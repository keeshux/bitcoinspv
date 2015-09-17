//
//  WSPartialMerkleTree.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 04/07/14.
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

#import "WSPartialMerkleTree.h"
#import "WSHash256.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "NSData+Binary.h"

// adapted from: https://github.com/bitcoinj/bitcoinj/blob/master/core/src/main/java/com/google/bitcoin/core/PartialMerkleTree.java

@interface WSMerkleHashCalculatorUsedValues : NSObject

@property (nonatomic, assign) NSUInteger bits;
@property (nonatomic, assign) NSUInteger hashes;

@end

@implementation WSMerkleHashCalculatorUsedValues

@end

#pragma mark -

@interface WSPartialMerkleTree ()

@property (nonatomic, assign) uint32_t txCount;
@property (nonatomic, strong) NSArray *hashes;
@property (nonatomic, strong) NSData *flags;

@property (nonatomic, strong) WSHash256 *merkleRoot;
@property (nonatomic, strong) NSSet *matchedTxIds;

- (WSHash256 *)computeMerkleRootSavingMatchedHashes:(NSMutableSet *)matchedHashes error:(NSError **)error;
- (WSHash256 *)merkleHashAtHeight:(NSUInteger)height
                         position:(NSUInteger)position
                       usedValues:(WSMerkleHashCalculatorUsedValues *)usedValues
                    matchedHashes:(NSMutableSet *)matchedHashes
                            error:(NSError *__autoreleasing *)error;

- (NSUInteger)treeHeight;
- (NSUInteger)treeWidthAtHeight:(NSUInteger)height;

@end

@implementation WSPartialMerkleTree

- (instancetype)initWithTxCount:(uint32_t)txCount hashes:(NSArray *)hashes flags:(NSData *)flags error:(NSError *__autoreleasing *)error
{
    // An empty set will not work
    WSExceptionCheckIllegal(txCount > 0);
    
    // check for excessively high numbers of transactions
    // 60 is the lower bound for the size of a serialized CTransaction
    WSExceptionCheckIllegal(txCount <= WSBlockMaxSize / 60);
    
    // there can never be more hashes provided than one for every txid
    WSExceptionCheckIllegal(hashes.count <= txCount);
    
    // there must be at least one bit per node in the partial tree, and at least one node per hash
    WSExceptionCheckIllegal(flags.length * 8 >= hashes.count);
    
    if ((self = [super init])) {
        self.txCount = txCount;
        self.hashes = hashes;
        self.flags = flags;

        NSMutableSet *matchedTxIds = [[NSMutableSet alloc] init];
        self.merkleRoot = [self computeMerkleRootSavingMatchedHashes:matchedTxIds error:error];
        if (!self.merkleRoot) {
            return nil;
        }
        self.matchedTxIds = matchedTxIds;
    }
    return self;
}

- (BOOL)matchesTransactionWithId:(WSHash256 *)txId
{
    WSExceptionCheckIllegal(txId);

    return [self.matchedTxIds containsObject:txId];
}

#pragma mark Algorithm

- (WSHash256 *)computeMerkleRootSavingMatchedHashes:(NSMutableSet *)matchedHashes error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(matchedHashes);
    
    // traverse the partial tree bottom-up
    const NSUInteger height = [self treeHeight];
    const NSUInteger position = 0;
    WSMerkleHashCalculatorUsedValues *usedValues = [[WSMerkleHashCalculatorUsedValues alloc] init];

    WSHash256 *merkleRoot = [self merkleHashAtHeight:height position:position usedValues:usedValues matchedHashes:matchedHashes error:error];
    if (!merkleRoot) {
        return nil;
    }
    
    // verify that all bits were consumed (except for the padding caused by serializing it as a byte sequence)
    // verify that all hashes were consumed
    if (((usedValues.bits + 7) / 8 != self.flags.length) || (usedValues.hashes != self.hashes.count)) {
        WSErrorSet(error, WSErrorCodeInvalidPartialMerkleTree, @"Did not consume all provided data");
        return nil;
    }
    
    return merkleRoot;
}

