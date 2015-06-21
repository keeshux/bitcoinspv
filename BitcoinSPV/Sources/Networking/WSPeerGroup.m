//
//  WSPeerGroup.m
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

#import <arpa/inet.h>
#import <errno.h>

#import "WSPeerGroup.h"
#import "WSBlockStore.h"
#import "WSConnectionPool.h"
#import "WSWallet.h"
#import "WSHDWallet.h"
#import "WSHash256.h"
#import "WSPeer.h"
#import "WSBloomFilter.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSPartialMerkleTree.h"
#import "WSStorableBlock.h"
#import "WSStorableBlock+BlockChain.h"
#import "WSTransaction.h"
#import "WSBlockLocator.h"
#import "WSInventory.h"
#import "WSNetworkAddress.h"
#import "WSConfig.h"
#import "WSLogging.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSPeerGroupStatus ()

@property (nonatomic, strong) id<WSParameters> parameters;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isDownloading;
@property (nonatomic, assign) NSUInteger currentHeight;
@property (nonatomic, assign) NSUInteger targetHeight;
@property (nonatomic, assign) double downloadProgress;
@property (nonatomic, strong) NSArray *recentBlocks;
@property (nonatomic, assign) NSUInteger sentBytes;
@property (nonatomic, assign) NSUInteger receivedBytes;

@end

@implementation WSPeerGroupStatus

@end

#pragma mark -

@interface WSPeerGroup () {
    WSPeer *_downloadPeer;
}

@property (nonatomic, strong) id<WSParameters> parameters;
@property (nonatomic, strong) WSPeerGroupNotifier *notifier;
@property (nonatomic, strong) WSConnectionPool *pool;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) id<WSBlockStore> store;
@property (nonatomic, strong) WSBlockChain *blockChain;
@property (nonatomic, strong) id<WSSynchronizableWallet> wallet;
@property (nonatomic, strong) WSReachability *reachability;

// connection
@property (nonatomic, assign) BOOL keepConnected;
@property (nonatomic, assign) NSUInteger activeDnsResolutions;
@property (nonatomic, assign) NSUInteger connectionFailures;
@property (nonatomic, strong) NSMutableOrderedSet *inactiveAddresses;       // WSNetworkAddress
@property (nonatomic, strong) NSMutableSet *misbehavingHosts;               // NSString
@property (nonatomic, strong) NSMutableSet *pendingPeers;                   // WSPeer
@property (nonatomic, strong) NSMutableSet *connectedPeers;                 // WSPeer
@property (nonatomic, strong) NSMutableDictionary *publishedTransactions;   // WSHash256 -> WSSignedTransaction
@property (nonatomic, assign) NSUInteger sentBytes;
@property (nonatomic, assign) NSUInteger receivedBytes;

// sync
@property (nonatomic, assign) uint32_t fastCatchUpTimestamp;
@property (nonatomic, assign) BOOL keepDownloading;
@property (nonatomic, strong) WSPeer *downloadPeer;
@property (nonatomic, assign) BOOL didNotifyDownloadFinished;
@property (nonatomic, strong) WSBIP37FilterParameters *bloomFilterParameters;
@property (nonatomic, strong) WSBloomFilter *bloomFilter; // immutable, thread-safe
@property (nonatomic, assign) NSUInteger observedFilterHeight;
@property (nonatomic, assign) double observedFalsePositiveRate;
@property (nonatomic, assign) NSTimeInterval lastKeepAliveTime;

- (void)connect;
- (void)disconnect;
- (void)discoverNewHostsWithResolutionCallback:(void (^)(NSString *, NSArray *))resolutionCallback failure:(void (^)(NSError *))failure;
- (void)triggerConnectionsFromSeed:(NSString *)seed addresses:(NSArray *)addresses;
- (void)triggerConnectionsFromInactive;
- (void)openConnectionToPeerHost:(NSString *)host;
- (void)handleConnectionFailureFromPeer:(WSPeer *)peer error:(NSError *)error;
- (void)reconnectAfterDelay:(NSTimeInterval)delay;
- (NSArray *)disconnectedAddressesWithHosts:(NSArray *)hosts;
- (void)removeInactiveHost:(NSString *)host;
- (BOOL)isInactiveHost:(NSString *)host;
- (BOOL)isPendingHost:(NSString *)host;
- (BOOL)isConnectedHost:(NSString *)host;
- (WSPeer *)bestPeer;
+ (BOOL)isHardNetworkError:(NSError *)error;

- (void)loadFilterAndStartDownload;
- (void)resetBloomFilter;
- (void)reloadBloomFilter;
- (BOOL)maybeResetAndSendBloomFilter;
- (BOOL)shouldDownloadBlocks;
- (BOOL)needsBloomFiltering;
- (void)detectDownloadTimeout;
- (void)trySaveBlockChainToCoreData;

- (BOOL)validateHeaderAgainstCheckpoints:(WSBlockHeader *)header error:(NSError **)error;
- (void)handleAddedBlock:(WSStorableBlock *)block fromPeer:(WSPeer *)peer;
- (void)handleReplacedBlock:(WSStorableBlock *)block fromPeer:(WSPeer *)peer;
- (void)handleReceivedTransaction:(WSSignedTransaction *)transaction fromPeer:(WSPeer *)peer;
- (void)handleReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks fromPeer:(WSPeer *)peer;
- (void)handleMisbehavingPeer:(WSPeer *)peer error:(NSError *)error;
- (BOOL)findAndRemovePublishedTransaction:(WSSignedTransaction *)transaction fromPeer:(WSPeer *)peer;
- (void)recoverMissedBlockTransactions:(WSStorableBlock *)block fromPeer:(WSPeer *)peer;

- (BOOL)unsafeIsConnected;
- (BOOL)unsafeHasReachedMaxConnections;
- (BOOL)unsafeIsSynced;
- (NSUInteger)unsafeNumberOfBlocksLeft;

@end

@implementation WSPeerGroup

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store
{
    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:store.parameters];
    NSString *className = [self.class description];
    dispatch_queue_t queue = dispatch_queue_create(className.UTF8String, DISPATCH_QUEUE_SERIAL);

    return [self initWithPool:pool queue:queue blockStore:store];
}

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:store.parameters];
    NSString *className = [self.class description];
    dispatch_queue_t queue = dispatch_queue_create(className.UTF8String, DISPATCH_QUEUE_SERIAL);

    return [self initWithPool:pool queue:queue blockStore:store fastCatchUpTimestamp:fastCatchUpTimestamp];
}

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet
{
    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:store.parameters];
    NSString *className = [self.class description];
    dispatch_queue_t queue = dispatch_queue_create(className.UTF8String, DISPATCH_QUEUE_SERIAL);

    return [self initWithPool:pool queue:queue blockStore:store wallet:wallet];
}

- (instancetype)initWithPool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue blockStore:(id<WSBlockStore>)store
{
    return [self initWithPool:pool queue:queue blockStore:store wallet:nil];
}

- (instancetype)initWithPool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue blockStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    if ((self = [self initWithPool:pool queue:queue blockStore:store wallet:nil])) {
        self.fastCatchUpTimestamp = fastCatchUpTimestamp;
    }
    return self;
}

