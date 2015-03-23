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

@protocol WSParameters;
@class WSConnectionPool;
@protocol WSBlockStore;
@protocol WSSynchronizableWallet;

#pragma mark -

@interface WSPeerGroupStatus : NSObject

- (id<WSParameters>)parameters;
- (BOOL)isConnected;
- (BOOL)isDownloading;
- (NSUInteger)currentHeight;
- (NSUInteger)targetHeight;
- (double)downloadProgress;
- (NSArray *)recentBlocks;
- (NSUInteger)sentBytes;
- (NSUInteger)receivedBytes;

@end

#pragma mark -

//
// All is done on groupQueue except public methods that can be run from any queue.
//
// NEVER invoke public methods internally, deadlock is guaranteed due to dispatch_sync.
//

@interface WSPeerGroup : NSObject <WSPeerDelegate, WSReachabilityDelegate>

// WARNING: set properties before starting connections

// group related
@property (nonatomic, strong) NSArray *peerHosts;                           // nil
@property (nonatomic, assign) NSUInteger maxConnections;                    // 3
@property (nonatomic, assign) NSUInteger maxConnectionFailures;             // 20
@property (nonatomic, assign) NSTimeInterval reconnectionDelayOnFailure;    // 10.0
@property (nonatomic, assign) double bloomFilterRateMin;                    // 0.0001
@property (nonatomic, assign) double bloomFilterRateDelta;                  // 0.0004
@property (nonatomic, assign) double bloomFilterObservedRateMax;            // 0.005
@property (nonatomic, assign) double bloomFilterLowPassRatio;               // 0.01
@property (nonatomic, assign) NSUInteger bloomFilterTxsPerBlock;            // 600
@property (nonatomic, assign) NSUInteger blockStoreSize;                    // 2500

// peer related
@property (nonatomic, assign) BOOL headersOnly;                             // NO
@property (nonatomic, assign) NSTimeInterval requestTimeout;                // 15.0

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store;
- (instancetype)initWithBlockStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp;
- (instancetype)initWithBlockStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet;

- (instancetype)initWithPool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue blockStore:(id<WSBlockStore>)store;
- (instancetype)initWithPool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue blockStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp;
- (instancetype)initWithPool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue blockStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet;

// connection
- (BOOL)startConnections;
- (BOOL)stopConnections;
- (void)stopConnectionsWithCompletionBlock:(void (^)())completionBlock;
- (BOOL)isStarted;
- (BOOL)isConnected;
- (NSUInteger)numberOfConnections;
- (BOOL)hasReachedMaxConnections;

// sync
- (BOOL)startBlockChainDownload;
- (BOOL)stopBlockChainDownload;
- (BOOL)isDownloading;
- (BOOL)isSynced;
- (BOOL)reconnectForDownload;
- (BOOL)rescan;

// interaction
- (WSPeerGroupStatus *)statusWithNumberOfRecentBlocks:(NSUInteger)numberOfRecentBlocks;
- (NSUInteger)currentHeight;
- (BOOL)controlsWallet:(id<WSSynchronizableWallet>)wallet;
- (BOOL)publishTransaction:(WSSignedTransaction *)transaction;

@end
