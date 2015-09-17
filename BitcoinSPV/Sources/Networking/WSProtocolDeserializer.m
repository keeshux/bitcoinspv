//
//  WSProtocolDeserializer.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 06/07/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//
//  http://github.com/keeshux
//  http://twitter.com/keeshux
//  http://davidederosa.com
//
//  This file is part of BitcoinSPV.
//
//  BitcoinSPV is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  BitcoinSPV is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with BitcoinSPV.  If not, see <http://www.gnu.org/licenses/>.
//

#import "WSProtocolDeserializer.h"
#import "WSMessageFactory.h"
#import "WSHash256.h"
#import "WSPeer.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSProtocolDeserializer ()

@property (nonatomic, strong) WSParameters *parameters;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, strong) WSMessageFactory *factory;
@property (nonatomic, strong) WSMutableBuffer *builtHeader;
@property (nonatomic, strong) WSMutableBuffer *builtPayload;
@property (nonatomic, strong) NSString *identifier;

- (id<WSMessage>)parseMessageFromStream:(NSInputStream *)inputStream keepParsing:(BOOL *)keepParsing error:(NSError *__autoreleasing *)error;

@end

@implementation WSProtocolDeserializer

- (instancetype)init
{
    WSExceptionRaiseUnsupported(@"Use initWithParameters:host:port:");
    return nil;
}

- (instancetype)initWithParameters:(WSParameters *)parameters host:(NSString *)host port:(uint16_t)port
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(host);
    WSExceptionCheckIllegal(port > 0);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        self.host = host;
        self.port = port;
        self.factory = [[WSMessageFactory alloc] initWithParameters:self.parameters];
        self.builtHeader = [[WSMutableBuffer alloc] init];
        self.builtPayload = [[WSMutableBuffer alloc] init];
        self.identifier = [NSString stringWithFormat:@"%@:%u", self.host, self.port];
    }
    return self;
}

- (id<WSMessage>)parseMessageFromStream:(NSInputStream *)inputStream error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(inputStream);
    
//    DDLogVerbose(@"Buffer length: %u", self.buffer.length);
    
    BOOL keepParsing = NO;
    id<WSMessage> message = [self parseMessageFromStream:inputStream keepParsing:&keepParsing error:error];
    if (!keepParsing) {
        [self resetBuffers];
    }
    return message;
}

- (void)resetBuffers
{
    self.builtHeader.length = 0;
    self.builtPayload.length = 0;
}

//
// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRPeer.m
//
// keepParsing: YES = read more bytes, NO = stop and reset buffers
//
- (id<WSMessage>)parseMessageFromStream:(NSInputStream *)inputStream keepParsing:(BOOL *)keepParsing error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(inputStream);
    NSParameterAssert(keepParsing);

    NSInteger currentHeaderLength = self.builtHeader.length;
    NSInteger currentPayloadLength = self.builtPayload.length;
    
    if (currentHeaderLength < WSMessageHeaderLength) {
        self.builtHeader.length = WSMessageHeaderLength;
        
        uint8_t *freeHeader = (uint8_t *)self.builtHeader.mutableBytes + currentHeaderLength;
        const NSUInteger toRead = self.builtHeader.length - currentHeaderLength;
        const NSInteger actuallyRead = [inputStream read:freeHeader maxLength:toRead];
        if (actuallyRead < 0) {
            [self resetBuffers];
            return nil;
        }

//        DDLogVerbose(@"Needed for header: %u", toRead);
//        DDLogVerbose(@"Current buffer length: %u", available);
//        DDLogVerbose(@"Actually read: %u", actuallyRead);

        self.builtHeader.length = currentHeaderLength + actuallyRead;
        
        // consume one byte at a time, up to the magic number that starts a new message header
        const uint32_t magicNumber = [self.parameters magicNumber];
        while ((self.builtHeader.length >= sizeof(uint32_t)) && ([self.builtHeader uint32AtOffset:0] != magicNumber)) {
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
        const NSInteger actuallyRead = [inputStream read:freePayload maxLength:toRead];
        if (actuallyRead < 0) {
            [self resetBuffers];
            return nil;
        }

//        DDLogVerbose(@"Needed for payload: %u", toRead);
//        DDLogVerbose(@"Current buffer length: %u", available);
//        DDLogVerbose(@"Actually read: %u", actuallyRead);

        self.builtPayload.length = currentPayloadLength + actuallyRead;
        if (self.builtPayload.length < expectedPayloadLength) {
            *keepParsing = YES;
            return nil;
        }
    }
    
    // checkpoint: payload is complete from here
    
    const uint32_t payloadLength = (uint32_t)self.builtPayload.length;
    WSHash256 *payloadHash256 = [self.builtPayload computeHash256];
    const uint32_t checksum = *(const uint32_t *)payloadHash256.bytes;
    if (checksum != expectedChecksum) {
        WSErrorSet(error, WSErrorCodeMalformed, @"Bad checksum deserializing '%@' (payload: %u == %u, checksum: %x == %x, hash256: %@)",
                   messageType, payloadLength, expectedPayloadLength, checksum, expectedChecksum, payloadHash256);

        *keepParsing = NO;
        return nil;
    }
    
    NSAssert(self.builtHeader.length == WSMessageHeaderLength, @"Unexpected header length (%lu != %lu)",
             (unsigned long)self.builtHeader.length,
             (unsigned long)WSMessageHeaderLength);
    
    DDLogVerbose(@"%@ Deserialized header: %@", self.identifier, [self.builtHeader hexString]);
    if (ddLogLevel >= LOG_LEVEL_VERBOSE) {
        if (self.builtPayload.length <= 4096) {
            DDLogVerbose(@"%@ Deserialized payload: %@", self.identifier, [self.builtPayload hexString]);
        }
        else {
            DDLogVerbose(@"%@ Deserialized payload: %lu bytes (too long to display)", self.identifier, (unsigned long)self.builtPayload.length);
        }
    }

    *keepParsing = NO;

    return [self.factory messageFromType:messageType payload:self.builtPayload error:error];
}

@end
