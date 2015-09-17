//
//  WSMemoryBlockStore.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/07/14.
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

#import "WSMemoryBlockStore.h"
#import "WSHash256.h"
#import "WSStorableBlock.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSTransactionOutPoint.h"
#import "WSTransactionInput.h"
#import "WSTransaction.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSMemoryBlockStore ()

@property (nonatomic, strong) WSFilteredBlock *genesisBlock;
@property (nonatomic, strong) NSMutableDictionary *blocks;          // WSHash256 -> WSStorableBlock
@property (nonatomic, strong) NSMutableDictionary *nextIdsById;     // WSHash256 -> WSHash256
@property (nonatomic, strong) WSStorableBlock *head;
@property (nonatomic, strong) WSStorableBlock *tail;

@end

@implementation WSMemoryBlockStore

- (instancetype)init
{
    WSExceptionRaiseUnsupported(@"Use initWithParameters:");
    return nil;
}

- (instancetype)initWithParameters:(WSParameters *)parameters
{
    WSExceptionCheckIllegal(parameters);

    if ((self = [super init])) {
        self.genesisBlock = [parameters genesisBlock];
        [self truncate];
    }
    return self;
}

#pragma mark WSBlockStore

- (WSParameters *)parameters
{
    return self.genesisBlock.parameters;
}

- (WSStorableBlock *)blockForId:(WSHash256 *)blockId
{
    WSExceptionCheckIllegal(blockId);
    
    return self.blocks[blockId];
}

- (void)putBlock:(WSStorableBlock *)block
{
    WSExceptionCheckIllegal(block);

    WSHash256 *blockId = block.blockId;
    self.blocks[blockId] = block;
    self.nextIdsById[block.previousBlockId] = blockId;
}

- (void)setHead:(WSStorableBlock *)head
{
    WSExceptionCheckIllegal(head);
    
    _head = head;
}

- (void)removeTail
{
    NSAssert(self.blocks.count > 0, @"Empty blocks");
    
    WSHash256 *tailId = self.tail.blockId;
    NSAssert(tailId, @"Tail is nil, store truncated without resetting?");
    
    WSHash256 *newTailId = self.nextIdsById[tailId];
    if (!newTailId) {
        WSStorableBlock *block = self.head;
        while (block) {
            newTailId = block.blockId;
            block = self.blocks[block.previousBlockId];
        }
    }
    
    [self.blocks removeObjectForKey:tailId];
    [self.nextIdsById removeObjectForKey:tailId];
    self.tail = self.blocks[newTailId];
}

- (void)findAndRestoreTail
{
    WSStorableBlock *block = self.head;
    WSStorableBlock *tail;
    while (block) {
        tail = block;
        block = self.blocks[block.previousBlockId];
    }
    self.tail = tail;
}

- (NSArray *)allBlocks
{
    return [self.blocks allValues];
}

- (NSUInteger)size
{
    return self.blocks.count;
}

- (void)truncate
{
    self.blocks = [[NSMutableDictionary alloc] init];
    self.nextIdsById = [[NSMutableDictionary alloc] init];
    
    WSStorableBlock *block = [[WSStorableBlock alloc] initWithHeader:self.genesisBlock.header transactions:nil height:0];
    [self putBlock:block];
    self.head = block;
    self.tail = self.head;
}

@end
