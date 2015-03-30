//
//  WSBlockChain.m
//  WaSPV
//
//  Created by Davide De Rosa on 02/07/14.
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

#import "WSBlockChain.h"
#import "WSHash256.h"
#import "WSBlockStore.h"
#import "WSStorableBlock.h"
#import "WSBlockHeader.h"
#import "WSBlockLocator.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"
#import "WSCoreDataManager.h"
#import "WSBlockHeaderEntity.h"
#import "WSStorableBlockEntity.h"
#import "WSTransactionEntity.h"
#import "WSTransactionOutPointEntity.h"
#import "WSTransactionInputEntity.h"
#import "WSTransactionOutputEntity.h"

// adapted from: https://github.com/bitcoinj/bitcoinj/blob/master/core/src/main/java/com/google/bitcoin/core/AbstractBlockChain.java

@interface WSBlockChain ()

@property (nonatomic, strong) id<WSBlockStore> store;
@property (nonatomic, strong) NSMutableDictionary *orphans; // WSHash256 -> WSStorableBlock
@property (nonatomic, assign) BOOL doValidate;

- (WSStorableBlock *)addBlockWithHeader:(WSBlockHeader *)header
                           transactions:(NSOrderedSet *)transactions
                        reorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock
                         connectOrphans:(BOOL)connectOrphans
                                  error:(NSError *__autoreleasing *)error;

- (void)connectCurrentOrphansWithReorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock;
- (WSStorableBlock *)findForkBaseFromHead:(WSStorableBlock *)forkHead;
- (NSArray *)subchainFromHead:(WSStorableBlock *)head toBase:(WSStorableBlock *)base;

@end

@implementation WSBlockChain

- (instancetype)initWithStore:(id<WSBlockStore>)blockStore
{
    WSExceptionCheckIllegal(blockStore != nil, @"Nil blockStore");
    WSExceptionCheckIllegal(blockStore.head != nil, @"Missing head from blockStore (genesis block is required at a minimum)");

    if ((self = [super init])) {
        self.store = blockStore;
        self.orphans = [[NSMutableDictionary alloc] init];
        self.blockStoreSize = 2500;

        //
        // test networks (testnet3/regtest) validates blocks in
        // a different manner than main network, we just won't
        // validate blocks there
        //
        // e.g.: normally blocks #4033 and #4032 should have same target
        // because in the same retarget timespan, but they actually don't
        //
        // https://www.biteasy.com/testnet/blocks/000000001af3b22a7598b10574deb6b3e2d596f36d62b0a49cb89a1f99ab81eb
        // https://www.biteasy.com/testnet/blocks/00000000db623a1752143f2f805c4527573570d9b4ca0a3cfe371e703ac429aa
        //
        self.doValidate = ([self.store.parameters networkType] == WSNetworkTypeMain);
    }
    return self;
}

#pragma mark Access

- (WSStorableBlock *)head
{
    NSAssert(self.store.head, @"Corrupted chain, nil head");
    
    return self.store.head;
}

- (WSStorableBlock *)blockForId:(WSHash256 *)blockId
{
    return [self.store blockForId:blockId];
}

- (NSArray *)allBlockIds
{
    NSMutableArray *ids = [[NSMutableArray alloc] initWithCapacity:self.currentHeight];
    WSStorableBlock *block = self.head;
    while (block) {
        [ids addObject:block.blockId];
        block = [block previousBlockInChain:self];
    }
    return ids;
}

- (NSUInteger)currentHeight
{
    return self.head.height;
}

- (uint32_t)currentTimestamp
{
    return self.head.header.timestamp;
}

