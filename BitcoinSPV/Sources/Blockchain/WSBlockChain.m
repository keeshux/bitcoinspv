//
//  WSBlockChain.m
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

#import "WSBlockChain.h"
#import "WSHash256.h"
#import "WSBlockStore.h"
#import "WSStorableBlock.h"
#import "WSStorableBlock+BlockChain.h"
#import "WSBlockHeader.h"
#import "WSBlockLocator.h"
#import "WSLogging.h"
#import "WSConfig.h"
#import "WSMacrosCore.h"
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
@property (nonatomic, assign) NSUInteger maxSize;
@property (nonatomic, strong) NSMutableDictionary *orphans; // WSHash256 -> WSStorableBlock
@property (nonatomic, assign) BOOL doValidate;

- (NSArray *)connectCurrentOrphansWithReorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock;
- (NSArray *)subchainFromHead:(WSStorableBlock *)head toBase:(WSStorableBlock *)base;

@end

@implementation WSBlockChain

- (instancetype)initWithStore:(id<WSBlockStore>)store
{
    return [self initWithStore:store maxSize:WSBlockChainDefaultMaxSize];
}

- (instancetype)initWithStore:(id<WSBlockStore>)store maxSize:(NSUInteger)maxSize
{
    WSExceptionCheckIllegal(store);
    WSExceptionCheckIllegal(maxSize >= 2016);
    WSExceptionCheck(store.head != nil, WSExceptionIllegalArgument, @"Missing head from blockStore (genesis block is required at a minimum)");

    if ((self = [super init])) {
        self.store = store;
        self.maxSize = maxSize;
        self.orphans = [[NSMutableDictionary alloc] init];

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

- (void)truncate
{
    [self.store truncate];
    [self.orphans removeAllObjects];
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

- (uint32_t)currentHeight
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

- (WSStorableBlock *)addCheckpoint:(WSStorableBlock *)checkpoint error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(checkpoint);
    
    // weak check because checkpoints usually have no ancestors
//    if (![self.head isBehindBlock:checkpoint inChain:self]) {
    if (self.head.height >= checkpoint.height) {
        return nil;
    }

    WSStorableBlock *block = [[WSStorableBlock alloc] initWithHeader:checkpoint.header transactions:nil height:checkpoint.height work:checkpoint.workData];
    [self.store putBlock:block];
    [self.store setHead:block];
    return block;
}

- (WSStorableBlock *)addBlockWithHeader:(WSBlockHeader *)header
                           transactions:(NSOrderedSet *)transactions
                               location:(WSBlockChainLocation *)location
                       connectedOrphans:(NSArray *__autoreleasing *)connectedOrphans
                        reorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock
                                  error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(header);
    
    if (location) {
        *location = WSBlockChainLocationNone;
    }
    
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
            if (location) {
                *location = WSBlockChainLocationMain;
            }
            
            [self.delegate blockChain:self didReplaceHead:newHead];

            return newHead;
        }
        else {
            DDLogDebug(@"Ignoring duplicated head: %@", header.blockId);
            if (location) {
                *location = WSBlockChainLocationMain;
            }
            return nil;
        }
    }
    if (connectedOrphans && self.orphans[header.blockId]) {
        DDLogDebug(@"Ignoring known orphan: %@", header.blockId);
        if (location) {
            *location = WSBlockChainLocationOrphan;
        }
        return nil;
    }

    WSStorableBlock *addedBlock = nil;

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
        
        DDLogVerbose(@"Extending main chain to %u with block %@ (%lu transactions)",
                     newHead.height,
                     header.blockId,
                     (unsigned long)transactions.count);

        [self.store putBlock:newHead];
        [self.store setHead:newHead];
        addedBlock = newHead;
        if (location) {
            *location = WSBlockChainLocationMain;
        }

        while (self.store.size > self.maxSize) {
            [self.store removeTail];
        }
        
        [self.delegate blockChain:self didAddNewBlock:addedBlock location:WSBlockChainLocationMain];
    }
    // fork
    else {
        
        // try connecting new block to fork
        WSStorableBlock *forkHead = [self.store blockForId:header.previousBlockId];

        // no parent, block is orphan
        if (!forkHead) {
            DDLogDebug(@"Added orphan block %@ (unknown height)", header.blockId);
            
            WSStorableBlock *orphan = [[WSStorableBlock alloc] initWithHeader:header transactions:transactions];
            self.orphans[header.blockId] = orphan;
            addedBlock = orphan;
            if (location) {
                *location = WSBlockChainLocationOrphan;
            }

            [self.delegate blockChain:self didAddNewBlock:orphan location:WSBlockChainLocationOrphan];

            return addedBlock;
        }

        DDLogDebug(@"Block %@ may be on a fork (head: %@)", header.blockId, forkHead.blockId);
        WSStorableBlock *newForkHead = [forkHead buildNextBlockFromHeader:header transactions:transactions];
        
        // fork is not best chain, extend with new head
        if (![newForkHead hasMoreWorkThanBlock:self.head]) {
            WSStorableBlock *forkBase = [self findForkBaseFromHead:newForkHead];

            if (forkBase && [forkBase isEqual:newForkHead]) {
                DDLogDebug(@"Ignoring duplicated block in main chain at height %u: %@", newForkHead.height, newForkHead.blockId);
                if (location) {
                    *location = WSBlockChainLocationMain;
                }
            }
            else {
                DDLogDebug(@"Extending fork to height %u with block %@ (%lu transactions)",
                           newForkHead.height,
                           header.blockId,
                           (unsigned long)transactions.count);

                [self.store putBlock:newForkHead];
                addedBlock = newForkHead;
                if (location) {
                    *location = WSBlockChainLocationFork;
                }

                [self.delegate blockChain:self didAddNewBlock:addedBlock location:WSBlockChainLocationFork];
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
            addedBlock = newForkHead;
            if (location) {
                *location = WSBlockChainLocationMain; // after reorg
            }

            [self.delegate blockChain:self didAddNewBlock:addedBlock location:WSBlockChainLocationFork];

            if (reorganizeBlock) {
                reorganizeBlock(forkBase, oldBlocks, newBlocks);
            }
            
            [self.delegate blockChain:self didReorganizeAtBase:forkBase oldBlocks:oldBlocks newBlocks:newBlocks];
        }
    }
    
    // blockchain updated, orphans might not be anymore
    if (connectedOrphans) {
        *connectedOrphans = [self connectCurrentOrphansWithReorganizeBlock:reorganizeBlock];
    }

    return addedBlock;
}

