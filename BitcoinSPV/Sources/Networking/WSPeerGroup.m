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
#import "WSPeerGroup+Download.h"
#import "WSConnectionPool.h"
#import "WSBlockChainDownloader.h"
#import "WSHash256.h"
#import "WSPeer.h"
#import "WSBloomFilter.h"
#import "WSBlock.h"
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
@property (nonatomic, strong) WSReachability *reachability;

@property (nonatomic, assign) BOOL keepConnected;
@property (nonatomic, assign) NSUInteger numberOfActiveResolutions;
@property (nonatomic, strong) NSMutableDictionary *ttlBySeed;           // NSString -> NSDate (background DNS thread)
@property (nonatomic, strong) NSMutableOrderedSet *inactiveAddresses;   // WSNetworkAddress
@property (nonatomic, strong) NSMutableDictionary *pendingPeers;        // NSString -> WSPeer
@property (nonatomic, strong) NSMutableDictionary *connectedPeers;      // NSString -> WSPeer
@property (nonatomic, strong) NSMutableSet *misbehavingHosts;           // NSString
@property (nonatomic, assign) NSUInteger connectionFailures;
@property (nonatomic, assign) NSUInteger sentBytes;
@property (nonatomic, assign) NSUInteger receivedBytes;

@property (nonatomic, strong) id<WSPeerGroupDownloadDelegate> downloadDelegate;

- (void)connect;
- (void)disconnect;
- (void)discoverNewHostsWithResolutionCallback:(void (^)(NSString *, NSArray *))resolutionCallback failure:(void (^)(NSError *))failure;
- (void)triggerConnectionsFromInactive;
- (void)openConnectionToPeerHost:(NSString *)host;
- (void)handleConnectionFailureFromPeer:(WSPeer *)peer error:(NSError *)error;
- (void)reconnectAfterDelay:(NSTimeInterval)delay;
- (void)removeInactiveHost:(NSString *)host;
- (void)signalMisbehavingPeer:(WSPeer *)peer error:(NSError *)error;
+ (BOOL)isHardNetworkError:(NSError *)error;

- (BOOL)unsafeIsConnected;
- (BOOL)unsafeHasReachedMaxAttempts;
- (BOOL)unsafeHasReachedMaxConnections;

@end

@implementation WSPeerGroup

- (instancetype)initWithParameters:(id<WSParameters>)parameters
{
    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:parameters];
    NSString *className = [self.class description];
    dispatch_queue_t queue = dispatch_queue_create(className.UTF8String, DISPATCH_QUEUE_SERIAL);

    return [self initWithParameters:parameters pool:pool queue:queue];
}

- (instancetype)initWithParameters:(id<WSParameters>)parameters pool:(WSConnectionPool *)pool queue:(dispatch_queue_t)queue
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(pool);
    WSExceptionCheckIllegal(queue);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        self.notifier = [[WSPeerGroupNotifier alloc] initWithPeerGroup:self];
        self.pool = pool;
        self.pool.connectionTimeout = WSPeerConnectTimeout;
        self.queue = queue;
        self.reachability = [WSReachability reachabilityForInternetConnection];
        self.reachability.delegate = self;
        self.reachability.delegateQueue = self.queue;

        // connection
//        self.peerHosts = nil;
        self.maxConnections = WSPeerGroupDefaultMaxConnections;
        self.maxConnectionFailures = WSPeerGroupDefaultMaxConnectionFailures;
        self.reconnectionDelayOnFailure = WSPeerGroupDefaultReconnectionDelay;
        self.seedTTL = 10 * WSDatesOneMinute;
        self.needsBloomFiltering = NO;
        
        self.keepConnected = NO;
        self.inactiveAddresses = [[NSMutableOrderedSet alloc] init];
        self.misbehavingHosts = [[NSMutableSet alloc] init];
        self.pendingPeers = [[NSMutableDictionary alloc] init];
        self.connectedPeers = [[NSMutableDictionary alloc] init];

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

//- (void)setPeerHosts:(NSArray *)peerHosts
//{
//    _peerHosts = peerHosts;
//    
//    self.maxConnections = _peerHosts.count;
//}

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

