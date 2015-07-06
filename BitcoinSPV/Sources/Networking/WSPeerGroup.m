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

@interface WSPeerGroup ()

@property (nonatomic, strong) id<WSParameters> parameters;
@property (nonatomic, strong) WSPeerGroupNotifier *notifier;
@property (nonatomic, strong) WSConnectionPool *pool;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) id<WSBlockStore> store;
@property (nonatomic, strong) WSReachability *reachability;

// connection
@property (nonatomic, assign) BOOL keepConnected;
@property (nonatomic, assign) NSUInteger activeDnsResolutions;
@property (nonatomic, assign) NSUInteger connectionFailures;
@property (nonatomic, strong) NSMutableOrderedSet *inactiveAddresses;       // WSNetworkAddress
@property (nonatomic, strong) NSMutableSet *misbehavingHosts;               // NSString
@property (nonatomic, strong) NSMutableSet *pendingPeers;                   // WSPeer
@property (nonatomic, strong) NSMutableSet *connectedPeers;                 // WSPeer
@property (nonatomic, assign) NSUInteger sentBytes;
@property (nonatomic, assign) NSUInteger receivedBytes;

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

- (BOOL)unsafeIsConnected;
- (BOOL)unsafeHasReachedMaxConnections;

@end

@implementation WSPeerGroup

- (instancetype)initWithBlockStore:(id<WSBlockStore>)store
{
    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:store.parameters];
    NSString *className = [self.class description];
    dispatch_queue_t queue = dispatch_queue_create(className.UTF8String, DISPATCH_QUEUE_SERIAL);

    return [self initWithPool:pool queue:queue blockStore:store];
}

//- (instancetype)initWithBlockStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
//{
//    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:store.parameters];
//    NSString *className = [self.class description];
//    dispatch_queue_t queue = dispatch_queue_create(className.UTF8String, DISPATCH_QUEUE_SERIAL);
//
//    return [self initWithPool:pool queue:queue blockStore:store fastCatchUpTimestamp:fastCatchUpTimestamp];
//}
//
//- (instancetype)initWithBlockStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet
//{
//    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:store.parameters];
//    NSString *className = [self.class description];
//    dispatch_queue_t queue = dispatch_queue_create(className.UTF8String, DISPATCH_QUEUE_SERIAL);
//
//    return [self initWithPool:pool queue:queue blockStore:store wallet:wallet];
//}

- (instancetype)initWithPool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue blockStore:(id<WSBlockStore>)store
{
    return [self initWithPool:pool queue:queue blockStore:store wallet:nil];
}

//- (instancetype)initWithPool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue blockStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
//{
//    if ((self = [self initWithPool:pool queue:queue blockStore:store wallet:nil])) {
//        self.fastCatchUpTimestamp = fastCatchUpTimestamp;
//    }
//    return self;
//}

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
        self.reachability = [WSReachability reachabilityForInternetConnection];
        self.reachability.delegate = self;
        self.reachability.delegateQueue = self.queue;

        // connection
        self.peerHosts = nil;
        self.maxConnections = WSPeerGroupDefaultMaxConnections;
        self.maxConnectionFailures = WSPeerGroupDefaultMaxConnectionFailures;
        self.reconnectionDelayOnFailure = WSPeerGroupDefaultReconnectionDelay;
        
        self.keepConnected = NO;
        self.connectionFailures = 0;
        self.inactiveAddresses = [[NSMutableOrderedSet alloc] init];
        self.misbehavingHosts = [[NSMutableSet alloc] init];
        self.pendingPeers = [[NSMutableSet alloc] init];
        self.connectedPeers = [[NSMutableSet alloc] init];

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

- (void)setPeerHosts:(NSArray *)peerHosts
{
    _peerHosts = peerHosts;
    
    self.maxConnections = _peerHosts.count;
}

#pragma mark Connection (any queue)

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
        self.keepConnected = NO;
        [self disconnect];
    });
    return YES;
}

- (void)stopConnectionsWithCompletionBlock:(void (^)())completionBlock
{
    __block id observer;
    __block void (^onceCompletionBlock)() = completionBlock;
    __block BOOL notConnected = NO;

    dispatch_sync(self.queue, ^{
        self.keepConnected = NO;
        [self disconnect];

        if ([self unsafeIsConnected]) {
            __weak NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

            observer = [nc addObserverForName:WSPeerGroupDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                [nc removeObserver:observer];

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
    if (error) {
        [self.pool closeConnectionForProcessor:peer error:error];
        return;
    }
    
    // peer was accepted
    
    [peer sendGetaddr];
}

- (void)peer:(WSPeer *)peer didFailToConnectWithError:(NSError *)error
{
    [self.pendingPeers removeObject:peer];

    DDLogInfo(@"Failed to connect to %@%@", peer, WSStringOptional(error, @" (%@)"));

    [self handleConnectionFailureFromPeer:peer error:error];
}

- (void)peer:(WSPeer *)peer didDisconnectWithError:(NSError *)error
{
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

    [self handleConnectionFailureFromPeer:peer error:error];
}

- (void)peerDidKeepAlive:(WSPeer *)peer
{
}

- (void)peer:(WSPeer *)peer didReceiveHeader:(WSBlockHeader *)header
{
    DDLogVerbose(@"Received header from %@: %@", peer, header);
}

- (void)peer:(WSPeer *)peer didReceiveBlock:(WSBlock *)block
{
    DDLogVerbose(@"Received full block from %@: %@", peer, block);

#warning FIXME: handle full blocks, blockchain not extending in full blocks mode
}

- (void)peer:(WSPeer *)peer didReceiveFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions
{
    DDLogVerbose(@"Received filtered block from %@: %@", peer, filteredBlock);
}

- (void)peer:(WSPeer *)peer didReceiveTransaction:(WSSignedTransaction *)transaction
{
    DDLogVerbose(@"Received transaction from %@: %@", peer, transaction);
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
}

- (void)peer:(WSPeer *)peer didReceiveRejectMessage:(WSMessageReject *)message
{
    DDLogDebug(@"Received reject from %@: %@", peer, message);
    
#warning TODO: handle reject message
}

- (void)peerDidRequestFilterReload:(WSPeer *)peer
{
    DDLogDebug(@"Received Bloom filter reload request from %@", peer);
}

- (void)peer:(WSPeer *)peer didSendNumberOfBytes:(NSUInteger)numberOfBytes
{
    self.sentBytes += numberOfBytes;
}

- (void)peer:(WSPeer *)peer didReceiveNumberOfBytes:(NSUInteger)numberOfBytes
{
    self.receivedBytes += numberOfBytes;
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
    
    NSArray *dnsSeeds = [self.parameters dnsSeeds];
    
    dispatch_apply(dnsSeeds.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(size_t i) {
        NSString *dns = dnsSeeds[i];
        DDLogInfo(@"Resolving seed: %@", dns);
        
        ++self.activeDnsResolutions;
        
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
    
    WSPeerFlags *flags = [[WSPeerFlags alloc] initWithShouldDownloadBlocks:NO//[self shouldDownloadBlocks]
                                                       needsBloomFiltering:NO];//[self needsBloomFiltering]];
    
    WSPeer *peer = [[WSPeer alloc] initWithHost:host parameters:self.parameters flags:flags];
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

#pragma mark External interface (unsafe)

- (BOOL)unsafeIsConnected
{
    return (self.connectedPeers.count > 0);
}

- (BOOL)unsafeHasReachedMaxConnections
{
    return (self.connectedPeers.count == self.maxConnections);
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

@end
