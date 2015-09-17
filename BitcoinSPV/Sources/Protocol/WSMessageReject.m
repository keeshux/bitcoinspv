//
//  WSMessageReject.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 23/07/14.
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

#import "WSMessageReject.h"
#import "WSBitcoinConstants.h"
#import "WSErrors.h"

NSString *const WSMessageRejectMessageTx        = @"tx";
NSString *const WSMessageRejectMessageBlock     = @"block";

@interface WSMessageReject ()

@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) uint8_t code;
@property (nonatomic, copy) NSString *reason;
@property (nonatomic, copy) NSData *payload;

- (instancetype)initWithParameters:(WSParameters *)parameters
                           message:(NSString *)message
                              code:(uint8_t)code
                            reason:(NSString *)reason
                           payload:(NSData *)payload;

@end

@implementation WSMessageReject

+ (instancetype)messageWithParameters:(WSParameters *)parameters
                              message:(NSString *)message
                                 code:(uint8_t)code
                               reason:(NSString *)reason
                              payload:(NSData *)payload
{
    return [[self alloc] initWithParameters:parameters message:message code:code reason:reason payload:payload];
}

- (instancetype)initWithParameters:(WSParameters *)parameters
                           message:(NSString *)message
                              code:(uint8_t)code
                            reason:(NSString *)reason
                           payload:(NSData *)payload
{
    WSExceptionCheckIllegal(message);
    WSExceptionCheckIllegal(code <= 0x4f);
    WSExceptionCheckIllegal(reason);
    WSExceptionCheckIllegal(payload);
    
    if ((self = [super initWithParameters:parameters])) {
        self.message = message;
        self.code = code;
        self.reason = reason;
        self.payload = payload;
    }
    return self;
}

#pragma mark WSMessage

- (NSString *)messageType
{
    return WSMessageType_REJECT;
}

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    return [NSString stringWithFormat:@"{message='%@', code=%x, reason='%@'}", self.message, self.code, self.reason];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendString:self.message];
    [buffer appendUint8:self.code];
    [buffer appendString:self.reason];
    [buffer appendData:self.payload];
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithParameters:parameters originalLength:buffer.length])) {
        NSUInteger offset = from;
        NSUInteger varIntLength;

        self.message = [buffer stringAtOffset:offset length:&varIntLength];
        offset += varIntLength;
        
        self.code = [buffer uint8AtOffset:offset];
        offset += sizeof(uint8_t);
        
        self.reason = [buffer stringAtOffset:offset length:&varIntLength];
        offset += varIntLength;
        
        if ([self.message isEqualToString:WSMessageRejectMessageTx]) {
            self.payload = [buffer dataAtOffset:offset length:WSHash256Length];
        }
        else if ([self.message isEqualToString:WSMessageRejectMessageBlock]) {
            self.payload = [buffer dataAtOffset:offset length:WSHash256Length];
        }
    }
    return self;
}

@end
