//
//  WSPeerGroup.h
//  WaSPV
//
//  Created by Davide De Rosa on 24/06/14.
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

#import "WSPeerGroupNotifier.h"
#import "WSPeer.h"
#import "WSReachability.h"
#import "WSBlockChain.h"

@class WSConnectionPool;
@protocol WSBlockStore;
@protocol WSSynchronizableWallet;

@interface WSPeerGroup : NSObject <WSPeerDelegate, WSReachabilityDelegate>

// WARNING: set properties before starting connections

// group related
@property (nonatomic, assign) BOOL shouldReconnectOnBecomeActive;           // NO
@property (nonatomic, assign) BOOL shouldDisconnectOnEnterBackground;       // NO
@property (nonatomic, strong) NSArray *peerHosts;                           // nil
@property (nonatomic, assign) NSUInteger maxConnections;                    // 3
@property (nonatomic, assign) NSUInteger maxConnectionFailures;             // 20
@property (nonatomic, assign) NSTimeInterval reconnectionDelayOnFailure;    // 10.0
@property (nonatomic, assign) double bloomFilterRateMin;                    // 0.0001
@property (nonatomic, assign) double bloomFilterRateDelta;                  // 0.0004
@property (nonatomic, assign) double bloomFilterObservedRateMax;            // 0.005
@property (nonatomic, assign) double bloomFilterLowPassRatio;               // 0.01
@property (nonatomic, assign) NSUInteger bloomFilterTxsPerBlock;            // 600

// peer related
@property (nonatomic, assign) BOOL headersOnly;                             // NO

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store;
- (instancetype)initWithBlockStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp;
- (instancetype)initWithBlockStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet;

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store pool:(WSConnectionPool *)pool;
- (instancetype)initWithBlockStore:(id<WSBlockStore>)store pool:(WSConnectionPool *)pool fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp;
- (instancetype)initWithBlockStore:(id<WSBlockStore>)store pool:(WSConnectionPool *)pool wallet:(id<WSSynchronizableWallet>)wallet;

// connection
- (BOOL)startConnections;
- (BOOL)stopConnections;
- (BOOL)isStarted;
- (BOOL)isConnected;

// sync
- (BOOL)startBlockChainDownload;
- (BOOL)stopBlockChainDownload;
- (BOOL)isDownloading;
- (BOOL)isSynced;
- (uint32_t)fastCatchUpTimestamp;
- (BOOL)rescan;

// interaction
- (NSUInteger)currentHeight;
- (BOOL)publishTransaction:(WSSignedTransaction *)transaction;

@end
