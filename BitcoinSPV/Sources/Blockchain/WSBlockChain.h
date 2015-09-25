//
//  WSBlockChain.h
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

#import <Foundation/Foundation.h>

#import "WSIndentableDescription.h"

@class WSHash256;
@protocol WSBlockStore;
@class WSStorableBlock;
@class WSBlockHeader;
@class WSFilteredBlock;
@class WSBlockLocator;
@class WSCoreDataManager;

#pragma mark -

@protocol WSBlockChainDelegate;

typedef enum {
    WSBlockChainLocationNone,
    WSBlockChainLocationMain,
    WSBlockChainLocationFork,
    WSBlockChainLocationOrphan
} WSBlockChainLocation;

typedef void (^WSBlockChainReorganizeBlock)(WSStorableBlock *, NSArray *, NSArray *);

//
// thread-safe: no (just a business wrapper around a block store)
//
@interface WSBlockChain : NSObject <WSIndentableDescription>

@property (nonatomic, weak) id<WSBlockChainDelegate> delegate;

- (instancetype)initWithStore:(id<WSBlockStore>)store;
- (instancetype)initWithStore:(id<WSBlockStore>)store maxSize:(NSUInteger)maxSize;
- (NSUInteger)maxSize;
- (void)truncate;

- (WSStorableBlock *)head;
- (WSStorableBlock *)blockForId:(WSHash256 *)blockId;
- (NSArray *)allBlockIds;
- (uint32_t)currentHeight;
- (uint32_t)currentTimestamp;
- (WSBlockLocator *)currentLocator;

- (WSStorableBlock *)addCheckpoint:(WSStorableBlock *)checkpoint error:(NSError **)error;
- (WSStorableBlock *)addBlockWithHeader:(WSBlockHeader *)header
                           transactions:(NSOrderedSet *)transactions
                               location:(WSBlockChainLocation *)location
                       connectedOrphans:(NSArray **)connectedOrphans
                        reorganizeBlock:(WSBlockChainReorganizeBlock)reorganizeBlock
                                  error:(NSError **)error;

- (BOOL)isOrphanBlock:(WSStorableBlock *)block;
- (BOOL)isKnownOrphanBlockWithId:(WSHash256 *)blockId;
- (WSStorableBlock *)findForkBaseFromHead:(WSStorableBlock *)forkHead;

- (void)loadFromCoreDataManager:(WSCoreDataManager *)manager;
- (void)saveToCoreDataManager:(WSCoreDataManager *)manager;

- (NSString *)descriptionWithMaxBlocks:(NSUInteger)maxBlocks;
- (NSString *)descriptionWithIndent:(NSUInteger)indent maxBlocks:(NSUInteger)maxBlocks;

@end

#pragma mark -

@protocol WSBlockChainDelegate <NSObject>

- (void)blockChain:(WSBlockChain *)blockChain didAddNewBlock:(WSStorableBlock *)block location:(WSBlockChainLocation)location;
- (void)blockChain:(WSBlockChain *)blockChain didReplaceHead:(WSStorableBlock *)head;
- (void)blockChain:(WSBlockChain *)blockChain didReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks;

@end
