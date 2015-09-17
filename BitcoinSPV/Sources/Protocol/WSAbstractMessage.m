//
//  WSAbstractMessage.m
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

#import "WSAbstractMessage.h"
#import "WSParameters.h"
#import "WSHash256.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSAbstractMessage ()

@property (nonatomic, strong) WSParameters *parameters;
@property (nonatomic, assign) NSUInteger originalLength;

@end

@implementation WSAbstractMessage

+ (instancetype)messageWithParameters:(WSParameters *)parameters
{
    return [[self alloc] initWithParameters:parameters];
}

- (instancetype)init
{
    WSExceptionRaiseUnsupported(@"Use initWithParameters:");
    return nil;
}

- (instancetype)initWithParameters:(WSParameters *)parameters
{
    return [self initWithParameters:parameters originalLength:0];
}

- (instancetype)initWithParameters:(WSParameters *)parameters originalLength:(NSUInteger)originalLength
{
    WSExceptionCheckIllegal(parameters);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        self.originalLength = originalLength;
    }
    return self;
}

- (WSBuffer *)toNetworkBufferWithHeaderLength:(NSUInteger *)headerLength
{
    NSAssert(self.parameters, @"Message built without network parameters");

    WSBuffer *payload = [self toBuffer];
    NSAssert(payload, @"Payload can be empty but not nil");

    const NSUInteger capacity = WSMessageHeaderLength + payload.length;
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:capacity];
    
    // header (magic, type, length, checksum)
    
    [buffer appendUint32:[self.parameters magicNumber]];
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

- (NSUInteger)length
{
    return WSMessageHeaderLength + self.originalLength;
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
