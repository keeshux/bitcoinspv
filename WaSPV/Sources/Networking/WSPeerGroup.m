//
//  WSPeerGroup.m
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

#import <arpa/inet.h>
#import <errno.h>
#import "DDLog.h"

#import "WSPeerGroup.h"
#import "WSConnectionPool.h"
#import "WSWallet.h"
#import "WSHash256.h"
#import "WSCheckpoint.h"
#import "WSPeer.h"
#import "WSBloomFilter.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSStorableBlock.h"
#import "WSTransaction.h"
#import "WSBlockLocator.h"
#import "WSInventory.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"

@interface WSPeerGroup () {
    BOOL _autosave;
    BOOL _shouldReconnectOnBecomeActive;
    BOOL _shouldDisconnectOnEnterBackground;
    NSArray *_peerHosts;
    NSUInteger _maxConnections;
    NSUInteger _maxConnectionFailures;
    NSTimeInterval _reconnectionDelayOnFailure;
    uint32_t _fastCatchUpTimestamp;
    WSPeer *_downloadPeer;
}

@property (nonatomic, strong) WSPeerGroupNotifier *notifier;
@property (nonatomic, strong) WSConnectionPool *pool;
@property (nonatomic, strong) WSBlockChain *blockChain;
@property (nonatomic, strong) id<WSSynchronizableWallet> wallet;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) WSReachability *reachability;

// connection
@property (nonatomic, assign) BOOL keepConnected;
@property (nonatomic, assign) NSUInteger activeDnsResolutions;
@property (nonatomic, assign) NSUInteger connectionFailures;
@property (nonatomic, strong) NSMutableOrderedSet *inactiveHosts;           // NSString
@property (nonatomic, strong) NSMutableSet *pendingPeers;                   // WSPeer
@property (nonatomic, strong) NSMutableSet *connectedPeers;                 // WSPeer
@property (nonatomic, strong) NSMutableDictionary *publishedTransactions;   // WSSignedTransaction

// sync
@property (nonatomic, assign) BOOL keepDownloading;
@property (nonatomic, strong) WSPeer *downloadPeer;
@property (nonatomic, assign) BOOL didNotifyDownloadFinished;
@property (nonatomic, strong) WSBIP37FilterParameters *bloomFilterParameters;
@property (nonatomic, strong) WSBloomFilter *bloomFilter; // immutable, thread-safe

- (void)connect;
- (void)disconnect;
- (NSArray *)disconnectedHostsInHosts:(NSArray *)hosts;
- (void)discoverNewHostsWithResolutionCallback:(void (^)(NSString *, NSArray *))resolutionCallback;
- (void)triggerConnectionsFromSeed:(NSString *)seed;
- (void)openConnectionToPeerHost:(NSString *)host;
- (WSPeer *)bestPeer;
- (void)reconnectAfterDelay:(NSTimeInterval)delay;
- (void)reinsertInactiveHostWithLowestPriority:(NSString *)host;

- (void)loadFilterAndStartDownload;
- (void)rebuildBloomFilter;
- (void)rebuildAndSendBloomFilter;

- (void)handleAddedBlock:(WSStorableBlock *)block fromPeer:(WSPeer *)peer;
- (void)handleReceivedTransaction:(WSSignedTransaction *)transaction fromPeer:(WSPeer *)peer;
- (void)handleReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks fromPeer:(WSPeer *)peer;
- (void)handleMisbehavingPeer:(WSPeer *)peer error:(NSError *)error;
- (BOOL)findAndRemovePublishedTransaction:(WSSignedTransaction *)transaction fromPeer:(WSPeer *)peer;

- (void)applicationDidBecomeActive:(NSNotification *)notification;
- (void)applicationDidEnterBackground:(NSNotification *)notification;

+ (BOOL)isHardNetworkError:(NSError *)error;

@end