- (instancetype)initWithPool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue blockStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet
{
    WSExceptionCheckIllegal(pool);
    WSExceptionCheckIllegal(queue);
    WSExceptionCheckIllegal(store);
    
    if ((self = [super init])) {
        self.parameters = store.parameters;
        self.notifier = [[WSPeerGroupNotifier alloc] initWithPeerGroup:self];
        self.pool = pool;
        self.pool.connectionTimeout = WSPeerConnectTimeout;
        self.queue = queue;

        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        if (wallet) {
            self.wallet = wallet;
            self.fastCatchUpTimestamp = [self.wallet earliestKeyTimestamp];
        }
        else {
            self.fastCatchUpTimestamp = 0; // block #0
        }

        self.reachability = [WSReachability reachabilityForInternetConnection];
        self.reachability.delegate = self;
        self.reachability.delegateQueue = self.queue;
        
        // group related
        self.peerHosts = nil;
        self.maxConnections = WSPeerGroupDefaultMaxConnections;
        self.maxConnectionFailures = WSPeerGroupDefaultMaxConnectionFailures;
        self.reconnectionDelayOnFailure = WSPeerGroupDefaultReconnectionDelay;
        self.bloomFilterRateMin = WSPeerGroupDefaultBFRateMin;
        self.bloomFilterRateDelta = WSPeerGroupDefaultBFRateDelta;
        self.bloomFilterObservedRateMax = WSPeerGroupDefaultBFObservedRateMax;
        self.bloomFilterLowPassRatio = WSPeerGroupDefaultBFLowPassRatio;
        self.bloomFilterTxsPerBlock = WSPeerGroupDefaultBFTxsPerBlock;
        self.blockStoreSize = 2500;

        // peer related
        self.headersOnly = NO;
        self.requestTimeout = WSPeerGroupDefaultRequestTimeout;
        
        self.keepConnected = NO;
        self.connectionFailures = 0;
        self.inactiveAddresses = [[NSMutableOrderedSet alloc] init];
        self.misbehavingHosts = [[NSMutableSet alloc] init];
        self.pendingPeers = [[NSMutableSet alloc] init];
        self.connectedPeers = [[NSMutableSet alloc] init];
        self.publishedTransactions = [[NSMutableDictionary alloc] init];

        self.keepDownloading = NO;
        self.downloadPeer = nil;
        if (self.wallet) {
            self.bloomFilterParameters = [[WSBIP37FilterParameters alloc] init];
#if BSPV_WALLET_FILTER == BSPV_WALLET_FILTER_UNSPENT
            self.bloomFilterParameters.flags = WSBIP37FlagsUpdateAll;
#endif
        }
        
        [self.reachability startNotifier];
    }
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self disconnect];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.reachability stopNotifier];
}

- (void)setCoreDataManager:(WSCoreDataManager *)coreDataManager
{
    _coreDataManager = coreDataManager;
    
    [self.blockChain loadFromCoreDataManager:coreDataManager];
}

- (void)setPeerHosts:(NSArray *)peerHosts
{
    _peerHosts = peerHosts;
    
    self.maxConnections = _peerHosts.count;
}

#pragma mark Connection

- (BOOL)startConnections
{
    dispatch_sync(self.queue, ^{
        self.keepConnected = YES;
        [self connect];
    });
    return YES;
}

- (BOOL)stopConnections
{
    dispatch_sync(self.queue, ^{
        self.keepDownloading = NO;
        self.keepConnected = NO;
        [self disconnect];
    });
    return YES;
}

//
// WARNING
//
// do not nil peerGroup strong references until disconnection!
//
// WSPeer objects would not call peer:didDisconnectWithError: because peerGroup is
// their (weak) delegate and would be deallocated prematurely
//
// as a consequence, peerGroup wouldn't exist anymore and would never report
// any WSPeerGroupDidDisconnectNotification resulting in completionBlock
// never called
//
- (void)stopConnectionsWithCompletionBlock:(void (^)())completionBlock
{
    __block id observer;
    __block void (^onceCompletionBlock)() = completionBlock;
    __block BOOL notConnected = NO;

    dispatch_sync(self.queue, ^{
        self.keepDownloading = NO;
        self.keepConnected = NO;
        [self disconnect];

        if ([self unsafeIsConnected]) {
            __weak NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

            observer = [nc addObserverForName:WSPeerGroupDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                [nc removeObserver:observer];
                [self trySaveBlockChainToCoreData];

                if (onceCompletionBlock) {
                    onceCompletionBlock();
                    onceCompletionBlock = NULL;
                }
            }];
        }
        else {
            notConnected = YES;
        }
    });
    
    if (notConnected && onceCompletionBlock) {
        [self trySaveBlockChainToCoreData];

        onceCompletionBlock();
        onceCompletionBlock = NULL;
    }
}

- (BOOL)isStarted
{
    __block BOOL isStarted;
    dispatch_sync(self.queue, ^{
        isStarted = self.keepConnected;
    });
    return isStarted;
}

- (BOOL)isConnected
{
    __block BOOL isConnected;
    dispatch_sync(self.queue, ^{
        isConnected = [self unsafeIsConnected];
    });
    return isConnected;
}

- (NSUInteger)numberOfConnections
{
    __block NSUInteger numberOfConnections;
    dispatch_sync(self.queue, ^{
        numberOfConnections = self.connectedPeers.count;
    });
    return numberOfConnections;
}

- (BOOL)hasReachedMaxConnections
{
    __block BOOL hasReachedMaxConnections;
    dispatch_sync(self.queue, ^{
        hasReachedMaxConnections = [self unsafeHasReachedMaxConnections];
    });
    return hasReachedMaxConnections;
}

#pragma mark Synchronization

- (BOOL)startBlockChainDownload
{
    __block BOOL started = NO;
    dispatch_sync(self.queue, ^{
        if (self.keepDownloading) {
            DDLogVerbose(@"Ignoring call because already downloading");
            return;
        }

        self.keepDownloading = YES;
        self.didNotifyDownloadFinished = NO;

        if (self.downloadPeer) {
            [self loadFilterAndStartDownload];
        }
        else {
            DDLogInfo(@"Delayed download until peer selection");
        }
        started = YES;
    });
    return started;
}

- (BOOL)stopBlockChainDownload
{
    __block BOOL stopped = NO;
    dispatch_sync(self.queue, ^{
        self.keepDownloading = NO;
        if (self.downloadPeer) {

            // not reconnecting without error
            [self.pool closeConnectionForProcessor:self.downloadPeer
                                             error:WSErrorMake(WSErrorCodePeerGroupStop, @"Download stopped")];
        }
        stopped = YES;
    });
    return stopped;
}

- (BOOL)isDownloading
{
    __block BOOL isDownloading;
    dispatch_sync(self.queue, ^{
        isDownloading = self.keepDownloading;
    });
    return isDownloading;
}

- (BOOL)isSynced
{
    __block BOOL isSynced;
    dispatch_sync(self.queue, ^{
        isSynced = [self unsafeIsSynced];
    });
    return isSynced;
}

- (BOOL)reconnectForDownload
{
    __block BOOL reconnected = NO;
    dispatch_sync(self.queue, ^{
        if (!self.keepConnected) {
            DDLogVerbose(@"Ignoring call because not connected");
            return;
        }
        [self.pool closeConnectionForProcessor:self.downloadPeer
                                         error:WSErrorMake(WSErrorCodePeerGroupSync, @"Rehashing download peer")];
        reconnected = YES;
    });
    return reconnected;
}

- (BOOL)rescan
{
    __block BOOL rescanned = NO;
    dispatch_sync(self.queue, ^{
        if (!self.keepConnected) {
            DDLogVerbose(@"Ignoring call because not connected");
            return;
        }
        [self.pool closeConnectionForProcessor:self.downloadPeer
                                         error:WSErrorMake(WSErrorCodePeerGroupRescan, @"Preparing for rescan")];
        rescanned = YES;
    });
    return rescanned;
}