- (WSBlockLocator *)currentLocator
{
    NSMutableArray *hashes = [[NSMutableArray alloc] initWithCapacity:100];
    WSStorableBlock *block = self.head;
    WSHash256 *genesisBlockId = [self.store.parameters genesisBlockId];

    NSInteger i = 0;
    NSInteger step = 1;
    while (block && ![block.blockId isEqual:genesisBlockId]) {
        [hashes addObject:block.blockId];
        if (i >= 10) {
            step <<= 1;
        }
        block = [block previousBlockInChain:self maxStep:step lastPreviousBlock:NULL];
        ++i;
    }
    [hashes addObject:genesisBlockId];

    return [[WSBlockLocator alloc] initWithHashes:hashes];
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

- (NSString *)descriptionWithMaxBlocks:(NSUInteger)maxBlocks
{
    return [self descriptionWithIndent:0 maxBlocks:maxBlocks];
}

#pragma mark Modification

- (WSStorableBlock *)addBlockWithHeader:(WSBlockHeader *)header error:(NSError *__autoreleasing *)error
{
    return [self addBlockWithHeader:header reorganizeBlock:NULL error:error];
}

- (WSStorableBlock *)addBlockWithHeader:(WSBlockHeader *)header reorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock error:(NSError *__autoreleasing *)error
{
    return [self addBlockWithHeader:header transactions:nil reorganizeBlock:reorganizeBlock error:error];
}

- (WSStorableBlock *)addBlockWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions error:(NSError *__autoreleasing *)error
{
    return [self addBlockWithHeader:header transactions:transactions reorganizeBlock:NULL connectOrphans:YES error:error];
}

- (WSStorableBlock *)addBlockWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions reorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock error:(NSError *__autoreleasing *)error
{
    return [self addBlockWithHeader:header transactions:transactions reorganizeBlock:reorganizeBlock connectOrphans:YES error:error];
}

- (WSStorableBlock *)addBlockWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions reorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock connectOrphans:(BOOL)connectOrphans error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(header != nil, @"Nil header");
    
    WSStorableBlock *addedBlock = nil;
    
    if ([header.blockId isEqual:self.head.blockId]) {

        if ((self.head.transactions.count < transactions.count) &&
            (!self.head.transactions || [self.head.transactions isSubsetOfOrderedSet:transactions])) {

            DDLogDebug(@"Trying to replace head with more detailed block: %@", header.blockId);
            WSStorableBlock *headParent = [self.head previousBlockInChain:self];
            WSStorableBlock *newHead = [headParent buildNextBlockFromHeader:header transactions:transactions];
            if ([self.head hasMoreWorkThanBlock:newHead]) {
                DDLogDebug(@"Ignoring block with less work than head (%@ < %@)", [newHead workString], [self.head workString]);
                return nil;
            }

            [self.store putBlock:newHead];
            [self.store setHead:newHead];
            
            [self.delegate blockChain:self didReplaceHead:newHead];

            return newHead;
        }
        else {
            DDLogDebug(@"Ignoring duplicated head: %@", header.blockId);
            return nil;
        }
    }
    if (connectOrphans && self.orphans[header.blockId]) {
        DDLogDebug(@"Ignoring known orphan: %@", header.blockId);
        return nil;
    }

    // main chain
    if ([header.previousBlockId isEqual:self.head.blockId]) {
        DDLogVerbose(@"Block %@ is on main chain (head: %@)", header.blockId, self.head.blockId);
        WSStorableBlock *newHead = [self.head buildNextBlockFromHeader:header transactions:transactions];
        
        if (self.doValidate) {
            if (![newHead validateTargetInChain:self error:error]) {
                DDLogDebug(@"Block %@ is invalid", header.blockId);
                return nil;
            }
        }
        
        DDLogVerbose(@"Extending main chain to %u with block %@ (%u transactions)", newHead.height, header.blockId, transactions.count);
        [self.store putBlock:newHead];
        [self.store setHead:newHead];

        while (self.store.size > self.blockStoreSize) {
            [self.store removeTailBlock];
        }
        
        [self.delegate blockChain:self didAddNewBlock:newHead];

        addedBlock = newHead;
    }
    // fork
    else {
        
        // try connecting new block to fork
        WSStorableBlock *forkHead = [self.store blockForId:header.previousBlockId];

        // no parent, block is orphan
        if (!forkHead) {
            DDLogDebug(@"Added orphan block %@ (unknown height)", header.blockId);
            self.orphans[header.blockId] = [[WSStorableBlock alloc] initWithHeader:header transactions:transactions];

            return nil;
        }

        DDLogDebug(@"Block %@ may be on a fork (head: %@)", header.blockId, forkHead.blockId);
        WSStorableBlock *newForkHead = [forkHead buildNextBlockFromHeader:header transactions:transactions];
        
        // fork is not best chain, extend with new head
        if (![newForkHead hasMoreWorkThanBlock:self.head]) {
            WSStorableBlock *forkBase = [self findForkBaseFromHead:newForkHead];

            if (forkBase && [forkBase isEqual:newForkHead]) {
                DDLogDebug(@"Ignoring duplicated block in main chain at height %u: %@", newForkHead.height, newForkHead.blockId);
            }
            else {
                DDLogDebug(@"Extending fork to height %u with block %@ (%u transactions)", newForkHead.height, header.blockId, transactions.count);

                [self.store putBlock:newForkHead];
            }
        }
        // fork is new best chain, reorganize
        else {
            DDLogDebug(@"Found new best chain at height %u with head %@ (work: %@ > %@), reorganizing",
                       newForkHead.height, newForkHead.blockId, [newForkHead workString], [self.head workString]);

            WSStorableBlock *forkBase = [self findForkBaseFromHead:newForkHead];
            DDLogDebug(@"Chain split at height %u", forkBase.height);
            
            NSArray *oldBlocks = [self subchainFromHead:self.head toBase:forkBase];
            NSArray *newBlocks = [self subchainFromHead:newForkHead toBase:forkBase];
            
            [self.store putBlock:newForkHead];
            [self.store setHead:newForkHead];

            if (reorganizeBlock) {
                reorganizeBlock(forkBase, oldBlocks, newBlocks);
            }
            
            [self.delegate blockChain:self didReorganizeAtBase:forkBase oldBlocks:oldBlocks newBlocks:newBlocks];
        }
    }
    
    // blockchain updated, orphans might not be anymore
    if (connectOrphans) {
        [self connectCurrentOrphansWithReorganizeBlock:reorganizeBlock];
    }

    return addedBlock;
}

- (void)connectCurrentOrphansWithReorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock
{
    NSMutableArray *connectedOrphanIds = [[NSMutableArray alloc] init];
    do {
        [connectedOrphanIds removeAllObjects];
        
        // WARNING: copy, don't modifiy iterated collection
        for (WSStorableBlock *orphan in [[self.orphans allValues] copy]) {
            WSStorableBlock *parentBlock = [self.store blockForId:orphan.previousBlockId];

            // still orphan
            if (!parentBlock) {
                continue;
            }

            // orphan has a parent, try readding to main chain or some fork (non-recursive)
            DDLogDebug(@"Trying to connect orphan block %@", orphan.blockId);
            WSStorableBlock *connectedOrphan = [self addBlockWithHeader:orphan.header
                                                           transactions:orphan.transactions
                                                        reorganizeBlock:reorganizeBlock
                                                         connectOrphans:NO
                                                                  error:NULL];
            if (connectedOrphan) {
                [connectedOrphanIds addObject:connectedOrphan.blockId];
            }

            // remove from original
            [self.orphans removeObjectForKey:orphan.blockId];
        }
        
        if (connectedOrphanIds.count > 0) {
            DDLogDebug(@"Connected %u orphan blocks: %@", connectedOrphanIds.count, connectedOrphanIds);
        }
    } while (connectedOrphanIds.count > 0);
}