// recursive function that traverses tree nodes, consuming the bits and hashes produced
// it returns the hash of the respective node.
- (WSHash256 *)merkleHashAtHeight:(NSUInteger)height
                         position:(NSUInteger)position
                       usedValues:(WSMerkleHashCalculatorUsedValues *)usedValues
                    matchedHashes:(NSMutableSet *)matchedHashes
                            error:(NSError *__autoreleasing *)error
{
    if (usedValues.bits >= self.flags.length * 8) {
        WSErrorSet(error, WSErrorCodeInvalidPartialMerkleTree, @"Overflowed flags array");
        return nil;
    }

    const BOOL parentOfMatch = WSUtilsCheckBit(self.flags.bytes, usedValues.bits);
    ++usedValues.bits;

    // if at height 0, or nothing interesting below, use stored hash and do not descend
    if ((height == 0) || !parentOfMatch) {
        if (usedValues.hashes >= self.hashes.count) {
            WSErrorSet(error, WSErrorCodeInvalidPartialMerkleTree, @"Overflowed hashes array");
            return nil;
        }

        WSHash256 *hash = self.hashes[usedValues.hashes];

        // in case of height 0, we have a matched txid
        if ((height == 0) && parentOfMatch) {
            [matchedHashes addObject:hash];
        }

        ++usedValues.hashes;
        return hash;
    }
    // otherwise, descend into the subtrees to extract matched txids and hashes
    else {
        const NSUInteger leftHeight = height - 1;
        const NSUInteger leftPosition = position * 2;

        WSHash256 *left = [self merkleHashAtHeight:leftHeight position:leftPosition usedValues:usedValues matchedHashes:matchedHashes error:error];

        // hash (left || right) if even children, (left || left) if odd

        const NSUInteger rightHeight = height - 1;
        const NSUInteger rightPosition = position * 2 + 1;

        WSHash256 *right = nil;
        if (rightPosition < [self treeWidthAtHeight:rightHeight]) {
            right = [self merkleHashAtHeight:rightHeight position:rightPosition usedValues:usedValues matchedHashes:matchedHashes error:error];
        }
        else {
            right = left;
        }

        NSMutableData *rootSource = [[NSMutableData alloc] initWithCapacity:(2 * WSHash256Length)];
        [rootSource appendData:left.data];
        [rootSource appendData:right.data];
        return WSHash256Compute(rootSource);
    }
}

- (NSUInteger)treeHeight
{
    NSUInteger height = 0;
    while ([self treeWidthAtHeight:height] > 1) {
        ++height;
    }
    return height;
}

// helper function to efficiently calculate the number of nodes at given height in the merkle tree
- (NSUInteger)treeWidthAtHeight:(NSUInteger)height
{
    return ((self.txCount + (1 << height) - 1) >> height);
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendUint32:self.txCount];
    [buffer appendVarInt:self.hashes.count];
    for (WSHash256 *hash in self.hashes) {
        [buffer appendHash256:hash];
    }
    [buffer appendVarData:self.flags];
}

- (WSBuffer *)toBuffer
{
    const NSUInteger capacity = 4 + 8 + self.hashes.count * WSHash256Length + 8 + self.flags.length;
    
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:capacity];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    NSUInteger offset = from;
    NSUInteger varIntLength;
    
    const uint32_t txCount = [buffer uint32AtOffset:offset];
    offset += sizeof(uint32_t);
    
    const NSUInteger hashesCount = (NSUInteger)[buffer varIntAtOffset:offset length:&varIntLength];
    if (hashesCount > INT32_MAX) {
        WSErrorSet(error, WSErrorCodeMalformed, @"Too many hashes (%u > INT32_MAX)", hashesCount, INT32_MAX);
        return nil;
    }
    NSUInteger expectedLength = sizeof(uint32_t) + varIntLength + hashesCount * WSHash256Length;
    if (available < expectedLength) {
        WSErrorSetNotEnoughBytes(error, [self class], available, expectedLength);
        return nil;
    }
    offset += varIntLength;
    
    NSMutableArray *hashes = [[NSMutableArray alloc] initWithCapacity:hashesCount];
    for (NSUInteger i = 0; i < hashesCount; ++i) {
        WSHash256 *hash256 = [buffer hash256AtOffset:offset];
        [hashes addObject:hash256];
        offset += WSHash256Length;
    }
    
    NSData *flags = [buffer varDataAtOffset:offset length:&varIntLength];
    expectedLength += varIntLength;
    if (available < expectedLength) {
        WSErrorSetNotEnoughBytes(error, [self class], available, expectedLength);
        return nil;
    }

    return [self initWithTxCount:txCount hashes:hashes flags:flags error:error];
}

#pragma mark WSIndentableDescription

- (NSString *)descriptionWithIndent:(NSUInteger)indent
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];
    [tokens addObject:[NSString stringWithFormat:@"txCount = %u", self.txCount]];
    [tokens addObject:[NSString stringWithFormat:@"hashes =\n%@", [self.hashes descriptionWithLocale:nil indent:(indent + 1)]]];
    [tokens addObject:[NSString stringWithFormat:@"flags = %@", [self.flags hexString]]];
    return [NSString stringWithFormat:@"{%@}", WSStringDescriptionFromTokens(tokens, indent)];
}

@end