#pragma mark Interaction

- (WSPeerGroupStatus *)statusWithNumberOfRecentBlocks:(NSUInteger)numberOfRecentBlocks
{
    WSPeerGroupStatus *status = [[WSPeerGroupStatus alloc] init];
    dispatch_sync(self.queue, ^{
        status.parameters = self.parameters;
        status.isConnected = (self.connectedPeers.count > 0);
        status.isDownloading = self.keepDownloading;
        status.currentHeight = self.blockChain.currentHeight;
        if (status.isConnected) {
            status.targetHeight = self.downloadPeer.lastBlockHeight;
            status.downloadProgress = [self.notifier downloadProgressAtHeight:status.currentHeight];
        }

        if (numberOfRecentBlocks > 0) {
            NSMutableArray *recentBlocks = [[NSMutableArray alloc] initWithCapacity:numberOfRecentBlocks];
            WSStorableBlock *block = self.blockChain.head;
            while (block && (recentBlocks.count < numberOfRecentBlocks)) {
                [recentBlocks addObject:block];
                block = [block previousBlockInChain:self.blockChain];
            }
            status.recentBlocks = recentBlocks;
        }

        status.sentBytes = self.sentBytes;
        status.receivedBytes = self.receivedBytes;
    });
    return status;
}

- (NSUInteger)currentHeight
{
    __block NSUInteger currentHeight;
    dispatch_sync(self.queue, ^{
        currentHeight = self.blockChain.currentHeight;
    });
    return currentHeight;
}

- (NSUInteger)numberOfBlocksLeft
{
    __block NSUInteger numberOfBlocksLeft = 0;
    dispatch_sync(self.queue, ^{
        numberOfBlocksLeft = [self unsafeNumberOfBlocksLeft];
    });
    return numberOfBlocksLeft;
}

- (BOOL)controlsWallet:(id<WSSynchronizableWallet>)wallet
{
    WSExceptionCheckIllegal(wallet);
    
    // immutable property
    return (self.wallet == wallet);
}

- (BOOL)publishTransaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction);

    __block BOOL published = NO;
    dispatch_sync(self.queue, ^{
        if (!self.keepConnected || ![self unsafeIsSynced] || self.publishedTransactions[transaction.txId]) {
            return;
        }

        self.publishedTransactions[transaction.txId] = transaction;
    
        // exclude one random peer to receive tx broadcast back
        const NSUInteger excluded = mrand48() % self.connectedPeers.count;

        NSUInteger i = 0;
        for (WSPeer *peer in self.connectedPeers) {
            if (i != excluded) {
                [peer sendInvMessageWithInventory:WSInventoryTx(transaction.txId)];
            }
            ++i;
        }
        published = YES;
    });
    return published;
}

- (void)saveState
{
    [self trySaveBlockChainToCoreData];
}

#pragma mark Events (group queue)

- (void)peerDidConnect:(WSPeer *)peer
{
    [self removeInactiveHost:peer.remoteHost];
    [self.pendingPeers removeObject:peer];
    [self.connectedPeers addObject:peer];
    
    DDLogInfo(@"Connected to %@ at height %u (active: %u)", peer, peer.lastBlockHeight, self.connectedPeers.count);
    DDLogInfo(@"Active peers: %@", self.connectedPeers);

    self.connectionFailures = 0;

    // group gets connected on first connection
    const BOOL hasReachedMaxConnections = (self.connectedPeers.count == self.maxConnections);
    [self.notifier notifyPeerConnected:peer reachedMaxConnections:hasReachedMaxConnections];
    if (self.connectedPeers.count == 1) {
        [self.notifier notifyConnected];
    }

    NSError *error;
    if (peer.version < WSPeerMinProtocol) {
        error = WSErrorMake(WSErrorCodeNetworking, @"Peer %@ uses unsupported protocol version %u", self, peer.version);
    }
    if ((peer.services & WSPeerServicesNodeNetwork) == 0) {
        error = WSErrorMake(WSErrorCodeNetworking, @"Peer %@ does not provide full node services", self);
    }
    if (peer.lastBlockHeight < self.blockChain.currentHeight) {
        error = WSErrorMake(WSErrorCodePeerGroupSync, @"Peer %@ is behind us (height: %u < %u)", self, peer.lastBlockHeight, self.blockChain.currentHeight);
    }
    if (error) {
        [self.pool closeConnectionForProcessor:peer error:error];
        return;
    }
    
    // peer was accepted
    
    if (self.downloadPeer && (peer.lastBlockHeight <= self.downloadPeer.lastBlockHeight)) {
        DDLogDebug(@"Peer %@ is not ahead of current download peer, marked common (height: %u <= %u)",
                   peer, peer.lastBlockHeight, self.downloadPeer.lastBlockHeight);

        if ([self unsafeIsSynced]) {
            if ([self needsBloomFiltering]) {
                DDLogDebug(@"Loading Bloom filter for common peer %@", peer);
                [peer sendFilterloadMessageWithFilter:self.bloomFilter];
            }
            DDLogDebug(@"Requesting mempool from common peer %@", peer);
            [peer sendMempoolMessage];
        }
        return;
    }
    
    [peer sendGetaddr];
    
    // find/improve download peer from now on
    
    // NOTE: to start download immediately, download peer is initially set to first
    // connected peer and only switched to a new one on timeout/failure
    
    WSPeer *bestPeer = [self bestPeer];
    NSAssert(bestPeer, @"We've just connected, there must be at least one connected peer");

    // no improvement
    if (self.downloadPeer == bestPeer) {
        return;
    }

    // no current download peer, set to best peer immediately
    if (!self.downloadPeer) {
        self.downloadPeer = bestPeer;
        DDLogInfo(@"Selected new download peer: %@", _downloadPeer);

        if (self.keepDownloading) {
            [self loadFilterAndStartDownload];
        }
    }
    // download peer is set but not best, if synced disconnect and switch to new best after disconnection
    else {

        // WARNING
        //
        // disconnecting during download is a major waste of time and bandwidth
        // only force disconnection if current download peer is behind best peer
        //
        if ([self unsafeIsSynced] || (bestPeer.lastBlockHeight > self.downloadPeer.lastBlockHeight)) {
            [self.pool closeConnectionForProcessor:self.downloadPeer
                                             error:WSErrorMake(WSErrorCodePeerGroupSync, @"Found a better download peer than %@", self.downloadPeer)];
        }
    }
}

- (void)peer:(WSPeer *)peer didFailToConnectWithError:(NSError *)error
{
    [peer cleanUpConnectionData];
    [self.pendingPeers removeObject:peer];

    DDLogInfo(@"Failed to connect to %@%@", peer, WSStringOptional(error, @" (%@)"));

    [self handleConnectionFailureFromPeer:peer error:error];
}