- (WSStorableBlock *)findForkBaseFromHead:(WSStorableBlock *)forkHead
{
    NSParameterAssert(forkHead);

    WSStorableBlock *mainBlock = self.head;
    WSStorableBlock *forkBlock = forkHead;

    while (![mainBlock isEqual:forkBlock]) {
        if (mainBlock.height > forkBlock.height) {
            mainBlock = [mainBlock previousBlockInChain:self];
            
            NSAssert(mainBlock, @"Attempt to follow an orphan chain");
        } else {
            forkBlock = [forkBlock previousBlockInChain:self];

            NSAssert(forkBlock, @"Attempt to follow an orphan chain");
        }
    }

    return forkBlock;
}

- (NSArray *)subchainFromHead:(WSStorableBlock *)head toBase:(WSStorableBlock *)base
{
    NSParameterAssert(head);
    NSParameterAssert(base);
    NSAssert(head.height > base.height, @"Head is not above base (%u <= %u)", head.height, base.height);

    NSMutableArray *chain = [[NSMutableArray alloc] initWithCapacity:(head.height - base.height)];

    WSStorableBlock *block = head;
    do {
        [chain addObject:block];
        block = [block previousBlockInChain:self];
    } while (![block isEqual:base]);

    return chain;
}

- (BOOL)isBehindBlock:(WSStorableBlock *)block
{
    WSExceptionCheckIllegal(block != nil, @"Nil block");

    return (self.currentHeight < block.height);
}

- (WSStorableBlock *)addCheckpoint:(WSStorableBlock *)checkpoint error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(checkpoint != nil, @"Nil checkpoint");
    
    if (![self isBehindBlock:checkpoint]) {
        return nil;
    }
    WSStorableBlock *block = [[WSStorableBlock alloc] initWithHeader:checkpoint.header transactions:nil height:checkpoint.height work:checkpoint.workData];
    [self.store putBlock:block];
    [self.store setHead:block];
    return block;
}

#pragma mark Core Data

- (void)loadFromCoreDataManager:(WSCoreDataManager *)manager
{
    WSExceptionCheckIllegal(manager != nil, @"Nil manager");
    
    [self.store truncate];

    __block NSArray *blockEntities = nil;
    [manager.context performBlockAndWait:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[WSStorableBlockEntity entityName]];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"height" ascending:NO]];
        
        NSError *error;
        blockEntities = [manager.context executeFetchRequest:request error:&error];
        if (blockEntities) {
            DDLogDebug(@"Found %u blocks in store", blockEntities.count);
        }
        else {
            DDLogError(@"Error fetching all blocks (%@)", error);
        }
        
        for (WSStorableBlockEntity *blockEntity in blockEntities) {
            WSStorableBlock *block = [blockEntity toStorableBlockWithParameters:self.store.parameters];
            [self.store putBlock:block];
        }
    }];
}

- (void)saveToCoreDataManager:(WSCoreDataManager *)manager
{
    WSExceptionCheckIllegal(manager != nil, @"Nil manager");
    
    [manager truncate];
    [manager.context performBlock:^{
        for (WSStorableBlock *block in [self.store allBlocks]) {
            WSStorableBlockEntity *blockEntity = [[WSStorableBlockEntity alloc] initWithContext:manager.context];
            [blockEntity copyFromStorableBlock:block];
        }
    }];
}

#pragma mark WSIndentableDescription

- (NSString *)descriptionWithIndent:(NSUInteger)indent
{
    return [self descriptionWithIndent:indent maxBlocks:UINT_MAX];
}

- (NSString *)descriptionWithIndent:(NSUInteger)indent maxBlocks:(NSUInteger)maxBlocks
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];
    WSStorableBlock *block = self.head;

    NSUInteger i = 0;
    while (block && (i < maxBlocks)) {
        NSString *row = [NSString stringWithFormat:@"%@ %@", [block class], [block descriptionWithIndent:(indent + 1)]];
        [tokens addObject:row];
        block = [block previousBlockInChain:self];
        ++i;
    }

    return [NSString stringWithFormat:@"{%@}", WSStringDescriptionFromTokens(tokens, indent)];
}

@end