- (NSArray *)allConnectedPeers
{
    __block NSArray *allConnectedPeers;
    dispatch_sync(self.queue, ^{
        allConnectedPeers = [self.connectedPeers allValues];
    });
    return allConnectedPeers;
}

- (BOOL)hasReachedMaxConnections
{
    __block BOOL hasReachedMaxConnections;
    dispatch_sync(self.queue, ^{
        hasReachedMaxConnections = [self unsafeHasReachedMaxConnections];
    });
    return hasReachedMaxConnections;
}

#pragma mark Download (any queue)

- (void)startDownloadWithDelegate:(id<WSPeerGroupDownloadDelegate>)downloadDelegate
{
    dispatch_sync(self.queue, ^{
        if (self.downloadDelegate) {
            DDLogVerbose(@"Ignoring call because already downloading");
            return;
        }
        self.downloadDelegate = downloadDelegate;
        [self.downloadDelegate peerGroupDidStartDownload:self];
    });
}

- (void)stopDownload
{
    dispatch_sync(self.queue, ^{
        [self.downloadDelegate peerGroupDidStopDownload:self];
        self.downloadDelegate = nil;
    });
}

#pragma mark Events (group queue)

- (void)peerDidConnect:(WSPeer *)peer
{
    [self removeInactiveHost:peer.remoteHost];
    [self.pendingPeers removeObjectForKey:peer.remoteHost];
    self.connectedPeers[peer.remoteHost] = peer;
    
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
        error = WSErrorMake(WSErrorCodeNetworking, @"Peer %@ uses unsupported protocol version %u (< %u)", self, peer.version, WSPeerMinProtocol);
    }
    if ((peer.services & WSPeerServicesNodeNetwork) == 0) {
        error = WSErrorMake(WSErrorCodeNetworking, @"Peer %@ does not provide full node services", self);
    }
    if (error) {
        [self.pool closeConnectionForProcessor:peer error:error];
        return;
    }
    
    // peer was accepted, request recent addresses
    [peer sendGetaddr];

    [self.downloadDelegate peerGroup:self peerDidConnect:peer];
}

- (void)peer:(WSPeer *)peer didFailToConnectWithError:(NSError *)error
{
    [self.pendingPeers removeObjectForKey:peer.remoteHost];

    DDLogInfo(@"Failed to connect to %@%@", peer, WSStringOptional(error, @" (%@)"));

    [self handleConnectionFailureFromPeer:peer error:error];
}

- (void)peer:(WSPeer *)peer didDisconnectWithError:(NSError *)error
{
    [self.pendingPeers removeObjectForKey:peer.remoteHost];
    [self.connectedPeers removeObjectForKey:peer.remoteHost];

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

    [self.downloadDelegate peerGroup:self peer:peer didDisconnectWithError:error];
}

- (void)peerDidKeepAlive:(WSPeer *)peer
{
    [self.downloadDelegate peerGroup:self peerDidKeepAlive:peer];
}

- (void)peer:(WSPeer *)peer didReceiveHeaders:(NSArray *)headers
{
    DDLogVerbose(@"Received headers from %@: %@", peer, headers);

    if (!self.downloadDelegate) {
        return;
    }

    for (WSBlockHeader *header in headers) {
        NSError *error;
        if (![self.downloadDelegate peerGroup:self peer:peer shouldAcceptHeader:header error:&error]) {
            [self.pool closeConnectionForProcessor:peer error:error];
            return;
        }
    }
    
    [self.downloadDelegate peerGroup:self peer:peer didReceiveHeaders:headers];
}

- (void)peer:(WSPeer *)peer didReceiveInventories:(NSArray *)inventories
{
    DDLogVerbose(@"Received inventories from %@: %@", peer, inventories);
    
    if (!self.downloadDelegate) {
        return;
    }

    [self.downloadDelegate peerGroup:self peer:peer didReceiveInventories:inventories];
}

- (void)peer:(WSPeer *)peer didReceiveBlock:(WSBlock *)block
{
    DDLogVerbose(@"Received full block from %@: %@", peer, block);

    if (!self.downloadDelegate) {
        return;
    }

    NSError *error;
    if (![self.downloadDelegate peerGroup:self peer:peer shouldAcceptHeader:block.header error:&error]) {
        [self.pool closeConnectionForProcessor:peer error:error];
        return;
    }

    [self.downloadDelegate peerGroup:self peer:peer didReceiveBlock:block];
}

