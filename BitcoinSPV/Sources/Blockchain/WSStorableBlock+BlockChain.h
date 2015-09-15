//
//  WSStorableBlock+BlockChain.h
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

#import <Foundation/Foundation.h>

#import "WSStorableBlock.h"

@class WSBlockChain;

@interface WSStorableBlock (BlockChain)

- (WSStorableBlock *)previousBlockInChain:(WSBlockChain *)blockChain;
- (WSStorableBlock *)previousBlockInChain:(WSBlockChain *)blockChain maxStep:(NSUInteger)maxStep lastPreviousBlock:(WSStorableBlock **)lastPreviousBlock;
- (BOOL)isBehindBlock:(WSStorableBlock *)block inChain:(WSBlockChain *)blockChain;
- (BOOL)isOrphanInChain:(WSBlockChain *)blockChain;
- (BOOL)validateTargetInChain:(WSBlockChain *)blockChain error:(NSError **)error;
- (BOOL)validateTargetFromPreviousBlock:(WSStorableBlock *)previousBlock retargetBlock:(WSStorableBlock *)retargetBlock error:(NSError **)error;

@end
