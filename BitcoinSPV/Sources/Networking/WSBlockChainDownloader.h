//
//  WSBlockChainDownloader.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 24/08/15.
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

#import "WSPeerGroup.h"

@protocol WSBlockStore;
@class WSParameters;
@protocol WSSynchronizableWallet;
@class WSCoreDataManager;

#pragma mark -

//
// thread-safe: no (should only run in group queue)
//
@interface WSBlockChainDownloader : NSObject <WSPeerGroupDownloader>

@property (nonatomic, strong) WSCoreDataManager *coreDataManager;           // nil
@property (nonatomic, assign) BOOL shouldAutoSaveWallet;                    // YES

// tuning
@property (nonatomic, assign) double bloomFilterRateMin;                    // 0.0001
@property (nonatomic, assign) double bloomFilterRateDelta;                  // 0.0004
@property (nonatomic, assign) double bloomFilterObservedRateMax;            // 0.005
@property (nonatomic, assign) double bloomFilterLowPassRatio;               // 0.01
@property (nonatomic, assign) NSUInteger bloomFilterTxsPerBlock;            // 600
@property (nonatomic, assign) NSTimeInterval requestTimeout;                // 5.0

- (instancetype)initWithStore:(id<WSBlockStore>)store headersOnly:(BOOL)headersOnly;
- (instancetype)initWithStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp;
- (instancetype)initWithStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet;

- (instancetype)initWithStore:(id<WSBlockStore>)store maxSize:(NSUInteger)maxSize headersOnly:(BOOL)headersOnly;
- (instancetype)initWithStore:(id<WSBlockStore>)store maxSize:(NSUInteger)maxSize fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp;
- (instancetype)initWithStore:(id<WSBlockStore>)store maxSize:(NSUInteger)maxSize wallet:(id<WSSynchronizableWallet>)wallet;

@end
