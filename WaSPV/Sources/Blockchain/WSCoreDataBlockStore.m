//
//  WSCoreDataBlockStore.m
//  WaSPV
//
//  Created by Davide De Rosa on 12/07/14.
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

#import "DDLog.h"

#import "WSCoreDataBlockStore.h"
#import "WSCoreDataManager.h"
#import "WSBlockHeaderEntity.h"
#import "WSStorableBlockEntity.h"
#import "WSTransactionEntity.h"
#import "WSTransactionOutPointEntity.h"
#import "WSTransactionInputEntity.h"
#import "WSTransactionOutputEntity.h"
#import "WSFilteredBlock.h"
#import "WSHash256.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"

// NOTE: orphans are not serialized

@interface WSCoreDataBlockStore ()

@property (nonatomic, strong) WSCoreDataManager *manager;
@property (nonatomic, strong) WSStorableBlock *head;
@property (nonatomic, strong) NSMutableDictionary *cachedBlockEntities;         // NSData -> WSStorableBlockEntity
@property (nonatomic, strong) NSMutableDictionary *cachedTxIdsToBlockEntities;  // NSData -> WSStorableBlockEntity

- (void)unsafeInsertGenesisBlock;
- (WSStorableBlockEntity *)unsafeBlockEntityForIdData:(NSData *)blockIdData;
- (WSTransactionEntity *)unsafeTransactionEntityForIdData:(NSData *)txIdData;

@end

@implementation WSCoreDataBlockStore

- (instancetype)init
{
    WSExceptionRaiseUnsupported(@"Use initWithManager:");
    return nil;
}

- (instancetype)initWithManager:(WSCoreDataManager *)manager
{
    if ((self = [super init])) {
        self.manager = manager;
        self.cachedBlockEntities = [[NSMutableDictionary alloc] init];
        self.cachedTxIdsToBlockEntities = [[NSMutableDictionary alloc] init];

        // load blocks into memory (from max height)
        __block NSArray *blockEntities = nil;
        [self.manager.context performBlockAndWait:^{
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[WSStorableBlockEntity entityName]];
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"height" ascending:NO]];

            NSError *error;
            blockEntities = [self.manager.context executeFetchRequest:request error:&error];
            if (blockEntities) {
                DDLogDebug(@"Found %u blocks in store", blockEntities.count);
            }
            else {
                DDLogError(@"Error fetching all blocks (%@)", error);
            }

            if (blockEntities.count == 0) {
                [self unsafeInsertGenesisBlock];
            }
            else {
                WSStorableBlockEntity *headEntity = [blockEntities firstObject];
                self.head = [headEntity toStorableBlock];

                for (WSStorableBlockEntity *blockEntity in blockEntities) {
                    self.cachedBlockEntities[blockEntity.header.blockIdData] = blockEntity;
                    
                    for (WSTransactionEntity *txEntity in blockEntity.transactions) {
                        self.cachedTxIdsToBlockEntities[txEntity.txIdData] = blockEntity;
                    }
                }
            }
        }];
    }
    return self;
}

#pragma mark WSBlockStore

- (WSStorableBlock *)blockForId:(WSHash256 *)blockId
{
    WSExceptionCheckIllegal(blockId != nil, @"Nil blockId");

    __block WSStorableBlockEntity *blockEntity = self.cachedBlockEntities[blockId.data];
    if (!blockEntity) {
        [self.manager.context performBlockAndWait:^{
            blockEntity = [self unsafeBlockEntityForIdData:blockId.data];
        }];
    }

    return [blockEntity toStorableBlock];
}

- (WSSignedTransaction *)transactionForId:(WSHash256 *)txId
{
    WSExceptionCheckIllegal(txId != nil, @"Nil txId");

    WSStorableBlockEntity *blockEntity = self.cachedTxIdsToBlockEntities[txId];
    __block WSTransactionEntity *txEntity = nil;
    for (WSTransactionEntity *entity in blockEntity.transactions) {
        if ([entity.txIdData isEqualToData:txId.data]) {
            txEntity = entity;
            break;
        }
    }
    if (!txEntity) {
        [self.manager.context performBlockAndWait:^{
            txEntity = [self unsafeTransactionEntityForIdData:txId.data];
        }];
    }
    if (!txEntity) {
        return nil;
    }
    
    return [txEntity toSignedTransaction];
}

- (void)putBlock:(WSStorableBlock *)block
{
    WSExceptionCheckIllegal(block != nil, @"Nil block");

    if (self.cachedBlockEntities[block.blockId.data]) {
        DDLogWarn(@"Replacing block %@", block.blockId);
    }
    [self.manager.context performBlockAndWait:^{
        WSStorableBlockEntity *blockEntity = [[WSStorableBlockEntity alloc] initWithContext:self.manager.context];
        [blockEntity copyFromStorableBlock:block];
        self.cachedBlockEntities[block.blockId.data] = blockEntity;
    }];
}