- (void)peer:(WSPeer *)peer didDisconnectWithError:(NSError *)error
{
    [peer cleanUpConnectionData];
    [self.pendingPeers removeObject:peer];
    [self.connectedPeers removeObject:peer];

    DDLogInfo(@"Disconnected from %@ (active: %u)%@", peer, self.connectedPeers.count, WSStringOptional(error, @" (%@)"));
    DDLogInfo(@"Active peers: %@", self.connectedPeers);
    
    // group gets disconnected on last disconnection
    [self.notifier notifyPeerDisconnected:peer];
    if (self.connectedPeers.count == 0) {
        [self.notifier notifyDisconnected];
    }

    if (error && (error.domain == WSErrorDomain)) {
        DDLogDebug(@"Disconnection due to known error (%@)", error);
        [self removeInactiveHost:peer.remoteHost];
    }

    if (error.code == WSErrorCodePeerGroupRescan) {
        DDLogDebug(@"Rescan, preparing to truncate blockchain and wallet (if any)");
        
        [self.store truncate];
        [self.wallet removeAllTransactions];
        
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        NSAssert(self.blockChain.currentHeight == 0, @"Expected genesis blockchain");
        
        DDLogDebug(@"Rescan, truncate complete");
        [self.notifier notifyRescan];
    }
    
    if (peer == self.downloadPeer) {
        DDLogDebug(@"Peer %@ was download peer", peer);

        if (self.connectedPeers.count == 0) {
            self.downloadPeer = nil;
            if (!self.keepDownloading) {
                [self.notifier notifyDownloadFailedWithError:WSErrorMake(WSErrorCodePeerGroupStop, @"Download stopped")];
            }
            else {
                [self.notifier notifyDownloadFailedWithError:WSErrorMake(WSErrorCodePeerGroupSync, @"No more peers for download")];
            }
        }
        else {
            [self.notifier notifyDownloadFailedWithError:error];

            self.downloadPeer = [self bestPeer];
            if (self.downloadPeer) {
                DDLogDebug(@"Switched to next best download peer %@", self.downloadPeer);

                // restart sync on new download peer
                if (self.keepDownloading && ![self unsafeIsSynced]) {
                    [self loadFilterAndStartDownload];
                }
            }
        }
    }

    [self handleConnectionFailureFromPeer:peer error:error];
}

- (void)peerDidKeepAlive:(WSPeer *)peer
{
    if (peer == self.downloadPeer) {
        self.lastKeepAliveTime = [NSDate timeIntervalSinceReferenceDate];
    }
}

- (void)peer:(WSPeer *)peer didReceiveHeader:(WSBlockHeader *)header
{
    DDLogVerbose(@"Received header from %@: %@", peer, header);
    
    NSError *error;
    WSStorableBlock *block = nil;
    __weak WSPeerGroup *weakSelf = self;

    if (![self validateHeaderAgainstCheckpoints:header error:&error]) {
        [self.pool closeConnectionForProcessor:peer error:error];
        return;
    }

    NSArray *connectedOrphans;
    block = [self.blockChain addBlockWithHeader:header reorganizeBlock:^(WSStorableBlock *base, NSArray *oldBlocks, NSArray *newBlocks) {

        [weakSelf handleReorganizeAtBase:base oldBlocks:oldBlocks newBlocks:newBlocks fromPeer:peer];

    } connectedOrphans:&connectedOrphans error:&error];
    
    if (!block) {
        if (!error) {
            DDLogDebug(@"Header not added: %@", header);
        }
        else {
            DDLogDebug(@"Error adding header (%@): %@", error, header);

            if ((error.domain == WSErrorDomain) && (error.code == WSErrorCodeInvalidBlock)) {
                [self handleMisbehavingPeer:peer error:error];
            }
        }
        DDLogDebug(@"Current head: %@", self.blockChain.head);
        
        return;
    }

    for (WSStorableBlock *addedBlock in [connectedOrphans arrayByAddingObject:block]) {
        [self handleAddedBlock:addedBlock fromPeer:peer];
    }
}

- (void)peer:(WSPeer *)peer didReceiveBlock:(WSBlock *)block
{
    DDLogVerbose(@"Received full block from %@: %@", peer, block);

#warning FIXME: handle full blocks, blockchain not extending in full blocks mode
}

- (void)peer:(WSPeer *)peer didReceiveFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions
{
    DDLogVerbose(@"Received filtered block from %@: %@", peer, filteredBlock);

    NSError *error;
    WSStorableBlock *block = nil;
    WSStorableBlock *previousHead = nil;
    __weak WSPeerGroup *weakSelf = self;

    if (![self validateHeaderAgainstCheckpoints:filteredBlock.header error:&error]) {
        [self.pool closeConnectionForProcessor:peer error:error];
        return;
    }

    NSArray *connectedOrphans;
    previousHead = self.blockChain.head;
    block = [self.blockChain addBlockWithHeader:filteredBlock.header transactions:transactions reorganizeBlock:^(WSStorableBlock *base, NSArray *oldBlocks, NSArray *newBlocks) {

        [weakSelf handleReorganizeAtBase:base oldBlocks:oldBlocks newBlocks:newBlocks fromPeer:peer];

    } connectedOrphans:&connectedOrphans error:&error];
    
    if (!block) {
        if (!error) {
            DDLogDebug(@"Filtered block not added: %@", filteredBlock);
        }
        else {
            DDLogDebug(@"Error adding filtered block (%@): %@", error, filteredBlock);

            if ((error.domain == WSErrorDomain) && (error.code == WSErrorCodeInvalidBlock)) {
                [self handleMisbehavingPeer:peer error:error];
            }
        }
        DDLogDebug(@"Current head: %@", self.blockChain.head);
        
        return;
    }

    //
    // adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRPeerManager.m
    //
    // low-pass filter in [BRPeerManager peer:relayedBlock:]
    //
    if ((peer == self.downloadPeer) && (transactions.count > 0)) {
        const double oldRate = self.observedFalsePositiveRate;
        self.observedFalsePositiveRate = (self.observedFalsePositiveRate *
                                          (1.0 - self.bloomFilterLowPassRatio * filteredBlock.partialMerkleTree.txCount / self.bloomFilterTxsPerBlock) +
                                          self.bloomFilterLowPassRatio * transactions.count / self.bloomFilterTxsPerBlock);
        
        DDLogVerbose(@"Observed false positive rate at #%u: %f * (1.0 - %.2f * %u / %u) + %.2f * %u / %u = %f",
                     self.blockChain.currentHeight, oldRate,
                     self.bloomFilterLowPassRatio, filteredBlock.partialMerkleTree.txCount, self.bloomFilterTxsPerBlock,
                     self.bloomFilterLowPassRatio, transactions.count, self.bloomFilterTxsPerBlock,
                     self.observedFalsePositiveRate);
        
        if (self.observedFalsePositiveRate > self.bloomFilterObservedRateMax) {
            [self.pool closeConnectionForProcessor:self.downloadPeer
                                             error:WSErrorMake(WSErrorCodePeerGroupSync, @"Too many false positives (%f > %f) in the %u-%u range (%u blocks), disconnecting",
                                                               self.observedFalsePositiveRate, self.bloomFilterObservedRateMax,
                                                               self.observedFilterHeight, self.blockChain.currentHeight,
                                                               self.blockChain.currentHeight - self.observedFilterHeight)];
        }
    }
    
    for (WSStorableBlock *addedBlock in [connectedOrphans arrayByAddingObject:block]) {
        if (![addedBlock.blockId isEqual:previousHead.blockId]) {
            [self handleAddedBlock:addedBlock fromPeer:peer];
        }
        else {
            [self handleReplacedBlock:addedBlock fromPeer:peer];
        }
    }
}

- (void)peer:(WSPeer *)peer didReceiveTransaction:(WSSignedTransaction *)transaction
{
    DDLogVerbose(@"Received transaction from %@: %@", peer, transaction);
    
    [self handleReceivedTransaction:transaction fromPeer:peer];
}

- (void)peer:(WSPeer *)peer didReceiveAddresses:(NSArray *)addresses isLastRelay:(BOOL)isLastRelay
{
    DDLogDebug(@"Received %u addresses from %@", addresses.count, peer);
    
    if (self.peerHosts) {
        return;
    }

    [self.inactiveAddresses addObjectsFromArray:addresses];

//    if (isLastRelay && (self.connectedPeers.count < self.maxConnections)) {
    if (self.connectedPeers.count < self.maxConnections) {
        [self triggerConnectionsFromInactive];
    }
}

