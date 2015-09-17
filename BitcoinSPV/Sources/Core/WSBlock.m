//
//  WSBlock.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/12/14.
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

#import "WSBlock.h"
#import "WSBlockHeader.h"
#import "WSTransaction.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSBlock ()

@property (nonatomic, strong) WSBlockHeader *header;
@property (nonatomic, strong) NSOrderedSet *transactions;

@end

@implementation WSBlock

- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions
{
    WSExceptionCheckIllegal(header);
    WSExceptionCheckIllegal(transactions);
    
    if ((self = [super init])) {
        self.header = header;
        self.transactions = transactions;
    }
    return self;
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [self.header appendToMutableBuffer:buffer];
    [buffer appendUint32:self.header.version];
    [buffer appendHash256:self.header.previousBlockId];
    [buffer appendHash256:self.header.merkleRoot];
    [buffer appendUint32:self.header.timestamp];
    [buffer appendUint32:self.header.bits];
    [buffer appendUint32:self.header.nonce];
    [buffer appendVarInt:self.transactions.count];
    
    for (WSSignedTransaction *tx in self.transactions) {
        [tx appendToMutableBuffer:buffer];
    }
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] init];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if (available < WSFilteredBlockBaseSize) {
        WSErrorSetNotEnoughBytes(error, [self class], available, WSFilteredBlockBaseSize);
        return nil;
    }
    NSUInteger offset = from;
    NSUInteger varIntLength;
    
    WSBlockHeader *header = [[WSBlockHeader alloc] initWithParameters:parameters buffer:buffer from:offset available:available error:error];
    if (!header) {
        return nil;
    }
    offset += WSBlockHeaderSize - sizeof(uint8_t);

    const NSUInteger txCount = (NSUInteger)[buffer varIntAtOffset:offset length:&varIntLength];
    offset += varIntLength;

    NSMutableOrderedSet *transactions = [[NSMutableOrderedSet alloc] initWithCapacity:txCount];
    for (NSUInteger i = 0; i < txCount; ++i) {
        WSSignedTransaction *tx = [[WSSignedTransaction alloc] initWithParameters:parameters buffer:buffer from:offset available:(available - offset + from) error:error];
        if (!tx) {
            return nil;
        }
        [transactions addObject:tx];
        offset += [tx estimatedSize];
    }
    
    return [self initWithHeader:header transactions:transactions];
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    NSUInteger size = WSBlockHeaderSize - sizeof(uint8_t);
    size += WSBufferVarIntSize(self.transactions.count);
    for (WSSignedTransaction *tx in self.transactions) {
        size += [tx estimatedSize];
    }
    return size;
}

#pragma mark WSIndentableDescription

- (NSString *)descriptionWithIndent:(NSUInteger)indent
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];
    [tokens addObject:[NSString stringWithFormat:@"size = %lu bytes", (unsigned long)[self estimatedSize]]];
    [tokens addObject:[NSString stringWithFormat:@"header = %@", [self.header descriptionWithIndent:(indent + 1)]]];
    [tokens addObject:[NSString stringWithFormat:@"transactions = %lu", (unsigned long)self.transactions.count]];
    return [NSString stringWithFormat:@"{%@}", WSStringDescriptionFromTokens(tokens, indent)];
}

@end