@implementation WSPeerGroup

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store
{
    return [self initWithBlockStore:store pool:[[WSConnectionPool alloc] init]];
}

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    return [self initWithBlockStore:store pool:[[WSConnectionPool alloc] init] fastCatchUpTimestamp:fastCatchUpTimestamp];
}

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet
{
    return [self initWithBlockStore:store pool:[[WSConnectionPool alloc] init] wallet:wallet];
}

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store pool:(WSConnectionPool *)pool
{
    return [self initWithBlockStore:store pool:pool wallet:nil];
}

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store pool:(WSConnectionPool *)pool fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    if ((self = [self initWithBlockStore:store pool:pool wallet:nil])) {
        self.fastCatchUpTimestamp = fastCatchUpTimestamp;
    }
    return self;
}

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store pool:(WSConnectionPool *)pool wallet:(id<WSSynchronizableWallet>)wallet
{
    WSExceptionCheckIllegal(store != nil, @"Nil store");
    WSExceptionCheckIllegal(pool != nil, @"Nil pool");
    
    if ((self = [super init])) {
        self.notifier = [[WSPeerGroupNotifier alloc] initWithPeerGroup:self];
        self.pool = pool;
        self.pool.connectionTimeout = WSPeerConnectTimeout;
        self.blockChain = [[WSBlockChain alloc] initWithStore:store];
        if (wallet) {
            self.wallet = wallet;
            self.fastCatchUpTimestamp = [self.wallet earliestKeyTimestamp];
        }
        else {
            self.fastCatchUpTimestamp = 0; // block #0
        }

        NSString *className = [self.class description];
        self.queue = dispatch_queue_create(className.UTF8String, NULL);
        self.reachability = [WSReachability reachabilityForInternetConnection];
        self.reachability.delegate = self;
        self.reachability.delegateQueue = self.queue;
        
        self.autosave = YES;
        self.shouldReconnectOnBecomeActive = NO;
        self.shouldDisconnectOnEnterBackground = NO;
        self.peerHosts = nil;
        self.maxConnections = WSPeerGroupMaxConnections;
        self.maxConnectionFailures = WSPeerGroupMaxConnectionFailures;
        self.reconnectionDelayOnFailure = WSPeerGroupReconnectionDelay;
        
        self.keepConnected = NO;
        self.connectionFailures = 0;
        self.inactiveHosts = [[NSMutableOrderedSet alloc] init];
        self.pendingPeers = [[NSMutableSet alloc] init];
        self.connectedPeers = [[NSMutableSet alloc] init];
        self.publishedTransactions = [[NSMutableDictionary alloc] init];

        self.keepDownloading = NO;
        self.downloadPeer = nil;
        self.bloomFilterParameters = [[WSBIP37FilterParameters alloc] init];
#if WASPV_WALLET_FILTER == WASPV_WALLET_FILTER_UNSPENT
        self.bloomFilterParameters.flags = WSBIP37FlagsUpdateAll;
#endif
        [self rebuildBloomFilter];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [nc addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];

        [self.reachability startNotifier];
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.reachability stopNotifier];
}

#pragma mark Properties

- (BOOL)autosave
{
    @synchronized (self.queue) {
        return _autosave;
    }
}

- (void)setAutosave:(BOOL)autosave
{
    @synchronized (self.queue) {
        _autosave = autosave;
    }
}

- (BOOL)shouldReconnectOnBecomeActive
{
    @synchronized (self.queue) {
        return _shouldReconnectOnBecomeActive;
    }
}

- (void)setShouldReconnectOnBecomeActive:(BOOL)shouldReconnectOnBecomeActive
{
    @synchronized (self.queue) {
        _shouldReconnectOnBecomeActive = shouldReconnectOnBecomeActive;
    }
}

- (BOOL)shouldDisconnectOnEnterBackground
{
    @synchronized (self.queue) {
        return _shouldDisconnectOnEnterBackground;
    }
}

- (void)setShouldDisconnectOnEnterBackground:(BOOL)shouldDisconnectOnEnterBackground
{
    @synchronized (self.queue) {
        _shouldDisconnectOnEnterBackground = shouldDisconnectOnEnterBackground;
    }
}

- (NSArray *)peerHosts
{
    @synchronized (self.queue) {
        return [_peerHosts copy];
    }
}

- (void)setPeerHosts:(NSArray *)peerHosts
{
    @synchronized (self.queue) {
        _peerHosts = [peerHosts copy];
    }
}

- (NSUInteger)maxConnections
{
    @synchronized (self.queue) {
        return _maxConnections;
    }
}

- (void)setMaxConnections:(NSUInteger)maxConnections
{
    @synchronized (self.queue) {
        _maxConnections = maxConnections;

        if (self.inactiveHosts.count > 0) {
            const NSInteger adjustment = maxConnections - self.connectedPeers.count;
            if (adjustment > 0) {
                [self triggerConnectionsFromSeed:nil];
            }
            else if (adjustment < 0) {
                [self.pool closeConnections:-adjustment];
            }
        }
    };
}

- (NSUInteger)maxConnectionFailures
{
    @synchronized (self.queue) {
        return _maxConnectionFailures;
    }
}