- (NSArray *)connectCurrentOrphansWithReorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock
{
    NSMutableArray *allConnectedOrphans = [[NSMutableArray alloc] init];
    BOOL anyConnected;

    do {
        anyConnected = NO;
        
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
                                                               location:NULL
                                                       connectedOrphans:NULL
                                                        reorganizeBlock:reorganizeBlock
                                                                  error:NULL];
            if (connectedOrphan) {
                [allConnectedOrphans addObject:connectedOrphan];
                anyConnected = YES;
            }

            // remove from original
            [self.orphans removeObjectForKey:orphan.blockId];
        }
        
        if (allConnectedOrphans.count > 0) {
            DDLogDebug(@"Connected %lu orphan blocks: %@", (unsigned long)allConnectedOrphans.count, allConnectedOrphans);
        }
    } while (anyConnected);

    return allConnectedOrphans;
}

- (BOOL)isOrphanBlock:(WSStorableBlock *)block
{
    WSExceptionCheckIllegal(block);

    return ![self.store blockForId:block.previousBlockId];
}

- (BOOL)isKnownOrphanBlockWithId:(WSHash256 *)blockId
{
    WSExceptionCheckIllegal(blockId);

    return (self.orphans[blockId] != nil);
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
    NSAssert([base isBehindBlock:head inChain:self], @"Head %@ (#%u) is not a descendant of fork base %@ (#%u)",
             head.blockId, head.height, base.blockId, base.height);

    NSMutableArray *chain = [[NSMutableArray alloc] initWithCapacity:(head.height - base.height)];

    WSStorableBlock *block = head;
    do {
        [chain addObject:block];
        block = [block previousBlockInChain:self];
    } while (![block.blockId isEqual:base.blockId]);

    return chain;
}

#pragma mark Core Data

- (void)loadFromCoreDataManager:(WSCoreDataManager *)manager
{
    WSExceptionCheckIllegal(manager);
    
    [self.store truncate];
    
    __block NSArray *blockEntities = nil;
    [manager.context performBlockAndWait:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[WSStorableBlockEntity entityName]];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"height" ascending:NO]];
        
        NSError *error;
        blockEntities = [manager.context executeFetchRequest:request error:&error];
        if (blockEntities) {
            DDLogDebug(@"Found %lu blocks in store", (unsigned long)blockEntities.count);
        }
        else {
            DDLogError(@"Error fetching all blocks (%@)", error);
        }
        
        for (WSStorableBlockEntity *blockEntity in blockEntities) {
            WSStorableBlock *block = [blockEntity toStorableBlockWithParameters:self.store.parameters];
            [self.store putBlock:block];

            if (blockEntity == [blockEntities firstObject]) {
                [self.store setHead:block];
            }
        }
        [self.store findAndRestoreTail];

        DDLogInfo(@"Loaded blockchain (%u) from Core Data: %@", self.head.height, manager.storeURL);
    }];
}

- (void)saveToCoreDataManager:(WSCoreDataManager *)manager
{
    WSExceptionCheckIllegal(manager);
    
    [manager truncate];
    [manager.context performBlockAndWait:^{
        for (WSStorableBlock *block in [self.store allBlocks]) {
            WSStorableBlockEntity *blockEntity = [[WSStorableBlockEntity alloc] initWithContext:manager.context];
            [blockEntity copyFromStorableBlock:block];
        }
    }];

    NSError *error;
    if ([manager saveWithError:&error]) {
        DDLogInfo(@"Saved blockchain (%u) to Core Data: %@", self.head.height, manager.storeURL);
    }
    else {
        DDLogError(@"Unable to save blockchain to Core Data: %@", error);
    }
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
