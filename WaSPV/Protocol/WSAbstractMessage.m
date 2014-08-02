//
//  WSAbstractMessage.m
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

#import "WSMacros.h"
#import "WSErrors.h"

#import "WSAbstractMessage.h"
#import "WSHash256.h"

@interface WSAbstractMessage ()

@property (nonatomic, strong) WSBuffer *originalPayload;

@end

@implementation WSAbstractMessage

+ (instancetype)message
{
    return [[self alloc] init];
}

- (instancetype)init
{
    return [self initWithOriginalPayload:nil];
}

- (instancetype)initWithOriginalPayload:(WSBuffer *)originalPayload
{
    if ((self = [super init])) {
        if (originalPayload) {
            self.originalPayload = [[WSBuffer alloc] initWithData:originalPayload.data];
        }
    }
    return self;
}

- (WSBuffer *)toNetworkBufferWithHeaderLength:(NSUInteger *)headerLength
{
    WSBuffer *payload = [self toBuffer];
    NSAssert(payload, @"Payload can be empty but not nil");

    const NSUInteger capacity = WSMessageHeaderLength + payload.length;
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:capacity];
    
    // header (magic, type, length, checksum)
    
    [buffer appendUint32:[WSCurrentParameters magicNumber]];
    [buffer appendNullPaddedString:self.messageType length:12];
    
    NSData *payloadData = payload.data;
    WSHash256 *payloadHash256 = WSHash256Compute(payloadData);
    const uint32_t payloadChecksum = *(const uint32_t *)payloadHash256.bytes;
    [buffer appendUint32:(uint32_t)payloadData.length];
    [buffer appendUint32:payloadChecksum];
    
//    DDLogVerbose(@"Payload: %@", [payloadData hexString]);
//    DDLogVerbose(@"Payload hash256: %@", [payloadHash256 hexString]);
//    DDLogVerbose(@"Payload checksum: %0x", payloadChecksum);
    
    // payload
    
    [buffer appendBytes:payloadData.bytes length:payloadData.length];

    // decouple client classes from header length constant
    if (headerLength) {
        *headerLength = WSMessageHeaderLength;
    }
    
    return buffer;
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

#pragma mark WSMessage

- (NSString *)messageType
{
    WSExceptionRaiseUnsupported(@"messageType must be overridden by concrete subclasses");
    return nil;
}

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    return @"{}";
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] init];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSIndentableDescription

- (NSString *)descriptionWithIndent:(NSUInteger)indent
{
    return [NSString stringWithFormat:@"%@ %@", [super description], [self payloadDescriptionWithIndent:indent]];
}

@end