- (void)peer:(WSPeer *)peer didReceivePongMesage:(WSMessagePong *)pong
{
    DDLogDebug(@"Received 'pong' with nonce: %llu", pong.nonce);

#warning TODO: track ping time
}

- (void)peer:(WSPeer *)peer didReceiveDataRequestWithInventories:(NSArray *)inventories
{
    DDLogDebug(@"Received data request from %@ with inventories: %@", peer, inventories);
    
    NSMutableArray *notfoundInventories = [[NSMutableArray alloc] initWithCapacity:inventories.count];
    NSMutableDictionary *relayingPeersByTxId = [[NSMutableDictionary alloc] initWithCapacity:inventories.count];
    
    for (WSInventory *inv in inventories) {
        
        // we don't relay blocks
        if (inv.inventoryType != WSInventoryTypeTx) {
            [notfoundInventories addObject:inv];
            continue;
        }
        
        WSHash256 *txId = inv.inventoryHash;
        WSSignedTransaction *transaction = self.publishedTransactions[txId];
        
        // requested transaction we don't own
        if (!transaction) {
            [notfoundInventories addObject:inv];
            continue;
        }
        
        [peer sendTxMessageWithTransaction:transaction];
        
        NSMutableArray *relayingPeers = relayingPeersByTxId[transaction.txId];
        if (!relayingPeers) {
            relayingPeers = [[NSMutableArray alloc] init];
            relayingPeersByTxId[transaction.txId] = relayingPeers;
        }
        [relayingPeers addObject:peer.remoteHost];
    }

    if (notfoundInventories.count > 0) {
        [peer sendNotfoundMessageWithInventories:notfoundInventories];
    }
    
    if (relayingPeersByTxId.count > 0) {
        DDLogDebug(@"Published transactions to peers: %@", relayingPeersByTxId);
    }
    else {
        DDLogDebug(@"No published transactions");
    }
}

- (void)peer:(WSPeer *)peer didReceiveRejectMessage:(WSMessageReject *)message
{
    DDLogDebug(@"Received reject from %@: %@", peer, message);
    
#warning TODO: handle reject message
}

- (void)peerDidRequestFilterReload:(WSPeer *)peer
{
    DDLogDebug(@"Received Bloom filter reload request from %@", peer);

    if (self.bloomFilterParameters.flags == WSBIP37FlagsUpdateNone) {
        DDLogDebug(@"Bloom filter is static and doesn't need a reload (flags: UPDATE_NONE)");
        return;
    }

    [self reloadBloomFilter];
    [peer sendFilterloadMessageWithFilter:self.bloomFilter];
}

- (void)peer:(WSPeer *)peer didSendNumberOfBytes:(NSUInteger)numberOfBytes
{
    self.sentBytes += numberOfBytes;
}

- (void)peer:(WSPeer *)peer didReceiveNumberOfBytes:(NSUInteger)numberOfBytes
{
    self.receivedBytes += numberOfBytes;
}

#pragma mark Application state (main queue)

- (void)reachability:(WSReachability *)reachability didChangeStatus:(WSReachabilityStatus)reachabilityStatus
{
    DDLogVerbose(@"Reachability flags: %@ (reachable: %d)", [reachability reachabilityFlagsString], [reachability isReachable]);
    
    dispatch_async(self.queue, ^{
        if (self.keepConnected && [reachability isReachable]) {
            DDLogDebug(@"Network is reachable, connecting...");
            [self connect];
        }
        else {
            DDLogDebug(@"Network is unreachable, disconnecting...");
            [self disconnect];
        }
    });
}

#pragma mark Connection helpers (unsafe)

- (void)connect
{
    if (self.connectionFailures == self.maxConnectionFailures) {
        DDLogInfo(@"Too many disconnections, not connecting");
        return;
    }
    if (![self.reachability isReachable]) {
        DDLogInfo(@"Network offline, not connecting");
        return;
    }
    
    self.blockChain.blockStoreSize = self.blockStoreSize;
    
    if (self.peerHosts.count > 0) {
        NSArray *newAddresses = [self disconnectedAddressesWithHosts:self.peerHosts];
        [self.inactiveAddresses addObjectsFromArray:newAddresses];
        
        DDLogInfo(@"Connecting to inactive peers (available: %u)", self.inactiveAddresses.count);
//        DDLogDebug(@"%@", self.inactiveAddresses);
        [self triggerConnectionsFromInactive];
    }
    else {
        if (self.inactiveAddresses.count > 0) {
            [self triggerConnectionsFromInactive];
            return;
        }
        
        if ((self.connectedPeers.count > 0) || (self.pendingPeers.count > 0)) {
            DDLogDebug(@"Active peers around, skip DNS discovery (connected: %u, pending: %u)", self.connectedPeers.count, self.pendingPeers.count);
            return;
        }
        
        // first bootstrap is from DNS
        [self discoverNewHostsWithResolutionCallback:^(NSString *seed, NSArray *newHosts) {
            DDLogDebug(@"Discovered %u new peers from %@", newHosts.count, seed);
            DDLogDebug(@"%@", newHosts);
            
            NSArray *newAddresses = [self disconnectedAddressesWithHosts:newHosts];
            if (newAddresses.count == 0) {
                DDLogDebug(@"All discovered peers are already connected");
                return;
            }
            
            [self.inactiveAddresses addObjectsFromArray:newAddresses];
            DDLogInfo(@"Connecting to discovered non-connected peers (available: %u)", newAddresses.count);
            DDLogDebug(@"%@", newAddresses);
            [self triggerConnectionsFromSeed:seed addresses:newAddresses];
        } failure:^(NSError *error) {
            DDLogError(@"DNS discovery failed: %@", error);
        }];
    }
}

- (void)disconnect
{
    [self.pool closeAllConnections];
}

- (void)discoverNewHostsWithResolutionCallback:(void (^)(NSString *, NSArray *))resolutionCallback failure:(void (^)(NSError *))failure
{
    NSParameterAssert(resolutionCallback);
    NSParameterAssert(failure);
    
    // if discovery ongoing, fall back to current inactive hosts
    if (self.activeDnsResolutions > 0) {
        DDLogWarn(@"Waiting for %u ongoing resolutions to complete", self.activeDnsResolutions);
        failure(WSErrorMake(WSErrorCodeNetworking, @"Another DNS discovery is still ongoing"));
        return;
    }
    
    for (NSString *dns in [self.parameters dnsSeeds]) {
        DDLogInfo(@"Resolving seed: %@", dns);
        
        ++self.activeDnsResolutions;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            CFHostRef host = CFHostCreateWithName(NULL, (__bridge CFStringRef)dns);
            if (!CFHostStartInfoResolution(host, kCFHostAddresses, NULL)) {
                DDLogError(@"Error during resolution of %@", dns);
                CFRelease(host);
                
                dispatch_sync(self.queue, ^{
                    --self.activeDnsResolutions;
                });
                
                return;
            }
            Boolean resolved;
            CFArrayRef rawAddressesRef = CFHostGetAddressing(host, &resolved);
            NSArray *rawAddresses = nil;
            if (resolved) {
                rawAddresses = CFBridgingRelease(CFArrayCreateCopy(NULL, rawAddressesRef));
            }
            CFRelease(host);
            
            dispatch_sync(self.queue, ^{
                --self.activeDnsResolutions;
            });
            
            if (rawAddresses) {
                DDLogDebug(@"Resolved %u addresses", rawAddresses.count);
                
                NSMutableArray *hosts = [[NSMutableArray alloc] init];
                
                // add a faulty host to test automatic removal
                //                [hosts addObject:@"124.170.89.58"]; // behind
                //                [hosts addObject:@"152.23.202.18"]; // timeout
                
                dispatch_sync(self.queue, ^{
                    for (NSData *rawBytes in rawAddresses) {
                        if (rawBytes.length != sizeof(struct sockaddr_in)) {
                            continue;
                        }
                        struct sockaddr_in *rawAddress = (struct sockaddr_in *)rawBytes.bytes;
                        const uint32_t address = rawAddress->sin_addr.s_addr;
                        NSString *host = WSNetworkHostFromIPv4(address);
                        
                        if (host && ![self isInactiveHost:host]) {
                            [hosts addObject:host];
                        }
                    }
                });
                
                DDLogDebug(@"Retained %u resolved addresses (pruned ipv6 and known from inactive)", hosts.count);
                
                if (hosts.count > 0) {
                    dispatch_async(self.queue, ^{
                        resolutionCallback(dns, hosts);
                    });
                }
            }
        });
    }
}

