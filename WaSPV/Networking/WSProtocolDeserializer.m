//
//  WSProtocolDeserializer.m
//  WaSPV
//
//  Created by Davide De Rosa on 06/07/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//
//  http://github.com/keeshux
//  http://twitter.com/keeshux
//  http://davidederosa.com
//
//  This file is part of WaSPV.
//
//  WaSPV is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  WaSPV is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with WaSPV.  If not, see <http://www.gnu.org/licenses/>.
//

#import "DDLog.h"

#import "WSProtocolDeserializer.h"
#import "WSMessageFactory.h"
#import "WSHash256.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"

@interface WSProtocolDeserializer ()

@property (nonatomic, weak) WSPeer *peer;
@property (nonatomic, strong) NSMutableData *buffer;
@property (nonatomic, strong) WSMutableBuffer *builtHeader;
@property (nonatomic, strong) WSMutableBuffer *builtPayload;

- (id<WSMessage>)parseMessageAndKeepParsing:(BOOL *)keepParsing error:(NSError *__autoreleasing *)error;
- (void)resetPartialMessage;

@end

@implementation WSProtocolDeserializer

- (instancetype)init
{
    return [self initWithPeer:nil];
}

- (instancetype)initWithPeer:(WSPeer *)peer
{
    if ((self = [super init])) {
        self.peer = peer;
        self.buffer = [[NSMutableData alloc] init];
        self.builtHeader = [[WSMutableBuffer alloc] init];
        self.builtPayload = [[WSMutableBuffer alloc] init];
    }
    return self;
}

- (void)appendData:(NSData *)data
{
    WSExceptionCheckIllegal(data != nil, @"Nil data");

//    DDLogVerbose(@"New data: %u", data.length);
    [self.buffer appendData:data];
}

- (id<WSMessage>)parseMessageWithError:(NSError *__autoreleasing *)error
{
//    DDLogVerbose(@"Buffer length: %u", self.buffer.length);
    
    BOOL keepParsing = NO;
    id<WSMessage> message = [self parseMessageAndKeepParsing:&keepParsing error:error];
    if (!keepParsing) {
        [self resetPartialMessage];
    }
    return message;
}

- (void)resetBuffers
{
    self.buffer.length = 0;
    [self resetPartialMessage];
}