- (void)setMaxConnectionFailures:(NSUInteger)maxConnectionFailures
{
    @synchronized (self.queue) {
        _maxConnectionFailures = maxConnectionFailures;
    }
}

- (NSTimeInterval)reconnectionDelayOnFailure
{
    @synchronized (self.queue) {
        return _reconnectionDelayOnFailure;
    }
}

- (void)setReconnectionDelayOnFailure:(NSTimeInterval)reconnectionDelayOnFailure
{
    @synchronized (self.queue) {
        _reconnectionDelayOnFailure = reconnectionDelayOnFailure;
    }
}

- (uint32_t)fastCatchUpTimestamp
{
    @synchronized (self.queue) {
        return _fastCatchUpTimestamp;
    }
}

- (void)setFastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    @synchronized (self.queue) {
        _fastCatchUpTimestamp = MAX(fastCatchUpTimestamp, [WSCurrentParameters forkBlockTimestamp]);
    }
}

- (WSPeer *)downloadPeer
{
    @synchronized (self.queue) {
        NSAssert1(!_downloadPeer || _downloadPeer.isDownloadPeer, @"%@ is not download peer", _downloadPeer);
        return _downloadPeer;
    }
}

- (void)setDownloadPeer:(WSPeer *)downloadPeer
{
    @synchronized (self.queue) {
        _downloadPeer.isDownloadPeer = NO;
        _downloadPeer = downloadPeer;
        _downloadPeer.isDownloadPeer = YES;
    }
}

#pragma mark Connection

- (BOOL)startConnections
{
    @synchronized (self.queue) {
        if (self.keepConnected) {
            DDLogVerbose(@"Ignoring call because already started");
            return NO;
        }

        self.keepConnected = YES;
        [self connect];
        return YES;
    }
}

- (BOOL)stopConnections
{
    @synchronized (self.queue) {
        if (!self.keepConnected) {
            DDLogVerbose(@"Ignoring call because not started");
            return NO;
        }

        self.keepConnected = NO;
        [self disconnect];
        return YES;
    }
}

- (BOOL)isStarted
{
    @synchronized (self.queue) {
        return self.keepConnected;
    }
}

- (BOOL)isConnected
{
    @synchronized (self.queue) {
        return (self.connectedPeers.count > 0);
    }
}

- (void)connect
{
    dispatch_async(self.queue, ^{
        if (![self.reachability isReachable]) {
            DDLogInfo(@"Network offline, not connecting");
            return;
        }

        if (self.peerHosts.count > 0) {
            @synchronized (self.queue) {
                NSArray *newHosts = [self disconnectedHostsInHosts:self.peerHosts];
                [self.inactiveHosts addObjectsFromArray:newHosts];

                DDLogInfo(@"Connecting to inactive peers (available: %u)", self.inactiveHosts.count);
                [self triggerConnectionsFromSeed:nil];
            }
        }
        else {
            [self discoverNewHostsWithResolutionCallback:^(NSString *seed, NSArray *newHosts) {
                @synchronized (self.queue) {
                    if (newHosts.count > 0) {
                        DDLogDebug(@"Discovered %u new peers from %@", newHosts.count, seed);
//                        DDLogVerbose(@"New peers addresses: %@", newHosts);

                        newHosts = [self disconnectedHostsInHosts:newHosts];
                        [self.inactiveHosts addObjectsFromArray:newHosts];
                    }

                    DDLogInfo(@"Connecting to inactive peers (available: %u)", self.inactiveHosts.count);
                    [self triggerConnectionsFromSeed:seed];
                }
            }];
        }
    });
}

- (void)disconnect
{
    [self.pool closeAllConnections];
}

- (NSArray *)disconnectedHostsInHosts:(NSArray *)hosts
{
    @synchronized (self.queue) {
        NSMutableArray *disconnected = [hosts mutableCopy];
        for (WSPeer *peer in self.connectedPeers) {
            [disconnected removeObject:peer.remoteHost];
        }
        return disconnected;
    }
}

