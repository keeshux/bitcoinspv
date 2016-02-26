//
//  WSPeerGroup.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 24/06/14.
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

#import "WSPeerGroupNotifier.h"
#import "WSPeer.h"
#import "WSReachability.h"
#import "WSBlockChain.h"

@class WSParameters;
@class WSConnectionPool;
@protocol WSPeerGroupDownloader;
@protocol WSPeerGroupDownloadDelegate;

#pragma mark -

@interface WSPeerInfo : NSObject

- (NSString *)host;
- (uint16_t)port;
- (NSString *)userAgent;
- (uint32_t)lastBlockHeight;
- (BOOL)isDownloadPeer;

@end

#pragma mark -

@interface WSPeerGroupStatus : NSObject

- (WSParameters *)parameters;
- (BOOL)isConnected;
- (BOOL)isDownloading;
- (uint32_t)currentHeight;
- (uint32_t)targetHeight;
- (double)downloadProgress;
- (NSArray *)recentBlocks;
- (NSUInteger)sentBytes;
- (NSUInteger)receivedBytes;
- (NSArray *)peersInfo;
- (WSPeerInfo *)downloadPeerInfo;

@end

#pragma mark -

//
// All is done on private queue except public methods that can be run from any queue.
//
// NEVER invoke public methods internally, deadlock is guaranteed due to dispatch_sync.
//

@interface WSPeerGroup : NSObject <WSPeerDelegate, WSReachabilityDelegate>

// WARNING: set properties before starting connections

@property (nonatomic, strong) NSArray *peerHosts;                           // nil
@property (nonatomic, assign) NSUInteger maxConnections;                    // 3
@property (nonatomic, assign) NSUInteger maxConnectionFailures;             // 20
@property (nonatomic, assign) NSTimeInterval reconnectionDelayOnFailure;    // 10.0
@property (nonatomic, assign) NSTimeInterval seedTTL;                       // 600.0 (10 minutes)
@property (nonatomic, assign) BOOL needsBloomFiltering;                     // NO

// WARNING: queue must be of type DISPATCH_QUEUE_SERIAL
- (instancetype)initWithParameters:(WSParameters *)parameters;
- (instancetype)initWithParameters:(WSParameters *)parameters pool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue;

// connection
- (BOOL)startConnections;
- (BOOL)stopConnections;
- (void)stopConnectionsWithCompletionBlock:(void (^)())completionBlock;
- (BOOL)isStarted;
- (BOOL)isConnected;
- (NSUInteger)numberOfConnections;
- (BOOL)hasReachedMaxConnections;

// download
- (BOOL)startDownloadWithDownloader:(id<WSPeerGroupDownloader>)downloader;
- (void)stopDownload;
- (BOOL)isDownloading;
- (uint32_t)currentHeight;
- (NSUInteger)numberOfBlocksLeft;
- (BOOL)isSynced;
- (BOOL)reconnectForDownload;
- (BOOL)rescanBlockChain;

// interaction
- (WSPeerGroupStatus *)statusWithNumberOfRecentBlocks:(NSUInteger)numberOfRecentBlocks;
- (BOOL)publishTransaction:(WSSignedTransaction *)transaction;
- (BOOL)publishTransaction:(WSSignedTransaction *)transaction safely:(BOOL)safely;
- (void)saveState;

//
// WARNING: do not nil out peerGroup strong references until disconnection!
//
// WSPeer objects would not call peer:didDisconnectWithError: because peerGroup is
// their (weak) delegate and would be deallocated prematurely
//
// as a consequence, peerGroup wouldn't exist anymore and would never report
// any WSPeerGroupDidDisconnectNotification resulting in completionBlock
// never called
//

@end

#pragma mark -

//
// every method is executed in group queue
//
@protocol WSPeerGroupDownloadDelegate <NSObject>

- (void)peerGroup:(WSPeerGroup *)peerGroup peerDidConnect:(WSPeer *)peer;
- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didDisconnectWithError:(NSError *)error;
- (void)peerGroup:(WSPeerGroup *)peerGroup peerDidKeepAlive:(WSPeer *)peer;

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveHeaders:(NSArray *)headers;
- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveInventories:(NSArray *)inventories;
- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveBlock:(WSBlock *)block;
- (BOOL)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer shouldAddTransaction:(WSSignedTransaction *)transaction toFilteredBlock:(WSFilteredBlock *)filteredBlock;
- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions;
- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveTransaction:(WSSignedTransaction *)transaction;
- (BOOL)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer shouldAcceptHeader:(WSBlockHeader *)header error:(NSError **)error;

@end

//
// every method is executed in group queue
//
@protocol WSPeerGroupDownloader <WSPeerGroupDownloadDelegate>

- (WSParameters *)parameters;
- (void)startWithPeerGroup:(WSPeerGroup *)peerGroup;
- (void)stop;
- (uint32_t)lastBlockHeight;
- (uint32_t)currentHeight;
- (NSUInteger)numberOfBlocksLeft;
- (BOOL)isSynced;
- (BOOL)isPeerDownloadPeer:(WSPeer *)peer;
- (NSArray *)recentBlocksWithCount:(NSUInteger)count;
- (void)reconnectForDownload;
- (void)rescanBlockChain;
- (void)saveState;

@end
