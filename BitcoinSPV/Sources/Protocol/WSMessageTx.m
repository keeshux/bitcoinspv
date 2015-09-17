//
//  WSMessageTx.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 02/07/14.
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

#import "WSErrors.h"

#import "WSMessageTx.h"
#import "WSTransaction.h"

@interface WSMessageTx ()

@property (nonatomic, strong) WSSignedTransaction *transaction;

- (instancetype)initWithParameters:(WSParameters *)parameters transaction:(WSSignedTransaction *)transaction;

@end

@implementation WSMessageTx

+ (instancetype)messageWithParameters:(WSParameters *)parameters transaction:(WSSignedTransaction *)transaction
{
    return [[self alloc] initWithParameters:parameters transaction:transaction];
}

- (instancetype)initWithParameters:(WSParameters *)parameters transaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction);
    
    if ((self = [super initWithParameters:parameters])) {
        self.transaction = transaction;
    }
    return self;
}

#pragma mark WSMessage

- (NSString *)messageType
{
    return WSMessageType_TX;
}

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    return [self.transaction descriptionWithIndent:indent];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [self.transaction appendToMutableBuffer:buffer];
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:[self.transaction estimatedSize]];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithParameters:parameters originalLength:buffer.length])) {
        self.transaction = [[WSSignedTransaction alloc] initWithParameters:parameters buffer:buffer from:from available:available error:error];
        if (!self.transaction) {
            return nil;
        }
    }
    return self;
}

@end
