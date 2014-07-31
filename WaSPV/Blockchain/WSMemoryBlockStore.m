//
//  WSMemoryBlockStore.m
//  WaSPV
//
//  Created by Davide De Rosa on 08/07/14.
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

#import "WSMemoryBlockStore.h"
#import "WSStorableBlock.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSTransactionOutPoint.h"
#import "WSTransactionInput.h"
#import "WSTransaction.h"

@interface WSMemoryBlockStore ()

@property (nonatomic, strong) NSMutableDictionary *blocks;          // WSHash256 -> WSStorableBlock
@property (nonatomic, strong) NSMutableDictionary *txIdsToBlocks;   // WSHash256 -> WSStorableBlock
@property (nonatomic, weak) WSStorableBlock *head;

@end

@implementation WSMemoryBlockStore

- (instancetype)init
{
    if ((self = [super init])) {
        self.blocks = [[NSMutableDictionary alloc] init];
        self.txIdsToBlocks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithGenesisBlock
{
    if ((self = [self init])) {
        WSFilteredBlock *genesisBlock = [WSCurrentParameters genesisBlock];
        WSStorableBlock *block = [[WSStorableBlock alloc] initWithHeader:genesisBlock.header transactions:nil height:0];
        [self putBlock:block];
        self.head = block;
    }
    return self;
}

#pragma mark WSBlockStore

- (WSStorableBlock *)blockForId:(WSHash256 *)blockId
{
    WSExceptionCheckIllegal(blockId != nil, @"Nil blockId");
    
    @synchronized (self) {
        return self.blocks[blockId];
    }
}

- (WSSignedTransaction *)transactionForId:(WSHash256 *)txId
{
    WSExceptionCheckIllegal(txId != nil, @"Nil txId");
    
    @synchronized (self) {
        WSStorableBlock *block = self.txIdsToBlocks[txId];
        if (!block) {
            return nil;
        }
        for (WSSignedTransaction *tx in block.transactions) {
            if ([tx.txId isEqual:txId]) {
                return tx;
            }
        }
        return nil;
    }
}

- (void)putBlock:(WSStorableBlock *)block
{
    WSExceptionCheckIllegal(block != nil, @"Nil block");

    @synchronized (self) {
        WSHash256 *blockId = block.blockId;
        if (self.blocks[blockId]) {
            DDLogWarn(@"Replacing block %@", blockId);
        }
        self.blocks[blockId] = block;
        for (WSSignedTransaction *tx in block.transactions) {
            self.txIdsToBlocks[tx.txId] = block;
        }
    }
}

- (NSArray *)removeBlocksBelowHeight:(NSUInteger)height
{
    return [self removeBlocksWithPredicate:[NSPredicate predicateWithFormat:@"height < %u", height]];
}

- (NSArray *)removeBlocksAboveHeight:(NSUInteger)height
{
    return [self removeBlocksWithPredicate:[NSPredicate predicateWithFormat:@"height > %u", height]];
}

- (NSArray *)removeBlocksWithPredicate:(NSPredicate *)predicate
{
    @synchronized (self) {
        NSMutableArray *removedBlockIds = [[NSMutableArray alloc] initWithCapacity:self.blocks.count];
        WSHash256 *blockId = self.head.blockId;
        while (blockId) {
            WSStorableBlock *block = self.blocks[blockId];
            if ([predicate evaluateWithObject:block]) {
                [removedBlockIds addObject:block.blockId];
            }
            blockId = block.previousBlockId;
        }
        [self.blocks removeObjectsForKeys:removedBlockIds];
        return removedBlockIds;
    }
}

- (void)setHead:(WSStorableBlock *)head
{
    WSExceptionCheckIllegal(head != nil, @"Nil head");
    
    _head = head;
}

- (BOOL)save
{
    return YES;
}

@end
