//
//  WSTransactionOutPoint.m
//  WaSPV
//
//  Created by Davide De Rosa on 26/07/14.
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

#import "WSTransactionOutPoint.h"

@interface WSTransactionOutPoint ()

@property (nonatomic, strong) WSHash256 *txId;
@property (nonatomic, assign) uint32_t index;
@property (nonatomic, strong) WSBuffer *buffer;

- (instancetype)initWithTxId:(WSHash256 *)txId index:(uint32_t)index;

@end

@implementation WSTransactionOutPoint

+ (instancetype)outpointWithTxId:(WSHash256 *)txId index:(uint32_t)index
{
    return [[self alloc] initWithTxId:txId index:index];
}

- (instancetype)initWithTxId:(WSHash256 *)txId index:(uint32_t)index
{
    WSExceptionCheckIllegal(txId != nil, @"Nil txId");
    
    if ((self = [super init])) {
        self.txId = txId;
        self.index = index;
        
        WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:WSTransactionOutPointLength];
        [self appendToMutableBuffer:buffer];
        self.buffer = buffer;
    }
    return self;
}

- (BOOL)isCoinbase
{
    return ([self.txId isEqual:WSHash256Zero()] && (self.index == WSTransactionCoinbaseInputIndex));
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSTransactionOutPoint *outpoint = object;
    NSAssert(self.buffer && outpoint.buffer, @"Nil buffer found in compared objects, didn't compute in init?");
    return [outpoint.buffer isEqual:self.buffer];
}

- (NSUInteger)hash
{
    return [self.buffer hash];
}

- (NSString *)description
{
    if ([self isCoinbase]) {
        return @"coinbase";
    }
    else {
        return [NSString stringWithFormat:@"%@:%u", self.txId, self.index];
    }
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSTransactionOutPoint *copy = [[self class] allocWithZone:zone];
    copy.txId = [self.txId copyWithZone:zone];
    copy.index = self.index;
    copy.buffer = [self.buffer copyWithZone:zone];
    return copy;
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendHash256:self.txId];
    [buffer appendUint32:self.index];
}

- (WSBuffer *)toBuffer
{
    return self.buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithBuffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if (available < WSTransactionOutPointLength) {
        WSErrorSetNotEnoughBytes(error, [self class], available, WSTransactionOutPointLength);
        return nil;
    }
    
    NSUInteger offset = from;
    
    WSHash256 *txId = [buffer hash256AtOffset:offset];
    offset += WSHash256Length;

    const uint32_t index = [buffer uint32AtOffset:offset];
    
    return [self initWithTxId:txId index:index];
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    return WSHash256Length + sizeof(uint32_t);
}

@end