- (void)triggerConnectionsFromSeed:(NSString *)seed addresses:(NSArray *)addresses
{
    NSParameterAssert(seed);
    NSParameterAssert(addresses.count > 0);
    
    NSMutableArray *triggered = [[NSMutableArray alloc] init];
    
    for (WSNetworkAddress *address in addresses) {
        if ([self isPendingHost:address.host] || [self.misbehavingHosts containsObject:address.host]) {
            continue;
        }
        if (self.connectedPeers.count + self.pendingPeers.count >= self.maxConnections) {
            break;
        }
        
        [self openConnectionToPeerHost:address.host];
        [triggered addObject:address];
    }
    [self.inactiveAddresses removeObjectsInArray:triggered];
    
    DDLogDebug(@"Triggered %u new connections from %@", triggered.count, seed);
}

- (void)triggerConnectionsFromInactive
{
    NSMutableArray *triggered = [[NSMutableArray alloc] init];
    
    // recent first
    [self.inactiveAddresses sortUsingComparator:^NSComparisonResult(WSNetworkAddress *a1, WSNetworkAddress *a2) {
        if (a1.timestamp > a2.timestamp) {
            return NSOrderedAscending;
        }
        else if (a1.timestamp < a2.timestamp) {
            return NSOrderedDescending;
        }
        else {
            return NSOrderedSame;
        }
    }];
    
    // cap total
    if (self.inactiveAddresses.count > WSPeerGroupMaxInactivePeers) {
        [self.inactiveAddresses removeObjectsInRange:NSMakeRange(WSPeerGroupMaxInactivePeers, self.inactiveAddresses.count - WSPeerGroupMaxInactivePeers)];
    }
    
    DDLogDebug(@"Sorted %u inactive addresses", self.inactiveAddresses.count);
//    DDLogDebug(@">>> %@", self.inactiveAddresses);
//
//    // sequential
//    for (WSNetworkAddress *address in self.inactiveAddresses) {
//        if ([self isPendingHost:address.host] || [self.misbehavingHosts containsObject:address.host]) {
//            continue;
//        }
//        if (self.connectedPeers.count + self.pendingPeers.count >= self.maxConnections) {
//            break;
//        }
//
//        [self openConnectionToPeerHost:address.host];
//        [triggered addObject:address];
//    }
//    [self.inactiveAddresses removeObjectsInArray:triggered];
    
    // randomic
    while (self.inactiveAddresses.count > 0) {
        
        //
        // taken from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRPeerManager.m
        //
        // prefer recent from inactive (higher probability of retrieving lower offsets)
        //
        WSNetworkAddress *address = self.inactiveAddresses[(NSUInteger)(pow(lrand48() % self.inactiveAddresses.count, 2) / self.inactiveAddresses.count)];
        
        if ([self isPendingHost:address.host] || [self.misbehavingHosts containsObject:address.host]) {
            continue;
        }
        if (self.connectedPeers.count + self.pendingPeers.count >= self.maxConnections) {
            break;
        }
        
        [self openConnectionToPeerHost:address.host];
        [triggered addObject:address];
        
        [self.inactiveAddresses removeObject:address];
    }
    
    DDLogDebug(@"Triggered %u new connections from inactive", triggered.count);
}

- (void)openConnectionToPeerHost:(NSString *)host
{
    NSParameterAssert(host);
    
    WSPeerParameters *peerParameters = [[WSPeerParameters alloc] initWithParameters:self.parameters
                                                               shouldDownloadBlocks:[self shouldDownloadBlocks]
                                                                needsBloomFiltering:[self needsBloomFiltering]];
    
    WSPeer *peer = [[WSPeer alloc] initWithHost:host peerParameters:peerParameters];
    peer.delegate = self;
    peer.delegateQueue = self.queue;
    [self.pendingPeers addObject:peer];
    
    DDLogInfo(@"Connecting to peer %@", peer);
    [self.pool openConnectionToPeer:peer];
}

- (void)handleConnectionFailureFromPeer:(WSPeer *)peer error:(NSError *)error
{
    // give up if no error (disconnected intentionally)
    if (!error) {
        DDLogDebug(@"Not recovering intentional disconnection from %@", peer);
    }
    else {
        ++self.connectionFailures;
        if (self.connectionFailures > self.maxConnectionFailures) {
            return;
        }
        
        // reconnect if persistent
        if (self.keepConnected) {
            DDLogDebug(@"Current connection failures %u/%u", self.connectionFailures, self.maxConnectionFailures);
            
            if (self.connectionFailures == self.maxConnectionFailures) {
                DDLogError(@"Too many failures, delaying reconnection for %.3fs", self.reconnectionDelayOnFailure);
                [self reconnectAfterDelay:self.reconnectionDelayOnFailure];
                return;
            }
            
            if ([[self class] isHardNetworkError:error]) {
                DDLogDebug(@"Hard error from peer %@", peer.remoteHost);
                [self removeInactiveHost:peer.remoteHost];
            }
            
            if (self.connectedPeers.count < self.maxConnections) {
                DDLogInfo(@"Searching for new peers");
                [self connect];
            }
        }
    }
}

- (void)reconnectAfterDelay:(NSTimeInterval)delay
{
    const dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC);
    dispatch_after(when, self.queue, ^{
        self.connectionFailures = 0;
        [self connect];
    });
}

- (NSArray *)disconnectedAddressesWithHosts:(NSArray *)hosts
{
    NSMutableArray *disconnected = [[NSMutableArray alloc] initWithCapacity:hosts.count];
    for (NSString *host in hosts) {
        if ([self isPendingHost:host] || [self isConnectedHost:host]) {
            continue;
        }
        WSNetworkAddress *address = WSNetworkAddressMake(WSNetworkIPv4FromHost(host), [self.parameters peerPort], 0, WSCurrentTimestamp() - WSDatesOneWeek);
        [disconnected addObject:address];
    }
    return disconnected;
}

- (void)removeInactiveHost:(NSString *)host
{
    WSNetworkAddress *addressToRemove;
    for (WSNetworkAddress *address in self.inactiveAddresses) {
        if ([address.host isEqualToString:host]) {
            addressToRemove = address;
        }
    }
    if (addressToRemove) {
        [self.inactiveAddresses removeObject:addressToRemove];
        
        DDLogDebug(@"Removed host %@ from inactive (available: %u)", host, self.inactiveAddresses.count);
    }
}