//
// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRPeer.m
//
// keepParsing: YES = read more bytes, NO = stop and reset buffers
//
- (id<WSMessage>)parseMessageAndKeepParsing:(BOOL *)keepParsing error:(NSError *__autoreleasing *)error
{
    NSAssert(keepParsing, @"NULL keepParsing");

    NSInteger currentHeaderLength = self.builtHeader.length;
    NSInteger currentPayloadLength = self.builtPayload.length;
    
    if (currentHeaderLength < WSMessageHeaderLength) {
        self.builtHeader.length = WSMessageHeaderLength;
        
        uint8_t *freeHeader = (uint8_t *)self.builtHeader.mutableBytes + currentHeaderLength;
        const NSUInteger toRead = self.builtHeader.length - currentHeaderLength;
        const NSUInteger available = self.buffer.length;
        const NSUInteger actuallyRead = MIN(available, toRead);

//        DDLogVerbose(@"Needed for header: %u", toRead);
//        DDLogVerbose(@"Current buffer length: %u", available);
//        DDLogVerbose(@"Actually read: %u", actuallyRead);

        [self.buffer getBytes:freeHeader range:NSMakeRange(0, actuallyRead)];
        [self.buffer replaceBytesInRange:NSMakeRange(0, actuallyRead) withBytes:NULL length:0];

//        DDLogVerbose(@"New buffer length: %u", self.buffer.length);

        self.builtHeader.length = currentHeaderLength + actuallyRead;
        
        // consume one byte at a time, up to the magic number that starts a new message header
        while ((self.builtHeader.length >= sizeof(uint32_t)) &&
               ([self.builtHeader uint32AtOffset:0] != [WSCurrentParameters magicNumber])) {
#if DEBUG
            printf("%c", *(const char *)self.builtHeader.bytes);
#endif
            [self.builtHeader replaceBytesInRange:NSMakeRange(0, 1) withBytes:NULL length:0];
        }
        
        if (self.builtHeader.length < WSMessageHeaderLength) {
            *keepParsing = YES;
            return nil;
        }
    }
    
    // checkpoint: header is complete from here
    
    // ensure message type is null-terminated
    if ([self.builtHeader uint8AtOffset:15] != 0) {
        WSErrorSet(error, WSErrorCodeMalformed, @"Message type is not null-terminated (partial header: %@)", self.builtHeader);
        *keepParsing = NO;
        return nil;
    }
    
    NSString *messageType = [NSString stringWithUTF8String:((const char *)self.builtHeader.bytes + 4)];
    const uint32_t expectedPayloadLength = [self.builtHeader uint32AtOffset:16];
    const uint32_t expectedChecksum = [self.builtHeader uint32AtOffset:20];
    
    if (expectedPayloadLength > WSMessageMaxLength) {
        WSErrorSet(error, WSErrorCodeMalformed, @"Error deserializing '%@', message is too long (%u > %u)", messageType, expectedPayloadLength, WSMessageMaxLength);
        *keepParsing = NO;
        return nil;
    }
    
    if (currentPayloadLength < expectedPayloadLength) {
        self.builtPayload.length = expectedPayloadLength;
        
        uint8_t *freePayload = (uint8_t *)self.builtPayload.mutableBytes + currentPayloadLength;
        const NSUInteger toRead = self.builtPayload.length - currentPayloadLength;

        const NSUInteger available = self.buffer.length;
        const NSUInteger actuallyRead = MIN(available, toRead);

//        DDLogVerbose(@"Needed for payload: %u", toRead);
//        DDLogVerbose(@"Current buffer length: %u", available);
//        DDLogVerbose(@"Actually read: %u", actuallyRead);

        [self.buffer getBytes:freePayload range:NSMakeRange(0, actuallyRead)];
        [self.buffer replaceBytesInRange:NSMakeRange(0, actuallyRead) withBytes:NULL length:0];

//        DDLogVerbose(@"New buffer length: %u", self.buffer.length);

        self.builtPayload.length = currentPayloadLength + actuallyRead;
        if (self.builtPayload.length < expectedPayloadLength) {
            *keepParsing = YES;
            return nil;
        }
    }
    
    // checkpoint: payload is complete from here
    
    const uint32_t payloadLength = self.builtPayload.length;
    WSHash256 *payloadHash256 = [self.builtPayload computeHash256];
    const uint32_t checksum = *(const uint32_t *)payloadHash256.bytes;
    if (checksum != expectedChecksum) {
        WSErrorSet(error, WSErrorCodeMalformed, @"Bad checksum deserializing '%@' (payload: %u == %u, checksum: %x == %x, hash256: %@)",
                   messageType, payloadLength, expectedPayloadLength, checksum, expectedChecksum, payloadHash256);

        *keepParsing = NO;
        return nil;
    }
    
    NSAssert(self.builtHeader.length == WSMessageHeaderLength, @"Unexpected header length (%u != %u)", self.builtHeader.length, WSMessageHeaderLength);
    
    DDLogVerbose(@"%@ Deserialized header: %@", self.peer, [self.builtHeader hexString]);
    if (ddLogLevel >= LOG_LEVEL_VERBOSE) {
        if (self.builtPayload.length <= 4096) {
            DDLogVerbose(@"%@ Deserialized payload: %@", self.peer, [self.builtPayload hexString]);
        }
        else {
            DDLogVerbose(@"%@ Deserialized payload: %u bytes (too long to display)", self.peer, self.builtPayload.length);
        }
    }

    *keepParsing = NO;

    return [[WSMessageFactory sharedInstance] messageFromType:messageType
                                                      payload:self.builtPayload
                                                        error:error];
}

- (void)resetPartialMessage
{
    self.builtHeader.length = 0;
    self.builtPayload.length = 0;
}

@end