- (void)discoverNewHostsWithResolutionCallback:(void (^)(NSString *, NSArray *))resolutionCallback
{
    NSAssert(resolutionCallback, @"NULL resolutionCallback");

    // if discovery ongoing, fall back to current inactive hosts
    BOOL ongoing = NO;
    @synchronized (self.queue) {
        if (self.activeDnsResolutions > 0) {
            DDLogWarn(@"Waiting for %u ongoing resolutions to complete", self.activeDnsResolutions);
            ongoing = YES;
        }
    }
    if (ongoing) {
        resolutionCallback(nil, nil);
        return;
    }
    
    for (NSString *dns in [WSCurrentParameters dnsSeeds]) {
        DDLogInfo(@"Resolving seed: %@", dns);

        @synchronized (self.queue) {
            ++self.activeDnsResolutions;
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            CFHostRef host = CFHostCreateWithName(NULL, (__bridge CFStringRef)dns);
            if (!CFHostStartInfoResolution(host, kCFHostAddresses, NULL)) {
                DDLogError(@"Error during resolution of %@", dns);
                CFRelease(host);

                @synchronized (self.queue) {
                    --self.activeDnsResolutions;
                }

                return;
            }
            Boolean resolved;
            CFArrayRef rawAddressesRef = CFHostGetAddressing(host, &resolved);
            NSArray *rawAddresses = nil;
            if (resolved) {
                rawAddresses = CFBridgingRelease(CFArrayCreateCopy(NULL, rawAddressesRef));
            }
            CFRelease(host);

            @synchronized (self.queue) {
                --self.activeDnsResolutions;
            }

            if (rawAddresses) {
                DDLogDebug(@"Resolved %u addresses", rawAddresses.count);

                NSMutableArray *hosts = [[NSMutableArray alloc] init];

                // add a faulty host to test automatic removal
//                [hosts addObject:@"124.170.89.58"]; // behind
//                [hosts addObject:@"152.23.202.18"]; // timeout

                @synchronized (self.queue) {
                    for (NSData *rawBytes in rawAddresses) {
                        if (rawBytes.length != sizeof(struct sockaddr_in)) {
                            continue;
                        }
                        struct sockaddr_in *rawAddress = (struct sockaddr_in *)rawBytes.bytes;
                        const uint32_t address = rawAddress->sin_addr.s_addr;
                        NSString *host = WSNetworkHostFromIPv4(address);

                        if (host && ![self.inactiveHosts containsObject:host]) {
                            [hosts addObject:host];
                        }
                    }
                }

                DDLogDebug(@"Retained %u resolved addresses (pruned ipv6 and known from inactive)", hosts.count);

                //
                // IMPORTANT: trigger callback even with empty hosts, function caller
                // expects a response anyway
                //
                // e.g. [self connect] is triggering connections in resolutionCallback
                // and it won't if callback is not invoked
                //
                dispatch_async(self.queue, ^{
                    resolutionCallback(dns, hosts);
                });
            }
        });
    }
}

- (void)triggerConnectionsFromSeed:(NSString *)seed
{
    NSUInteger triggered = 0;

    @synchronized (self.queue) {
        for (NSString *host in self.inactiveHosts) {
            const NSUInteger activeConnections = [self.pool numberOfConnections];
            if (activeConnections >= self.maxConnections) {
                DDLogVerbose(@"Reached max connections (%u >= %u)", activeConnections, self.maxConnections);
                break;
            }

            [self openConnectionToPeerHost:host];
            ++triggered;
        }
    }

    DDLogInfo(@"Triggered %u new connections%@", triggered, WSStringOptional(seed, @" from %@"));
}

- (void)openConnectionToPeerHost:(NSString *)host
{
    NSAssert(host, @"Nil host");
    
    WSPeerParameters *parameters = [[WSPeerParameters alloc] initWithGroupQueue:self.queue blockChain:self.blockChain];
    WSPeer *peer = [[WSPeer alloc] initWithHost:host parameters:parameters];
    peer.relayTransactionsInVersion = (self.wallet == nil);
    peer.delegate = self;
    @synchronized (self.queue) {
        [self.pendingPeers addObject:peer];
    }

    DDLogInfo(@"Connecting to peer %@", peer);
    [self.pool openConnectionToPeer:peer];
}

- (WSPeer *)bestPeer
{
    WSPeer *bestPeer = nil;
    @synchronized (self.queue) {
        for (WSPeer *peer in self.connectedPeers) {

            // double check connection status
            if (peer.peerStatus != WSPeerStatusConnected) {
                continue;
            }
            
            // min ping or max chain height
            if (!bestPeer ||
                ((peer.connectionTime < bestPeer.connectionTime) && (peer.lastBlockHeight >= bestPeer.lastBlockHeight)) ||
                (peer.lastBlockHeight > bestPeer.lastBlockHeight)) {
                
                bestPeer = peer;
            }
        }
    }
    return bestPeer;
}