- (BOOL)isInactiveHost:(NSString *)host
{
    for (WSNetworkAddress *address in self.inactiveAddresses) {
        if ([address.host isEqualToString:host]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isPendingHost:(NSString *)host
{
    for (WSPeer *peer in self.pendingPeers) {
        if ([peer.remoteHost isEqualToString:host]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isConnectedHost:(NSString *)host
{
    for (WSPeer *peer in self.connectedPeers) {
        if ([peer.remoteHost isEqualToString:host]) {
            return YES;
        }
    }
    return NO;
}

- (WSPeer *)bestPeer
{
    WSPeer *bestPeer = nil;
    for (WSPeer *peer in self.connectedPeers) {
        
        // double check connection status
        if (peer.peerStatus != WSPeerStatusConnected) {
            continue;
        }
        
        // max chain height or min ping
        if (!bestPeer ||
            (peer.lastBlockHeight > bestPeer.lastBlockHeight) ||
            ((peer.lastBlockHeight == bestPeer.lastBlockHeight) && (peer.connectionTime < bestPeer.connectionTime))) {
            
            bestPeer = peer;
        }
    }
    return bestPeer;
}

+ (BOOL)isHardNetworkError:(NSError *)error
{
    static NSMutableDictionary *hardCodes;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        hardCodes = [[NSMutableDictionary alloc] init];
        
        hardCodes[NSPOSIXErrorDomain] = [NSSet setWithArray:@[@(ECONNREFUSED),
                                                              @(ECONNRESET)]];
        
//        hardCodes[GCDAsyncSocketErrorDomain] = [NSSet setWithArray:@[@(GCDAsyncSocketConnectTimeoutError),
//                                                                     @(GCDAsyncSocketClosedError)]];
        
    });
    
    return ((error.domain != WSErrorDomain) && [hardCodes[error.domain] containsObject:@(error.code)]);
}

#pragma mark Sync helpers (unsafe)

- (void)loadFilterAndStartDownload
{
    NSAssert(self.downloadPeer, @"No download peer set");
    
    if ([self needsBloomFiltering]) {
        [self resetBloomFilter];
        
        DDLogDebug(@"Loading Bloom filter for download peer %@", self.downloadPeer);
        [self.downloadPeer sendFilterloadMessageWithFilter:self.bloomFilter];
    }
    else if ([self shouldDownloadBlocks]) {
        DDLogDebug(@"No wallet provided, downloading full blocks");
    }
    else {
        DDLogDebug(@"No wallet provided, downloading block headers");
    }
    
    DDLogInfo(@"Preparing for blockchain sync");
    
    [self.downloadPeer downloadBlockChain:self.blockChain fastCatchUpTimestamp:self.fastCatchUpTimestamp prestartBlock:^(NSUInteger fromHeight, NSUInteger toHeight) {
        [self.notifier notifyDownloadStartedFromHeight:fromHeight toHeight:toHeight];
        
        self.lastKeepAliveTime = [NSDate timeIntervalSinceReferenceDate];
        const NSTimeInterval delay = self.requestTimeout;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(detectDownloadTimeout) object:nil];
            [self performSelector:@selector(detectDownloadTimeout) withObject:nil afterDelay:delay];
        });
    } syncedBlock:^(NSUInteger height) {
        [self.notifier notifyDownloadStartedFromHeight:height toHeight:height];
        
        DDLogInfo(@"Blockchain is synced");
        
        [self trySaveBlockChainToCoreData];
        
        [self.notifier notifyDownloadFinished];
    }];
}

- (void)resetBloomFilter
{
    if (![self needsBloomFiltering]) {
        return;
    }
    
    const NSUInteger blocksLeft = [self unsafeNumberOfBlocksLeft];
    const NSUInteger retargetInterval = [self.parameters retargetInterval];
    
    // increase fp rate as we approach current height
    NSUInteger filterRateGap = 0;
    if (blocksLeft > 0) {
        filterRateGap = MIN(blocksLeft, retargetInterval);
    }
    
    //
    // 0.0 if (left blocks >= retarget)
    // 0.x if (left blocks < retarget)
    // 1.0 if (left blocks == 0, i.e. blockchain synced)
    //
    double fpRateIncrease = 0.0;
    if ([self unsafeIsSynced]) {
        fpRateIncrease = 1.0 - (double)filterRateGap / retargetInterval;
    }
    
    self.bloomFilterParameters.falsePositiveRate = self.bloomFilterRateMin + fpRateIncrease * self.bloomFilterRateDelta;
    self.observedFilterHeight = self.blockChain.currentHeight;
    self.observedFalsePositiveRate = self.bloomFilterParameters.falsePositiveRate;
    
    const NSTimeInterval rebuildStartTime = [NSDate timeIntervalSinceReferenceDate];
    self.bloomFilter = [self.wallet bloomFilterWithParameters:self.bloomFilterParameters];
    const NSTimeInterval rebuildTime = [NSDate timeIntervalSinceReferenceDate] - rebuildStartTime;
    
    DDLogDebug(@"Bloom filter reset in %.3fs (false positive rate: %f)",
               rebuildTime, self.bloomFilterParameters.falsePositiveRate);
}

- (void)reloadBloomFilter
{
    if (![self needsBloomFiltering]) {
        return;
    }
    
    self.observedFilterHeight = self.blockChain.currentHeight;
    self.observedFalsePositiveRate = [self.bloomFilter estimatedFalsePositiveRate];
}

- (BOOL)maybeResetAndSendBloomFilter
{
    if (![self needsBloomFiltering]) {
        return NO;
    }
    
    DDLogDebug(@"Bloom filter may be outdated (height: %u, receive: %u, change: %u)",
               self.blockChain.currentHeight, self.wallet.allReceiveAddresses.count, self.wallet.allChangeAddresses.count);
    
    if ([self.wallet isCoveredByBloomFilter:self.bloomFilter]) {
        DDLogDebug(@"Wallet is still covered by current Bloom filter, not resetting");
        return NO;
    }
    
    DDLogDebug(@"Wallet is not covered by current Bloom filter anymore, resetting now");
    
    if ([self.wallet isKindOfClass:[WSHDWallet class]]) {
        WSHDWallet *hdWallet = (WSHDWallet *)self.wallet;
        
        DDLogDebug(@"HD wallet: generating %u look-ahead addresses", hdWallet.gapLimit);
        [hdWallet generateAddressesWithLookAhead:hdWallet.gapLimit];
        DDLogDebug(@"HD wallet: receive: %u, change: %u)", hdWallet.allReceiveAddresses.count, hdWallet.allChangeAddresses.count);
    }
    
    [self resetBloomFilter];
    
    if ([self needsBloomFiltering]) {
        if (![self unsafeIsSynced]) {
            DDLogDebug(@"Still syncing, loading rebuilt Bloom filter only for download peer %@", self.downloadPeer);
            [self.downloadPeer sendFilterloadMessageWithFilter:self.bloomFilter];
        }
        else {
            for (WSPeer *peer in self.connectedPeers) {
                DDLogDebug(@"Synced, loading rebuilt Bloom filter for peer %@", peer);
                [peer sendFilterloadMessageWithFilter:self.bloomFilter];
            }
        }
    }
    
    return YES;
}

- (BOOL)shouldDownloadBlocks
{
    return ((self.wallet != nil) || !self.headersOnly);
}

- (BOOL)needsBloomFiltering
{
    return (self.wallet != nil);
}

// main queue
- (void)detectDownloadTimeout
{
    dispatch_sync(self.queue, ^{
        const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        const NSTimeInterval elapsed = now - self.lastKeepAliveTime;
        
        if (elapsed < self.requestTimeout) {
            const NSTimeInterval delay = self.requestTimeout - elapsed;
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(detectDownloadTimeout) object:nil];
                [self performSelector:@selector(detectDownloadTimeout) withObject:nil afterDelay:delay];
            });
            return;
        }
        
        if (self.downloadPeer) {
            [self.pool closeConnectionForProcessor:self.downloadPeer
                                             error:WSErrorMake(WSErrorCodePeerGroupTimeout, @"Download timed out, disconnecting")];
        }
    });
}

