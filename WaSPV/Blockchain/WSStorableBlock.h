//
//  WSStorableBlock.h
//  WaSPV
//
//  Created by Davide De Rosa on 11/07/14.
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

#import <Foundation/Foundation.h>

#import "WSIndentableDescription.h"

@class WSBlockHeader;
@class WSFilteredBlock;
@class WSCheckpoint;
@class WSBlockChain;
@protocol WSTransaction;

#pragma mark -

@interface WSStorableBlock : NSObject <WSIndentableDescription>

- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions;
- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions height:(uint32_t)height;
- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions height:(uint32_t)height work:(NSData *)work;
- (instancetype)initWithCheckpoint:(WSCheckpoint *)checkpoint inChain:(WSBlockChain *)chain;

- (WSBlockHeader *)header;
- (uint32_t)height;
- (NSData *)workData;
- (NSString *)workString;
- (NSOrderedSet *)transactions; // WSSignedTransaction

- (WSHash256 *)blockId;
- (WSHash256 *)previousBlockId;
- (BOOL)isTransitionBlock;
- (BOOL)hasMoreWorkThanBlock:(WSStorableBlock *)block;
- (WSStorableBlock *)buildNextBlockFromHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions;

- (WSStorableBlock *)previousBlockInChain:(WSBlockChain *)blockChain;
- (WSStorableBlock *)previousBlockInChain:(WSBlockChain *)blockChain maxStep:(NSUInteger)maxStep lastPreviousBlock:(WSStorableBlock **)lastPreviousBlock;
- (BOOL)validateTargetInChain:(WSBlockChain *)blockChain error:(NSError **)error;

@end