- (void)reconnectAfterDelay:(NSTimeInterval)delay
{
    const dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC);
    dispatch_after(when, self.queue, ^{
        @synchronized (self.queue) {
            self.connectionFailures = 0;
        }
        [self connect];
    });
}

- (void)reinsertInactiveHostWithLowestPriority:(NSString *)host
{
    @synchronized (self.queue) {
        DDLogDebug(@"Reinsert %@ with lowest priority", host);

        [self.inactiveHosts removeObject:host];
        [self.inactiveHosts addObject:host];

        DDLogVerbose(@"Reinserted at %u/%u", [self.inactiveHosts indexOfObject:host], self.inactiveHosts.count - 1);
        DDLogVerbose(@"Inactive hosts: %@", self.inactiveHosts);
    }
}

#pragma mark Synchronization

- (BOOL)startBlockChainDownload
{
    @synchronized (self.queue) {
        if (self.keepDownloading) {
            DDLogVerbose(@"Ignoring call because already downloading");
            return NO;
        }

        self.keepDownloading = YES;
        self.didNotifyDownloadFinished = NO;

        if (self.downloadPeer) {
            [self loadFilterAndStartDownload];
        }
        else {
            DDLogInfo(@"Delayed download until peer selection");
        }
        return YES;
    }
}

- (void)loadFilterAndStartDownload
{
    @synchronized (self.queue) {
        NSAssert(self.downloadPeer, @"No download peer set");
        
        DDLogDebug(@"Loading Bloom filter for download peer %@", self.downloadPeer);
        [self.downloadPeer sendFilterloadMessageWithFilter:self.bloomFilter];

        const NSUInteger fromHeight = self.blockChain.currentHeight;
        const NSUInteger toHeight = fromHeight + [self.downloadPeer numberOfBlocksLeft];
        [self.notifier notifyDownloadStartedFromHeight:fromHeight toHeight:toHeight];
        
        if (![self.downloadPeer downloadBlockChainWithFastCatchUpTimestamp:self.fastCatchUpTimestamp]) {
            DDLogInfo(@"Blockchain is synced");
            [self.notifier notifyDownloadFinished];
        }
    }
}

- (BOOL)stopBlockChainDownload
{
    @synchronized (self.queue) {
        if (!self.keepDownloading) {
            DDLogVerbose(@"Ignoring call because not downloading");
            return NO;
        }
        self.keepDownloading = NO;
        if (self.downloadPeer) {

            // not reconnecting without error
            [self.pool closeConnectionForProcessor:self.downloadPeer
                                             error:WSErrorMake(WSErrorCodeSync, @"Download stopped")];
        }
        return YES;
    }
}

- (BOOL)isDownloading
{
    @synchronized (self.queue) {
        return self.keepDownloading;
    }
}

- (BOOL)isSynced
{
    @synchronized (self.queue) {
        return (self.downloadPeer && ([self.downloadPeer numberOfBlocksLeft] == 0));
    }
}

- (void)rebuildBloomFilter
{
    @synchronized (self.queue) {
        if (self.wallet) {
            const NSUInteger blocksLeft = [self.downloadPeer numberOfBlocksLeft]; // 0 if disconnected or synced
            const NSUInteger retargetInterval = [WSCurrentParameters retargetInterval];

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
            if ([self isSynced]) {
                fpRateIncrease = 1.0 - (double)filterRateGap / retargetInterval;
            }

            self.bloomFilterParameters.falsePositiveRate = WSPeerGroupBloomFilterFPRateMin + fpRateIncrease * WSPeerGroupBloomFilterFPRateRange;

            const NSTimeInterval rebuildStartTime = [NSDate timeIntervalSinceReferenceDate];
            self.bloomFilter = [self.wallet bloomFilterWithParameters:self.bloomFilterParameters];

            const NSTimeInterval rebuildTime = [NSDate timeIntervalSinceReferenceDate] - rebuildStartTime;
            DDLogDebug(@"Bloom filter updated in %.3fs (falsePositiveRate: %f)",
                       rebuildTime, self.bloomFilterParameters.falsePositiveRate);
        }
#warning TODO: if no wallet, remove full-match Bloom filter and download full blocks
        else {
            if (!self.bloomFilter) {
                self.bloomFilter = [[WSMutableBloomFilter alloc] initWithFullMatch];

                DDLogDebug(@"Full-match Bloom filter set");
            }
        }
    }
}