- (void)trySaveBlockChainToCoreData
{
    if (self.coreDataManager) {
        [self.blockChain saveToCoreDataManager:self.coreDataManager];
    }
}

#pragma mark Handlers (unsafe)

- (BOOL)validateHeaderAgainstCheckpoints:(WSBlockHeader *)header error:(NSError *__autoreleasing *)error
{
    WSStorableBlock *expected = [self.parameters checkpointAtHeight:(uint32_t)(self.blockChain.currentHeight + 1)];
    if (!expected) {
        return YES;
    }
    if ([header.blockId isEqual:expected.header.blockId]) {
        return YES;
    }
    
    DDLogError(@"Checkpoint validation failed at %u", expected.height);
    DDLogError(@"Expected checkpoint: %@", expected);
    DDLogError(@"Found block header: %@", header);
    
    if (error) {
        *error = WSErrorMake(WSErrorCodePeerGroupRescan, @"Checkpoint validation failed at %u (%@ != %@)",
                             expected.height, header.blockId, expected.blockId);
    }
    return NO;
}

- (void)handleAddedBlock:(WSStorableBlock *)block fromPeer:(WSPeer *)peer
{
    [self.notifier notifyBlockAdded:block];
    
    const NSUInteger lastBlockHeight = self.downloadPeer.lastBlockHeight;
    const BOOL isDownloadFinished = (block.height == lastBlockHeight);
    
    if (isDownloadFinished) {
        for (WSPeer *peer in self.connectedPeers) {
            if ([self needsBloomFiltering] && (peer != self.downloadPeer)) {
                DDLogDebug(@"Loading Bloom filter for peer %@", peer);
                [peer sendFilterloadMessageWithFilter:self.bloomFilter];
            }
            DDLogDebug(@"Requesting mempool from peer %@", peer);
            [peer sendMempoolMessage];
        }

        [self trySaveBlockChainToCoreData];

        dispatch_async(dispatch_get_main_queue(), ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(detectDownloadTimeout) object:nil];
        });
        [self.notifier notifyDownloadFinished];
    }
    
    //
    
    if (self.wallet) {
        [self recoverMissedBlockTransactions:block fromPeer:peer];
    }
}

- (void)handleReplacedBlock:(WSStorableBlock *)block fromPeer:(WSPeer *)peer
{
    if (self.wallet) {
        [self recoverMissedBlockTransactions:block fromPeer:peer];
    }
}

- (void)handleReceivedTransaction:(WSSignedTransaction *)transaction fromPeer:(WSPeer *)peer
{
    const BOOL isPublished = [self findAndRemovePublishedTransaction:transaction fromPeer:peer];
    [self.notifier notifyTransaction:transaction fromPeer:peer isPublished:isPublished];
    
    //
    
    BOOL didGenerateNewAddresses = NO;
    if (self.wallet && ![self.wallet registerTransaction:transaction didGenerateNewAddresses:&didGenerateNewAddresses]) {
        return;
    }
    
    if (didGenerateNewAddresses) {
        DDLogDebug(@"Last transaction triggered new addresses generation");
        
        if ([self maybeResetAndSendBloomFilter]) {
            [peer requestOutdatedBlocks];
        }
    }
}

- (void)handleReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks fromPeer:(WSPeer *)peer
{
    DDLogDebug(@"Reorganized blockchain at block: %@", base);
    DDLogDebug(@"Reorganize, old blocks: %@", oldBlocks);
    DDLogDebug(@"Reorganize, new blocks: %@", newBlocks);
    
    for (WSStorableBlock *block in newBlocks) {
        for (WSSignedTransaction *transaction in block.transactions) {
            const BOOL isPublished = [self findAndRemovePublishedTransaction:transaction fromPeer:peer];
            [self.notifier notifyTransaction:transaction fromPeer:peer isPublished:isPublished];
        }
    }
    
    //
    // wallet should already contain transactions from new blocks, reorganize will only
    // change their parent block (thus updating wallet metadata)
    //
    // that's because after a 'merkleblock' message the following 'tx' messages are received
    // and registered anyway, even if the 'merkleblock' is later considered orphan or on fork
    // by local blockchain
    //
    // for the above reason, a reorg should never generate new addresses
    //
    
    if (!self.wallet) {
        return;
    }
    
    BOOL didGenerateNewAddresses = NO;
    [self.wallet reorganizeWithOldBlocks:oldBlocks newBlocks:newBlocks didGenerateNewAddresses:&didGenerateNewAddresses];
    
    if (didGenerateNewAddresses) {
        DDLogWarn(@"Reorganize triggered (unexpected) new addresses generation");
        
        if ([self maybeResetAndSendBloomFilter]) {
            [peer requestOutdatedBlocks];
        }
    }
}

- (void)handleMisbehavingPeer:(WSPeer *)peer error:(NSError *)error
{
    [self.misbehavingHosts addObject:peer.remoteHost];
    [self.pool closeConnectionForProcessor:peer error:error];
}

- (BOOL)findAndRemovePublishedTransaction:(WSSignedTransaction *)transaction fromPeer:(WSPeer *)peer
{
    BOOL isPublished = NO;
    if (self.publishedTransactions[transaction.txId]) {
        [self.publishedTransactions removeObjectForKey:transaction.txId];
        isPublished = YES;
        
        DDLogInfo(@"Peer %@ relayed published transaction: %@", peer, transaction);
    }
    return isPublished;
}

- (void)recoverMissedBlockTransactions:(WSStorableBlock *)block fromPeer:(WSPeer *)peer
{
    //
    // enforce registration in case we lost these transactions
    //
    // see note in [WSHDWallet isRelevantTransaction:savingReceivingAddresses:]
    //
    BOOL didGenerateNewAddresses = NO;
    for (WSSignedTransaction *transaction in block.transactions) {
        BOOL txDidGenerateNewAddresses = NO;
        [self.wallet registerTransaction:transaction didGenerateNewAddresses:&txDidGenerateNewAddresses];
        
        didGenerateNewAddresses |= txDidGenerateNewAddresses;
    }
    
    [self.wallet registerBlock:block];
    
    if (didGenerateNewAddresses) {
        DDLogWarn(@"Block registration triggered new addresses generation");
        
        if ([self maybeResetAndSendBloomFilter]) {
            [peer requestOutdatedBlocks];
        }
    }
}

#pragma mark External interface (unsafe)

- (BOOL)unsafeIsConnected
{
    return (self.connectedPeers.count > 0);
}

- (BOOL)unsafeHasReachedMaxConnections
{
    return (self.connectedPeers.count == self.maxConnections);
}

- (BOOL)unsafeIsSynced
{
    return (self.downloadPeer && (self.blockChain.currentHeight >= self.downloadPeer.lastBlockHeight));
}

- (NSUInteger)unsafeNumberOfBlocksLeft
{
    if (self.blockChain.currentHeight >= self.downloadPeer.lastBlockHeight) {
        return 0;
    }
    return self.downloadPeer.lastBlockHeight - self.blockChain.currentHeight;
}

@end
