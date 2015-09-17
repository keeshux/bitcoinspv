//
//  WSMessagePong.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 27/06/14.
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

#import "WSMessagePong.h"
#import "WSErrors.h"

@interface WSMessagePong ()

@property (nonatomic, assign) uint64_t nonce;

- (instancetype)initWithParameters:(WSParameters *)parameters nonce:(uint64_t)nonce;

@end

@implementation WSMessagePong

+ (instancetype)messageWithParameters:(WSParameters *)parameters nonce:(uint64_t)nonce
{
    return [[self alloc] initWithParameters:parameters nonce:nonce];
}

- (instancetype)initWithParameters:(WSParameters *)parameters nonce:(uint64_t)nonce
{
    if ((self = [super initWithParameters:parameters])) {
        self.nonce = nonce;
    }
    return self;
}

#pragma mark WSMessage

- (NSString *)messageType
{
    return WSMessageType_PONG;
}

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    return [NSString stringWithFormat:@"{nonce=%0llx}", self.nonce];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendUint64:self.nonce];
}

- (WSBuffer *)toBuffer
{
    // nonce
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:8];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if (available < sizeof(uint64_t)) {
        WSErrorSetNotEnoughMessageBytes(error, self.messageType, available, sizeof(uint64_t));
        return nil;
    }
    
    if ((self = [super initWithParameters:parameters originalLength:buffer.length])) {
        self.nonce = [buffer uint64AtOffset:from];
    }
    return self;
}

@end