- (void)rebuildAndSendBloomFilter
{
    @synchronized (self.queue) {
        DDLogDebug(@"Rebuilding Bloom filter");
        [self rebuildBloomFilter];
        
        if (![self isSynced]) {
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
}

#pragma mark Interaction

- (NSUInteger)currentHeight
{
    @synchronized (self.queue) {
        return self.blockChain.currentHeight;
    }
}

- (BOOL)publishTransaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");
    
    @synchronized (self.queue) {
        if (![self isConnected]) {
            return NO;
        }
        if ([self.publishedTransactions objectForKey:transaction.txId]) {
            return NO;
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
    }

    return YES;
}

#pragma mark Events (group queue)

- (void)peerDidConnect:(WSPeer *)peer
{
    @synchronized (self.queue) {
        [self.inactiveHosts removeObject:peer.remoteHost];
        [self.pendingPeers removeObject:peer];
        [self.connectedPeers addObject:peer];
        
        DDLogInfo(@"Connected to %@ at height %u (active: %u)", peer, peer.lastBlockHeight, self.connectedPeers.count);
        DDLogDebug(@"Active peers: %@", self.connectedPeers);

        self.connectionFailures = 0;

        // group gets connected on first connection
        [self.notifier notifyPeerConnected:peer];
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
            error = WSErrorMake(WSErrorCodeSync, @"Peer %@ is behind us (height: %u < %u)", self, peer.lastBlockHeight, self.blockChain.currentHeight);
        }
        if (error) {
            [self.pool closeConnectionForProcessor:peer error:error];
            return;
        }
        
        // peer was accepted
        
        if (self.downloadPeer && (peer.lastBlockHeight <= self.downloadPeer.lastBlockHeight)) {
            DDLogDebug(@"Peer %@ is not ahead of current download peer, marked common (height: %u <= %u)",
                       peer, peer.lastBlockHeight, self.downloadPeer.lastBlockHeight);

            if ([self isSynced]) {
                DDLogDebug(@"Loading Bloom filter for common peer %@", peer);
                [peer sendFilterloadMessageWithFilter:self.bloomFilter];
                DDLogDebug(@"Requesting mempool from common peer %@", peer);
                [peer sendMempoolMessage];
            }
            return;
        }
        
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

            // WARNING: disconnecting during download is a major waste of time and bandwidth
            if ([self isSynced]) {
                [self.pool closeConnectionForProcessor:self.downloadPeer
                                                 error:WSErrorMake(WSErrorCodeSync, @"Found a better download peer than %@", self.downloadPeer)];
            }
        }
    }
}

- (void)peer:(WSPeer *)peer didDisconnectWithError:(NSError *)error
{
    @synchronized (self.queue) {
        [peer cleanUpConnectionData];
        [self.pendingPeers removeObject:peer];
        [self.connectedPeers removeObject:peer];

        DDLogInfo(@"Disconnected from %@ (active: %u)%@", peer, self.connectedPeers.count, WSStringOptional(error, @" (%@)"));
        DDLogDebug(@"Active peers: %@", self.connectedPeers);
        
        // group gets disconnected on last disconnection
        [self.notifier notifyPeerDisconnected:peer];
        if (self.connectedPeers.count == 0) {
            [self.notifier notifyDisconnected];
        }

        if (error && (error.domain == WSErrorDomain)) {
            DDLogDebug(@"Disconnection due to known error (%@)", error);
            [self reinsertInactiveHostWithLowestPriority:peer.remoteHost];
        }

        if (peer == self.downloadPeer) {
            DDLogDebug(@"Peer %@ was download peer", peer);

            self.downloadPeer = [self bestPeer];
            if (self.downloadPeer) {
                DDLogDebug(@"Switched to next best download peer %@", self.downloadPeer);
                
                // restart sync on new download peer
                if (self.keepDownloading && ![self isSynced]) {
                    [self loadFilterAndStartDownload];
                }
            }
            else {
                DDLogDebug(@"No more peers for download");
                
                [self.notifier notifyDownloadFailedWithError:WSErrorMake(WSErrorCodeSync, @"No more peers for download")];
            }
        }
    
        // give up if no error (disconnected intentionally)
        if (!error) {
            DDLogDebug(@"Not recovering intentional disconnection from %@", peer);
        }
        else {
            ++self.connectionFailures;
            DDLogDebug(@"Current connection failures %u/%u", self.connectionFailures, self.maxConnectionFailures);

            // reconnect if persistent
            if (self.keepConnected) {
                if (self.connectionFailures >= self.maxConnectionFailures) {
                    DDLogError(@"Too many failures, delaying reconnection for %.3fs", self.reconnectionDelayOnFailure);
                    [self reconnectAfterDelay:self.reconnectionDelayOnFailure];
                    return;
                }

                if ([[self class] isHardNetworkError:error]) {
                    DDLogDebug(@"Hard error from peer %@", peer.remoteHost);
                    [self reinsertInactiveHostWithLowestPriority:peer.remoteHost];
                }

                DDLogInfo(@"Searching for new peers");
                [self connect];
            }
        }
    }
}