- (void)peer:(WSPeer *)peer didReceiveFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions
{
    DDLogVerbose(@"Received filtered block from %@: %@", peer, filteredBlock);

    if (!self.downloadDelegate) {
        return;
    }

    NSError *error;
    if (![self.downloadDelegate peerGroup:self peer:peer shouldAcceptHeader:filteredBlock.header error:&error]) {
        [self.pool closeConnectionForProcessor:peer error:error];
        return;
    }
    
    [self.downloadDelegate peerGroup:self peer:peer didReceiveFilteredBlock:filteredBlock withTransactions:transactions];
}

- (void)peer:(WSPeer *)peer didReceiveTransaction:(WSSignedTransaction *)transaction
{
    DDLogVerbose(@"Received transaction from %@: %@", peer, transaction);

    [self.downloadDelegate peerGroup:self peer:peer didReceiveTransaction:transaction];
}

- (void)peer:(WSPeer *)peer didReceiveAddresses:(NSArray *)addresses isLastRelay:(BOOL)isLastRelay
{
    DDLogDebug(@"Received %u addresses from %@", addresses.count, peer);
    
//    if (self.peerHosts) {
//        return;
//    }

    [self.inactiveAddresses addObjectsFromArray:addresses];

    if (![self unsafeHasReachedMaxAttempts]) {
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
    if ([self unsafeHasReachedMaxAttempts]) {
        DDLogInfo(@"Maximum connections or attempts reached (%u)", self.maxConnections);
        return;
    }
    if (![self.reachability isReachable]) {
        DDLogInfo(@"Network offline, not connecting");
        return;
    }
    if (self.connectionFailures == self.maxConnectionFailures) {
        DDLogInfo(@"Too many disconnections, not connecting");
        return;
    }
    
#warning TODO: fixed hosts list
//    if (self.peerHosts.count > 0) {
//        self.inactiveAddresses = [[NSMutableOrderedSet alloc] initWithCapacity:self.peerHosts.count];
//        for (NSString *host in self.peerHosts) {
//            
//        }
//        WSNetworkAddress *address = WSNetworkAddressMake(WSNetworkIPv4FromHost(host), [self.parameters peerPort], 0, WSCurrentTimestamp() - WSDatesOneWeek);
//        NSArray *newAddresses = [self disconnectedAddressesWithHosts:self.peerHosts];
//        [self.inactiveAddresses addObjectsFromArray:newAddresses];
//        
//        DDLogInfo(@"Connecting to inactive peers (available: %u)", self.inactiveAddresses.count);
////        DDLogDebug(@"%@", self.inactiveAddresses);
//        [self triggerConnectionsFromInactive];
//        return;
//    }

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
        
        NSMutableArray *newAddresses = [[NSMutableArray alloc] initWithCapacity:newHosts.count];
        const NSUInteger previousInactiveCount = self.inactiveAddresses.count;
        
        for (NSString *host in newHosts) {
            if (self.connectedPeers[host] || self.pendingPeers[host]) {
                continue;
            }
            WSNetworkAddress *address = WSNetworkAddressMake(WSNetworkIPv4FromHost(host),
                                                             [self.parameters peerPort],
                                                             0,
                                                             WSCurrentTimestamp() - WSDatesOneWeek);
            [newAddresses addObject:address];
            [self.inactiveAddresses addObject:address];
        }

        if (self.inactiveAddresses.count == previousInactiveCount) {
            DDLogDebug(@"All discovered peers are already connected or pending");
            return;
        }
        
        DDLogInfo(@"Connecting to discovered non-connected peers (available: %u)", newAddresses.count);
        DDLogDebug(@"%@", newAddresses);
        [self triggerConnectionsFromInactive];
    } failure:^(NSError *error) {
        DDLogError(@"DNS discovery failed: %@", error);
    }];
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
    if (self.numberOfActiveResolutions > 0) {
        DDLogWarn(@"Waiting for %u ongoing resolutions to complete", self.numberOfActiveResolutions);
        failure(WSErrorMake(WSErrorCodeNetworking, @"Another DNS discovery is still ongoing"));
        return;
    }
    
    NSArray *dnsSeeds = [self.parameters dnsSeeds];
    
    dispatch_apply(dnsSeeds.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(size_t i) {
        NSString *dns = dnsSeeds[i];
        DDLogInfo(@"%@ Resolving seed", dns);
        
        NSDate *ttl = self.ttlBySeed[dns];
        NSDate *now = [NSDate date];
        if (ttl && ([ttl laterDate:now] == ttl)) {
            DDLogInfo(@"%@ Not resolving, TTL yet to expire (%@ < %@)", dns, now, ttl);
            return;
        }

        dispatch_async(self.queue, ^{
            ++self.numberOfActiveResolutions;
        });
        
        CFHostRef host = CFHostCreateWithName(NULL, (__bridge CFStringRef)dns);
        if (!CFHostStartInfoResolution(host, kCFHostAddresses, NULL)) {
            DDLogError(@"%@ Error during resolution", dns);
            CFRelease(host);
            
            dispatch_async(self.queue, ^{
                --self.numberOfActiveResolutions;
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
        
        dispatch_async(self.queue, ^{
            --self.numberOfActiveResolutions;
        });

        self.ttlBySeed[dns] = [NSDate dateWithTimeIntervalSinceNow:self.seedTTL];
 
        if (rawAddresses.count > 0) {
            DDLogDebug(@"%@ Resolved %u addresses", dns, rawAddresses.count);
            
            NSMutableArray *hosts = [[NSMutableArray alloc] init];
            
            // add a faulty host to test automatic removal
//            [hosts addObject:@"124.170.89.58"]; // behind
//            [hosts addObject:@"152.23.202.18"]; // timeout
            
            for (NSData *rawBytes in rawAddresses) {
                if (rawBytes.length != sizeof(struct sockaddr_in)) {
                    continue;
                }
                struct sockaddr_in *rawAddress = (struct sockaddr_in *)rawBytes.bytes;
                const uint32_t address = rawAddress->sin_addr.s_addr;
                NSString *host = WSNetworkHostFromIPv4(address);
                
                if (host) {
                    [hosts addObject:host];
                }
            }
            
            DDLogDebug(@"%@ Retained %u resolved addresses (pruned ipv6)", dns, hosts.count);
            
            if (hosts.count > 0) {
                dispatch_async(self.queue, ^{
                    resolutionCallback(dns, hosts);
                });
            }
        }
    });
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
//        if ([self unsafeHasReachedMaxAttempts]) {
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
        const NSUInteger inactiveOffset = (NSUInteger)(pow(lrand48() % self.inactiveAddresses.count, 2) / self.inactiveAddresses.count);
        WSNetworkAddress *address = self.inactiveAddresses[inactiveOffset];
        
        if (self.pendingPeers[address.host] || [self.misbehavingHosts containsObject:address.host]) {
            continue;
        }
        if ([self unsafeHasReachedMaxAttempts]) {
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
    
    WSPeerFlags *flags = [[WSPeerFlags alloc] initWithNeedsBloomFiltering:self.needsBloomFiltering];
    
    WSPeer *peer = [[WSPeer alloc] initWithHost:host parameters:self.parameters flags:flags];
    peer.delegate = self;
    peer.delegateQueue = self.queue;
    self.pendingPeers[peer.remoteHost] = peer;
    
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

#pragma mark Download interface (unsafe)

- (void)disconnectPeer:(WSPeer *)peer error:(NSError *)error
{
    [self.pool closeConnectionForProcessor:peer error:error];
}

- (void)reportMisbehavingPeer:(WSPeer *)peer error:(NSError *)error
{
    [self.misbehavingHosts addObject:peer.remoteHost];
    [self.pool closeConnectionForProcessor:peer error:error];
}

#pragma mark External interface (unsafe)

- (BOOL)unsafeIsConnected
{
    return (self.connectedPeers.count > 0);
}

- (BOOL)unsafeHasReachedMaxAttempts
{
    return (self.connectedPeers.count + self.pendingPeers.count >= self.maxConnections);
}

- (BOOL)unsafeHasReachedMaxConnections
{
    return (self.connectedPeers.count >= self.maxConnections);
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