- (NSArray *)removeBlocksBelowHeight:(NSUInteger)height
{
    return [self removeBlocksWithPredicate:[NSPredicate predicateWithFormat: @"(height < %u)", height]];
}

- (NSArray *)removeBlocksAboveHeight:(NSUInteger)height
{
    return [self removeBlocksWithPredicate:[NSPredicate predicateWithFormat: @"(height > %u)", height]];
}

- (NSArray *)removeBlocksWithPredicate:(NSPredicate *)predicate
{
    __block NSMutableArray *prunedIds = nil;

    [self.manager.context performBlockAndWait:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[WSStorableBlockEntity entityName]];
        request.predicate = predicate;
        
        NSError *error;
        NSArray *prunedEntities = [self.manager.context executeFetchRequest:request error:&error];
        if (!prunedEntities) {
            DDLogError(@"Error fetching blocks with predicate %@ (%@)", predicate, error);
            return;
        }

        NSArray *sortedPrunedEntities = [prunedEntities sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            WSStorableBlockEntity *be1 = obj1;
            WSStorableBlockEntity *be2 = obj2;
            
            return (([be1.height unsignedIntegerValue] > [be2.height unsignedIntegerValue]) ? NSOrderedAscending : NSOrderedDescending);
        }];

        prunedIds = [[NSMutableArray alloc] initWithCapacity:sortedPrunedEntities.count];
        for (WSStorableBlockEntity *entity in sortedPrunedEntities) {
            [prunedIds addObject:WSHash256FromData(entity.header.blockIdData)];
        }

        NSMutableArray *prunedIdDatas = [[NSMutableArray alloc] initWithCapacity:prunedEntities.count];
        for (WSStorableBlockEntity *entity in prunedEntities) {
            [prunedIdDatas addObject:entity.header.blockIdData];
            [self.manager.context deleteObject:entity];
        }
        [self.cachedBlockEntities removeObjectsForKeys:prunedIdDatas];
    }];
    
    return prunedIds;
}

- (void)setHead:(WSStorableBlock *)head
{
    WSExceptionCheckIllegal(head != nil, @"Nil head");
    
    _head = head;
}

- (BOOL)save
{
    [self.manager.context performBlock:^{
        if ([self.manager.context save:NULL]) {
            DDLogInfo(@"Saved store to %@", self.manager.storeURL);
        }
        else {
            DDLogError(@"Failed to save store to %@", self.manager.storeURL);
        }
    }];
    return YES;
}

- (void)truncate
{
    DDLogInfo(@"Truncating store at %@", self.manager.storeURL);

    [self.manager truncate];

    [self.manager.context performBlockAndWait:^{
        [self.cachedBlockEntities removeAllObjects];
        [self.cachedTxIdsToBlockEntities removeAllObjects];
        
        [self unsafeInsertGenesisBlock];
    }];
}

#pragma mark Helpers

- (void)unsafeInsertGenesisBlock
{
    WSFilteredBlock *genesisBlock = [WSCurrentParameters genesisBlock];
    self.head = [[WSStorableBlock alloc] initWithHeader:genesisBlock.header transactions:nil height:0];
    
    WSStorableBlockEntity *headEntity = [[WSStorableBlockEntity alloc] initWithContext:self.manager.context];
    [headEntity copyFromStorableBlock:self.head];
}

- (WSStorableBlockEntity *)unsafeBlockEntityForIdData:(NSData *)blockIdData
{
    NSAssert(blockIdData, @"Nil blockIdData");
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[WSStorableBlockEntity entityName]];
    request.fetchLimit = 1;
    request.predicate = [NSPredicate predicateWithFormat:@"(header.blockIdData == %@)", blockIdData];
    
    NSError *error;
    NSArray *blockEntities = [self.manager.context executeFetchRequest:request error:&error];
    if (!blockEntities) {
        DDLogError(@"Error fetching block for id %@ (%@)", WSHash256FromData(blockIdData), error);
        return nil;
    }
    return [blockEntities lastObject];
}

- (WSTransactionEntity *)unsafeTransactionEntityForIdData:(NSData *)txIdData
{
    NSAssert(txIdData, @"Nil txIdData");

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[WSTransactionEntity entityName]];
    request.fetchLimit = 1;
    request.predicate = [NSPredicate predicateWithFormat:@"(txIdData == %@)", txIdData];
    
    NSError *error;
    NSArray *txEntities = [self.manager.context executeFetchRequest:request error:&error];
    if (!txEntities) {
        DDLogError(@"Error fetching transaction for id %@ (%@)", WSHash256FromData(txIdData), error);
        return nil;
    }
    return [txEntities lastObject];
}

@end
