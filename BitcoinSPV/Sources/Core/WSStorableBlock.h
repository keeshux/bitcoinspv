//
//  WSStorableBlock.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 11/07/14.
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

#import "WSBuffer.h"
#import "WSSized.h"
#import "WSIndentableDescription.h"

@class WSHash256;
@class WSBlockHeader;
@class WSFilteredBlock;
@protocol WSTransaction;

#pragma mark -

@interface WSStorableBlock : NSObject <WSBufferEncoder, WSBufferDecoder, WSSized, WSIndentableDescription>

- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions;
- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions height:(uint32_t)height;
- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions height:(uint32_t)height work:(NSData *)work;

- (WSParameters *)parameters;
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

@end
