//
//  WSBIP37.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 13/06/14.
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

@class WSAddress;
@class WSTransactionOutPoint;

//
// Bloom filtering
//
// https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki
//

#pragma mark -

extern const uint32_t           WSBIP37MaxFilterSize;
extern const uint32_t           WSBIP37MaxHashFunctions;
extern const uint32_t           WSBIP37HashMultiplier;

typedef enum {
    WSBIP37FlagsUpdateNone = 0,
    WSBIP37FlagsUpdateAll,
    WSBIP37FlagsUpdateP2PubKeyOnly
} WSBIP37Flags;

#pragma mark -

@interface WSBIP37FilterParameters : NSObject <NSCopying>

@property (nonatomic, assign) double falsePositiveRate;
@property (nonatomic, assign) uint32_t tweak;
@property (nonatomic, assign) WSBIP37Flags flags;

@end

#pragma mark -

@interface WSBIP37Filter : NSObject <NSCopying, WSBufferEncoder>

- (instancetype)initWithParameters:(WSBIP37FilterParameters *)parameters capacity:(NSUInteger)capacity;
- (instancetype)initWithFullMatch;
- (instancetype)initWithNoMatch;
- (WSBIP37FilterParameters *)parameters;
- (NSUInteger)capacity;

- (NSData *)filter;
- (uint32_t)elements;
- (uint32_t)hashFunctions;

- (void)insertData:(NSData *)data;
- (BOOL)containsData:(NSData *)data;
- (NSUInteger)size;
- (double)estimatedFalsePositiveRate;

@end
