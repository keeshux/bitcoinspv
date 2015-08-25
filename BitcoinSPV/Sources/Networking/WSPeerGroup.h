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

@protocol WSParameters;
@class WSConnectionPool;
@protocol WSPeerGroupDownloadDelegate;

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
@property (nonatomic, weak) id<WSPeerGroupDownloadDelegate> downloadDelegate;

// WARNING: queue must be of type DISPATCH_QUEUE_SERIAL
- (instancetype)initWithParameters:(id<WSParameters>)parameters;
- (instancetype)initWithParameters:(id<WSParameters>)parameters pool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue;

- (BOOL)startConnections;
- (BOOL)stopConnections;
- (void)stopConnectionsWithCompletionBlock:(void (^)())completionBlock;
- (BOOL)isStarted;
- (BOOL)isConnected;
- (NSUInteger)numberOfConnections;
- (BOOL)hasReachedMaxConnections;

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

@protocol WSPeerGroupDownloadDelegate <NSObject>

- (void)peerGroup:(WSPeerGroup *)peerGroup didRequestFilterReloadForPeer:(WSPeer *)peer;

@end
