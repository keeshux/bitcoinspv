//
//  WSStorableBlock+BlockChain.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 21/04/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
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

#import <openssl/bn.h>

#import "WSStorableBlock+BlockChain.h"
#import "WSBlockChain.h"
#import "WSBlockHeader.h"
#import "WSParameters.h"
#import "WSErrors.h"
#import "WSMacrosCore.h"
#import "WSMacrosPrivate.h"

@implementation WSStorableBlock (BlockChain)

- (WSStorableBlock *)previousBlockInChain:(WSBlockChain *)blockChain
{
    return [self previousBlockInChain:blockChain maxStep:1 lastPreviousBlock:NULL];
}

- (WSStorableBlock *)previousBlockInChain:(WSBlockChain *)blockChain maxStep:(NSUInteger)maxStep lastPreviousBlock:(WSStorableBlock *__autoreleasing *)lastPreviousBlock
{
    WSExceptionCheckIllegal(blockChain);
    WSExceptionCheckIllegal(maxStep > 0);
    
    WSStorableBlock *previousBlock = self;
    for (NSUInteger i = 0; i < maxStep; ++i) {
        if (lastPreviousBlock) {
            *lastPreviousBlock = previousBlock;
        }
        WSHash256 *previousBlockId = previousBlock.header.previousBlockId;
        if (!previousBlockId) {
            return nil;
        }
        previousBlock = [blockChain blockForId:previousBlockId];
        if (!previousBlock) {
            return nil;
        }
    }
    return previousBlock;
}

- (BOOL)isBehindBlock:(WSStorableBlock *)block inChain:(WSBlockChain *)blockChain
{
    WSExceptionCheckIllegal(block);
    WSExceptionCheckIllegal(blockChain);
    
    WSStorableBlock *ancestor = block;
    while (ancestor && ![ancestor.blockId isEqual:self.blockId]) {
        ancestor = [ancestor previousBlockInChain:blockChain];
    }
    return (ancestor != nil);
}

- (BOOL)isOrphanInChain:(WSBlockChain *)blockChain
{
    WSExceptionCheckIllegal(blockChain);
    
    return [blockChain isOrphanBlock:self];
}

- (BOOL)validateTargetInChain:(WSBlockChain *)blockChain error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(blockChain);
    
    WSStorableBlock *previousBlock = [self previousBlockInChain:blockChain];
    if (!previousBlock) {
        WSErrorSet(error, WSErrorCodeInvalidBlock, @"Orphaned block");
        return NO;
    }
    
    if (![self isTransitionBlock]) {
        if (self.header.bits != previousBlock.header.bits) {
            WSErrorSet(error, WSErrorCodeInvalidBlock, @"Unexpected target at height %u (%x != %x)",
                       self.height, self.header.bits, previousBlock.header.bits);
            
            return NO;
        }
        return YES;
    }
    
    WSStorableBlock *retargetBlock = previousBlock;
    const uint32_t retargetInterval = [self.parameters retargetInterval];
    for (NSUInteger i = 1; i < retargetInterval; ++i) {
        retargetBlock = [retargetBlock previousBlockInChain:blockChain];
    }
    if (!retargetBlock) {
        WSErrorSet(error, WSErrorCodeInvalidBlock, @"Incomplete chain, last retarget block not found at height %u", self.height - retargetInterval + 1);
        return NO;
    }
    
    return [self validateTargetFromPreviousBlock:previousBlock retargetBlock:retargetBlock error:error];
}

- (BOOL)validateTargetFromPreviousBlock:(WSStorableBlock *)previousBlock retargetBlock:(WSStorableBlock *)retargetBlock error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(previousBlock);
    NSParameterAssert(retargetBlock);
    
    uint32_t span = previousBlock.header.timestamp - retargetBlock.header.timestamp;
    const uint32_t minRetargetTimespan = [self.parameters minRetargetTimespan];
    const uint32_t maxRetargetTimespan = [self.parameters maxRetargetTimespan];
    if (span < minRetargetTimespan) {
        span = minRetargetTimespan;
    }
    if (span > maxRetargetTimespan) {
        span = maxRetargetTimespan;
    }
    
    BIGNUM bnTarget;
    BIGNUM bnMaxTarget;
    BIGNUM bnSpan;
    BIGNUM bnRetargetSpan;
    BIGNUM bnTargetXSpan;
    
    BN_init(&bnTarget);
    BN_init(&bnMaxTarget);
    BN_init(&bnSpan);
    BN_init(&bnRetargetSpan);
    BN_init(&bnTargetXSpan);
    
    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);
    
    WSBlockSetBits(&bnTarget, retargetBlock.header.bits);
    WSBlockSetBits(&bnMaxTarget, [self.parameters maxProofOfWork]);
    BN_set_word(&bnSpan, span);
    BN_set_word(&bnRetargetSpan, [self.parameters retargetTimespan]);
    BN_mul(&bnTargetXSpan, &bnTarget, &bnSpan, ctx);
    BN_div(&bnTarget, NULL, &bnTargetXSpan, &bnRetargetSpan, ctx);
    
    // cap target to max target
    if (BN_cmp(&bnTarget, &bnMaxTarget) > 0) {
        BN_copy(&bnTarget, &bnMaxTarget);
    }
    
    const uint32_t expectedBits = WSBlockGetBits(&bnTarget);
    
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
    
    BN_free(&bnTarget);
    BN_free(&bnMaxTarget);
    BN_free(&bnSpan);
    BN_free(&bnRetargetSpan);
    BN_free(&bnTargetXSpan);
    
    if (self.header.bits != expectedBits) {
        WSErrorSet(error, WSErrorCodeInvalidBlock, @"Unexpected target at height %u (%x != %x)",
                   self.height, self.header.bits, expectedBits);
        
        return NO;
    }
    return YES;
}

@end