- (void)peer:(WSPeer *)peer didReceiveHeader:(WSBlockHeader *)header
{
    DDLogVerbose(@"Received header from %@: %@", peer, header);
    
    NSError *error;
    WSStorableBlock *block = nil;
    __weak WSPeerGroup *weakSelf = self;

    @synchronized (self.queue) {
        block = [self.blockChain addBlockWithHeader:header reorganizeBlock:^(WSStorableBlock *base, NSArray *oldBlocks, NSArray *newBlocks) {

            [weakSelf handleReorganizeAtBase:base oldBlocks:oldBlocks newBlocks:newBlocks fromPeer:peer];

        } error:&error];
    }
    
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

    [self handleAddedBlock:block fromPeer:peer];
}

- (void)peer:(WSPeer *)peer didReceiveFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions
{
    DDLogVerbose(@"Received filtered block from %@: %@", peer, filteredBlock);

    NSError *error;
    WSStorableBlock *block = nil;
    __weak WSPeerGroup *weakSelf = self;

    @synchronized (self.queue) {
        block = [self.blockChain addBlockWithHeader:filteredBlock.header transactions:transactions reorganizeBlock:^(WSStorableBlock *base, NSArray *oldBlocks, NSArray *newBlocks) {

            [weakSelf handleReorganizeAtBase:base oldBlocks:oldBlocks newBlocks:newBlocks fromPeer:peer];

        } error:&error];
    }
    
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

    [self handleAddedBlock:block fromPeer:peer];
}

- (void)peer:(WSPeer *)peer didReceiveTransaction:(WSSignedTransaction *)transaction
{
    DDLogDebug(@"Received transaction from %@: %@", peer, transaction);
    
    [self handleReceivedTransaction:transaction fromPeer:peer];
}

- (void)peer:(WSPeer *)peer didReceiveAddresses:(NSArray *)addresses
{
    DDLogDebug(@"Received %u addresses from %@", addresses.count, peer);
    
#warning TODO: add to inactive addresses (cap inactive count)
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
    
    @synchronized (self.queue) {
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

- (void)peerDidRequestRebuiltFilter:(WSPeer *)peer
{
    DDLogDebug(@"Received Bloom filter rebuild request from %@", peer);

    @synchronized (self.queue) {
        if (self.bloomFilterParameters.flags == WSBIP37FlagsUpdateNone) {
            DDLogDebug(@"Bloom filter is static and doesn't need a rebuild (flags: UPDATE_NONE)");
            return;
        }
        
        [self rebuildBloomFilter];
        [peer sendFilterloadMessageWithFilter:self.bloomFilter];
    }
}

#pragma mark Handlers

- (void)handleAddedBlock:(WSStorableBlock *)block fromPeer:(WSPeer *)peer
{
    NSUInteger lastBlockHeight = 0;

    @synchronized (self.queue) {
        [self.notifier notifyBlockAdded:block];

        lastBlockHeight = self.downloadPeer.lastBlockHeight;
        const BOOL isDownloadFinished = (block.height == lastBlockHeight);

        if (isDownloadFinished) {
            for (WSPeer *peer in self.connectedPeers) {
                if (peer != self.downloadPeer) {
                    DDLogDebug(@"Loading Bloom filter for peer %@", peer);
                    [peer sendFilterloadMessageWithFilter:self.bloomFilter];
                }
                DDLogDebug(@"Requesting mempool from peer %@", peer);
                [peer sendMempoolMessage];
            }
        }

        if (isDownloadFinished || (block.height % 5000 == 0)) {
            [self.blockChain save];
        }

        if (isDownloadFinished) {
            [self.notifier notifyDownloadFinished];
        }
    }

    //
    
    if (!self.wallet) {
        return;
    }

    //
    // enforce registration in case we lost these transactions during sync
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
    
    // transactions should already exist in wallet, no new addresses should be generated
    if (didGenerateNewAddresses) {
        DDLogWarn(@"Block registering triggered (unexpected) new addresses generation, Bloom filter is outdated (height: %u, receive: %u, change: %u)",
                  self.currentHeight, self.wallet.allReceiveAddresses.count, self.wallet.allChangeAddresses.count);
        
        [self rebuildAndSendBloomFilter];
        [peer requestOutdatedBlocks];
    }
}

- (void)handleReceivedTransaction:(WSSignedTransaction *)transaction fromPeer:(WSPeer *)peer
{
    @synchronized (self.queue) {
        const BOOL isPublished = [self findAndRemovePublishedTransaction:transaction fromPeer:peer];
        [self.notifier notifyTransaction:transaction fromPeer:peer isPublished:isPublished];
    }
    
    //
    
    BOOL didGenerateNewAddresses = NO;
    if (self.wallet && ![self.wallet registerTransaction:transaction didGenerateNewAddresses:&didGenerateNewAddresses]) {
        return;
    }
    
    if (didGenerateNewAddresses) {
        DDLogDebug(@"Last transaction triggered new addresses generation, Bloom filter is outdated (height: %u, receive: %u, change: %u)",
                   self.currentHeight, self.wallet.allReceiveAddresses.count, self.wallet.allChangeAddresses.count);
        
        [self rebuildAndSendBloomFilter];
        [peer requestOutdatedBlocks];
    }
}

- (void)handleReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks fromPeer:(WSPeer *)peer
{
    DDLogDebug(@"Reorganized blockchain at block: %@", base);
    DDLogDebug(@"Reorganize, old blocks: %@", oldBlocks);
    DDLogDebug(@"Reorganize, new blocks: %@", newBlocks);

    @synchronized (self.queue) {
        for (WSStorableBlock *block in newBlocks) {
            for (WSSignedTransaction *transaction in block.transactions) {
                const BOOL isPublished = [self findAndRemovePublishedTransaction:transaction fromPeer:peer];
                [self.notifier notifyTransaction:transaction fromPeer:peer isPublished:isPublished];
            }
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
        DDLogWarn(@"Reorganize triggered (unexpected) new addresses generation, Bloom filter is outdated (height: %u, receive: %u, change: %u)",
                  self.currentHeight, self.wallet.allReceiveAddresses.count, self.wallet.allChangeAddresses.count);

        [self rebuildAndSendBloomFilter];
        [peer requestOutdatedBlocks];
    }
}

- (void)handleMisbehavingPeer:(WSPeer *)peer error:(NSError *)error
{
    [self reinsertInactiveHostWithLowestPriority:peer.remoteHost];
    [self.pool closeConnectionForProcessor:peer error:error];
}

- (BOOL)findAndRemovePublishedTransaction:(WSSignedTransaction *)transaction fromPeer:(WSPeer *)peer
{
    @synchronized (self.queue) {
        BOOL isPublished = NO;
        if ([self.publishedTransactions objectForKey:transaction.txId]) {
            [self.publishedTransactions removeObjectForKey:transaction.txId];
            isPublished = YES;
            
            DDLogInfo(@"Peer %@ relayed published transaction: %@", peer, transaction);
        }
        return isPublished;
    }
}

#pragma mark Application state

- (void)reachability:(WSReachability *)reachability didChangeStatus:(WSReachabilityStatus)reachabilityStatus
{
    DDLogVerbose(@"Reachability flags: %@ (reachable: %d)", [reachability reachabilityFlagsString], [reachability isReachable]);
    
    @synchronized (self.queue) {
        if (self.keepConnected && [reachability isReachable]) {
            [self connect];
        }
        else {
            [self disconnect];
        }
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (self.shouldReconnectOnBecomeActive) {
        @synchronized (self.queue) {
            if (self.keepConnected && [self.reachability isReachable]) {
                [self connect];
            }
        }
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    if (self.shouldDisconnectOnEnterBackground) {
        [self disconnect];
    }
}

#pragma mark Utils (unsafe)

+ (BOOL)isHardNetworkError:(NSError *)error
{
    static NSMutableDictionary *hardCodes;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        hardCodes = [[NSMutableDictionary alloc] init];
        
        hardCodes[NSPOSIXErrorDomain] = [NSSet setWithArray:@[@(ECONNREFUSED),
                                                              @(ECONNRESET)]];
        
        hardCodes[GCDAsyncSocketErrorDomain] = [NSSet setWithArray:@[@(GCDAsyncSocketConnectTimeoutError),
                                                                     @(GCDAsyncSocketClosedError)]];
        
    });
    
    return ((error.domain != WSErrorDomain) && [hardCodes[error.domain] containsObject:@(error.code)]);
}

@end
