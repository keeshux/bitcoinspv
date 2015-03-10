//
//  WSPeer.m
//  WaSPV
//
//  Created by Davide De Rosa on 13/06/14.
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

#import "WSPeer.h"
#import "WSProtocolDeserializer.h"
#import "WSNetworkAddress.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSStorableBlock.h"
#import "WSBlockChain.h"
#import "WSBlockLocator.h"
#import "WSInventory.h"
#import "WSTransaction.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"
#import "NSData+Binary.h"

@interface WSPeerParameters ()

@property (nonatomic, strong) id<WSParameters> parameters;
@property (nonatomic, strong) dispatch_queue_t groupQueue;
@property (nonatomic, strong) WSBlockChain *blockChain;
@property (nonatomic, assign) BOOL shouldDownloadBlocks;
@property (nonatomic, assign) BOOL needsBloomFiltering;

@end

@implementation WSPeerParameters

- (instancetype)initWithParameters:(id<WSParameters>)parameters
{
    return [self initWithParameters:parameters
                         groupQueue:dispatch_get_main_queue()
                         blockChain:nil
               shouldDownloadBlocks:YES
                needsBloomFiltering:YES];
}

- (instancetype)initWithParameters:(id<WSParameters>)parameters
                        groupQueue:(dispatch_queue_t)groupQueue
                        blockChain:(WSBlockChain *)blockChain
              shouldDownloadBlocks:(BOOL)shouldDownloadBlocks
               needsBloomFiltering:(BOOL)needsBloomFiltering
{
    WSExceptionCheckIllegal(parameters != nil, @"Nil parameters");
    WSExceptionCheckIllegal(groupQueue != NULL, @"NULL groupQueue");

    if ((self = [super init])) {
        self.parameters = parameters;
        self.groupQueue = groupQueue;
        self.blockChain = blockChain;
        self.shouldDownloadBlocks = shouldDownloadBlocks;
        self.needsBloomFiltering = needsBloomFiltering;
        self.port = [self.parameters peerPort];
    }
    return self;
}

@end

#pragma mark -

@interface WSPeer () {
    WSPeerStatus _peerStatus;
    BOOL _didReceiveVerack;
    BOOL _didSendVerack;
    NSString *_remoteHost;
    uint16_t _remotePort;
    uint64_t _remoteServices;
    uint64_t _nonce;
    NSTimeInterval _connectionStartTime;
    NSTimeInterval _connectionTime;
    NSTimeInterval _lastSeenTimestamp;
    WSMessageVersion *_receivedVersion;
    NSUInteger _sentBytes;
    NSUInteger _receivedBytes;
    BOOL _isDownloadPeer;
}

// only set on creation
@property (nonatomic, strong) id<WSParameters> parameters;
@property (nonatomic, strong) dispatch_queue_t groupQueue;
#ifdef WASPV_TEST_MESSAGE_QUEUE
@property (nonatomic, strong) NSCondition *messageQueueCondition;
@property (nonatomic, strong) NSMutableArray *messageQueue;
#endif

// only set on pool thread
@property (nonatomic, strong) dispatch_queue_t connectionQueue;
@property (nonatomic, strong) WSProtocolDeserializer *deserializer;
@property (nonatomic, strong) id<WSConnectionWriter> writer;

// sync status (shared by WSPeerGroup, guarded by self.groupQueue)
@property (nonatomic, strong) WSBlockChain *blockChain;
@property (nonatomic, assign) BOOL shouldDownloadBlocks;
@property (nonatomic, assign) BOOL needsBloomFiltering;
@property (nonatomic, strong) NSCountedSet *pendingBlockIds;
@property (nonatomic, strong) NSMutableOrderedSet *processingBlockIds;
@property (nonatomic, assign) BOOL isDownloadPeer;
@property (nonatomic, assign) uint32_t fastCatchUpTimestamp;
@property (nonatomic, strong) WSFilteredBlock *currentFilteredBlock;
@property (nonatomic, strong) NSMutableOrderedSet *currentFilteredTransactions;
@property (nonatomic, assign) NSUInteger filteredBlockCount;

// protocol
- (void)sendVersionMessageWithRelayTransactions:(uint8_t)relayTransactions;
- (void)sendVerackMessage;
- (void)sendPongMessageWithNonce:(uint64_t)nonce;
- (void)receiveMessage:(id<WSMessage>)message;
- (void)receiveVersionMessage:(WSMessageVersion *)message;
- (void)receiveVerackMessage:(WSMessageVerack *)message;
- (void)receiveAddrMessage:(WSMessageAddr *)message;
- (void)receiveInvMessage:(WSMessageInv *)message;
- (void)receiveGetdataMessage:(WSMessageGetdata *)message;
- (void)receiveNotfoundMessage:(WSMessageNotfound *)message;
- (void)receiveTxMessage:(WSMessageTx *)message;
- (void)receiveBlockMessage:(WSMessageBlock *)message;
- (void)receiveHeadersMessage:(WSMessageHeaders *)message;
- (void)receivePingMessage:(WSMessagePing *)message;
- (void)receivePongMessage:(WSMessagePong *)message;
- (void)receiveMerkleblockMessage:(WSMessageMerkleblock *)message;
- (void)receiveRejectMessage:(WSMessageReject *)message;

// sync
- (void)aheadRequestOnReceivedHeaders:(NSArray *)headers;
- (void)aheadRequestOnReceivedBlockHashes:(NSArray *)hashes;
- (void)requestHeadersWithLocator:(WSBlockLocator *)locator;
- (void)requestBlocksWithLocator:(WSBlockLocator *)locator;
- (void)addBlockHeaders:(NSArray *)headers; // WSBlockHeader
- (void)beginFilteredBlock:(WSFilteredBlock *)filteredBlock;
- (BOOL)addTransactionToCurrentFilteredBlock:(WSSignedTransaction *)transaction outdated:(BOOL *)outdated;
- (void)endCurrentFilteredBlock;
- (BOOL)shouldDownloadBlocks;
- (BOOL)needsBloomFiltering;

// utils
- (void)unsafeSendMessage:(id<WSMessage>)message;
- (BOOL)tryFinishHandshake;
- (void)didSendNumberOfBytes:(NSUInteger)numberOfBytes;
- (void)didReceiveNumberOfBytes:(NSUInteger)numberOfBytes;

@end

@implementation WSPeer

- (instancetype)initWithHost:(NSString *)host parameters:(id<WSParameters>)parameters
{
    return [self initWithHost:host peerParameters:[[WSPeerParameters alloc] initWithParameters:parameters]];
}

- (instancetype)initWithHost:(NSString *)host peerParameters:(WSPeerParameters *)peerParameters
{
    WSExceptionCheckIllegal(host != nil, @"Nil host");
    WSExceptionCheckIllegal(peerParameters != nil, @"Nil peerParameters");
    
    if ((self = [super init])) {
        self.writeTimeout = WSPeerWriteTimeout;
#ifdef WASPV_TEST_MESSAGE_QUEUE
        self.messageQueueCondition = [[NSCondition alloc] init];
        self.messageQueue = [[NSMutableArray alloc] init];
#endif

        self.parameters = peerParameters.parameters;
        self.groupQueue = peerParameters.groupQueue;
        self.blockChain = peerParameters.blockChain;
        self.shouldDownloadBlocks = peerParameters.shouldDownloadBlocks;
        self.needsBloomFiltering = peerParameters.needsBloomFiltering;

        _peerStatus = WSPeerStatusDisconnected;
        _remoteHost = host;
        _remotePort = peerParameters.port;

        self.pendingBlockIds = [[NSCountedSet alloc] init];
        self.processingBlockIds = [[NSMutableOrderedSet alloc] initWithCapacity:(2 * WSMessageBlocksMaxCount)];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSPeer *peer = object;
    @synchronized (self) {
        return ((peer.remoteAddress == self.remoteAddress) && (peer.remotePort == self.remotePort));
    }
}

//
// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRPeer.m
//
// FNV32-1a hash of the ip address and port number: http://www.isthe.com/chongo/tech/comp/fnv/index.html#FNV-1a
//
- (NSUInteger)hash
{
    static const uint32_t prime = 0x01000193;
    static const uint32_t offset = 0x811c9dc5;

    uint32_t hash = offset;
    @synchronized (self) {
        const uint32_t remoteAddress = self.remoteAddress;
        hash = (hash ^ ((remoteAddress >> 24) & 0xff)) * prime;
        hash = (hash ^ ((remoteAddress >> 16) & 0xff)) * prime;
        hash = (hash ^ ((remoteAddress >> 8) & 0xff)) * prime;
        hash = (hash ^ (remoteAddress & 0xff)) * prime;
        hash = (hash ^ ((_remotePort >> 8) & 0xff)) * prime;
        hash = (hash ^ (_remotePort & 0xff)) * prime;
    }
    return hash;
}

- (NSString *)description
{
    @synchronized (self) {
        return [NSString stringWithFormat:@"(%@:%u)", _remoteHost, _remotePort];
    }
}

#pragma mark WSConnectionProcessor (connection queue)

- (void)openedConnectionToHost:(NSString *)host port:(uint16_t)port queue:(dispatch_queue_t)queue
{
    @synchronized (self) {
        NSAssert([host isEqualToString:_remoteHost], @"Connected host differs from remoteHost");
        NSAssert(port == _remotePort, @"Connected port differs from remotePort");
    
        self.connectionQueue = queue;
        _peerStatus = WSPeerStatusConnecting;
        _didReceiveVerack = NO;
        _didSendVerack = NO;
        _remoteHost = host;
        _remotePort = port;
        _remoteServices = 0;
        _nonce = mrand48();
        _connectionStartTime = DBL_MAX;
        _connectionTime = DBL_MAX;
        _lastSeenTimestamp = NSTimeIntervalSince1970;
        _receivedVersion = nil;
    }

    DDLogDebug(@"%@ Connection opened", self);

    self.deserializer = [[WSProtocolDeserializer alloc] initWithPeer:self];
    [self sendVersionMessageWithRelayTransactions:(uint8_t)![self needsBloomFiltering]];
}

- (void)processData:(NSData *)data
{
    [self didReceiveNumberOfBytes:data.length];
    [self.deserializer appendData:data];
    
    NSError *error;
    id<WSMessage> message = nil;
    do {
        message = [self.deserializer parseMessageWithError:&error];
        if (message) {
            [self receiveMessage:message];
        }
        else if (error) {
            DDLogError(@"%@ Error deserializing message: %@", self, error);
            if (error.code == WSErrorCodeMalformed) {
                [self.writer disconnectWithError:error];
            }
        }
    } while (message);
}

- (void)closedConnectionWithError:(NSError *)error
{
    DDLogDebug(@"%@ Connection closed%@", self, WSStringOptional(error, @" (%@)"));
    
    @synchronized (self) {
        _peerStatus = WSPeerStatusDisconnected;
    }

    dispatch_async(self.groupQueue, ^{
        [self.delegate peer:self didDisconnectWithError:error];
    });
}

#pragma mark Connection

- (BOOL)isConnected
{
    @synchronized (self) {
        NSAssert((self.connectionQueue != NULL) == (_peerStatus != WSPeerStatusDisconnected),
                 @"Connection queue must not be NULL as long as a connection is active");
        
        return (self.connectionQueue != NULL);
    }
}

- (WSPeerStatus)peerStatus
{
    @synchronized (self) {
        return _peerStatus;
    }
}

- (NSString *)remoteHost
{
    @synchronized (self) {
        return _remoteHost;
    }
}

- (uint32_t)remoteAddress
{
    @synchronized (self) {
        return WSNetworkIPv4FromHost(_remoteHost);
    }
}

- (uint16_t)remotePort
{
    @synchronized (self) {
        return _remotePort;
    }
}

- (NSTimeInterval)connectionTime
{
    @synchronized (self) {
        return _connectionTime;
    }
}

- (NSTimeInterval)lastSeenTimestamp
{
    @synchronized (self) {
        return _lastSeenTimestamp;
    }
}

- (WSMessageVersion *)receivedVersion
{
    @synchronized (self) {
        if (!_receivedVersion) {
            DDLogWarn(@"%@ Reading version while disconnected", self);
            return nil;
        }
        return _receivedVersion;
    }
}

- (void)setReceivedVersion:(WSMessageVersion *)receivedVersion
{
    @synchronized (self) {
        _receivedVersion = receivedVersion;
    }
}

- (uint32_t)version
{
    return self.receivedVersion.version;
}

- (uint64_t)services
{
    return self.receivedVersion.services;
}

- (uint64_t)timestamp
{
    return self.receivedVersion.timestamp;
}

- (uint32_t)lastBlockHeight
{
    return self.receivedVersion.lastBlockHeight;
}

- (NSUInteger)sentBytes
{
    @synchronized (self) {
        return _sentBytes;
    }
}

- (NSUInteger)receivedBytes
{
    @synchronized (self) {
        return _receivedBytes;
    }
}

//
// VERY IMPORTANT: since the delegate (peer group) is the master peer controller, let it also do the
// clean up in didDisconnectWithError.
//
// this is extremely important because as long as the peer does the clean up by itself there'll be a
// short period during which the peer is disconnected and the peer group is not aware. indeed, it
// would still treat the peer as if it was connected because it would still belong to the
// connectedPeers set.
//
// NOTE: we're assuming that peer connection and peer group run on different queues
//
- (void)cleanUpConnectionData
{
    self.deserializer = nil;
    
    @synchronized (self) {
//        self.connectionQueue = NULL;
//        self.delegate = nil;
//        
//        _remoteHost = nil;
//        _remotePort = 0;
//        _remoteServices = 0;
//        _nonce = 0;
//        _pingTime = DBL_MAX;
//        _lastSeenTimestamp = NSTimeIntervalSince1970;
//        _receivedVersion = nil;

        [self.pendingBlockIds removeAllObjects];
        [self.processingBlockIds removeAllObjects];
    }
}

#pragma mark Protocol: send* (connection queue)

- (void)sendVersionMessageWithRelayTransactions:(uint8_t)relayTransactions
{
    NSAssert(self.connectionQueue, @"Not connected");
    
    dispatch_async(self.connectionQueue, ^{
        WSNetworkAddress *networkAddress = [[WSNetworkAddress alloc] initWithTimestamp:0 services:_remoteServices ipv4Address:self.remoteAddress port:_remotePort];
        WSMessageVersion *message = [WSMessageVersion messageWithParameters:self.parameters
                                                                    version:WSPeerProtocol
                                                                   services:WSPeerEnabledServices
                                                       remoteNetworkAddress:networkAddress
                                                                  localPort:[self.parameters peerPort]
                                                          relayTransactions:relayTransactions];

        _nonce = message.nonce;
        _connectionStartTime = [NSDate timeIntervalSinceReferenceDate];

        [self unsafeSendMessage:message];
    });
}

- (void)sendVerackMessage
{
    NSAssert(self.connectionQueue, @"Not connected");

    dispatch_async(self.connectionQueue, ^{
        @synchronized (self) {
            if (_didSendVerack) {
                DDLogWarn(@"%@ Unexpected 'verack' sending", self);
                return;
            }
        }
        
        [self unsafeSendMessage:[WSMessageVerack messageWithParameters:self.parameters]];
        @synchronized (self) {
            _didSendVerack = YES;
        }
        [self tryFinishHandshake];
    });
}

- (void)sendInvMessageWithInventory:(WSInventory *)inventory
{
    WSExceptionCheckIllegal(inventory != nil, @"Nil inventory");
    
    [self sendInvMessageWithInventories:@[inventory]];
}

- (void)sendInvMessageWithInventories:(NSArray *)inventories
{
    NSAssert(self.connectionQueue, @"Not connected");
    WSExceptionCheckIllegal(inventories.count > 0, @"Empty inventories");

    dispatch_async(self.connectionQueue, ^{
        [self unsafeSendMessage:[WSMessageInv messageWithParameters:self.parameters inventories:inventories]];
    });
}

- (void)sendGetdataMessageWithHashes:(NSArray *)hashes forInventoryType:(WSInventoryType)inventoryType
{
    NSAssert(self.connectionQueue, @"Not connected");
    WSExceptionCheckIllegal(hashes.count > 0, @"Empty hashes");

    NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:hashes.count];
    for (WSHash256 *hash in hashes) {
        [inventories addObject:[[WSInventory alloc] initWithType:inventoryType hash:hash]];
    }
    [self sendGetdataMessageWithInventories:inventories];
}

- (void)sendGetdataMessageWithInventories:(NSArray *)inventories
{
    NSAssert(self.connectionQueue, @"Not connected");
    WSExceptionCheckIllegal(inventories.count > 0, @"Empty inventories");

    NSMutableArray *blockHashes = [[NSMutableArray alloc] initWithCapacity:inventories.count];
    BOOL willRequestFilteredBlocks = NO;

    for (WSInventory *inv in inventories) {
        if ([inv isBlockInventory]) {
            [blockHashes addObject:inv.inventoryHash];

            // enforce ping as non-tx separator after merkleblock + tx messages
            if (inv.inventoryType == WSInventoryTypeFilteredBlock) {
                willRequestFilteredBlocks = YES;
            }
        }
    }

    BOOL shouldReloadBloomFilter = NO;

    @synchronized (self) {
        [self.pendingBlockIds addObjectsFromArray:blockHashes];
        [self.processingBlockIds addObjectsFromArray:blockHashes];

        if ([self needsBloomFiltering]) {
            DDLogDebug(@"%@ Filtered %u blocks so far (height: %u)", self, _filteredBlockCount, self.blockChain.currentHeight);
            
            if (_filteredBlockCount + blockHashes.count > WSPeerMaxFilteredBlockCount) {
                DDLogDebug(@"%@ Bloom filter may deteriorate after %u blocks (%u + %u > %u), refreshing now", self,
                           blockHashes.count, _filteredBlockCount, blockHashes.count, WSPeerMaxFilteredBlockCount);

                shouldReloadBloomFilter = YES;
            }
            else {
                DDLogDebug(@"%@ Bloom filter doesn't need a refresh", self);
                _filteredBlockCount += blockHashes.count;
            }
        }
    }

    dispatch_async(self.connectionQueue, ^{

        // the filter must be guaranteed to be fresh BEFORE sending a new getdata
        if (shouldReloadBloomFilter) {
            dispatch_sync(self.groupQueue, ^{
                [self.delegate peerDidRequestFilterReload:self];
            });
        }

        [self unsafeSendMessage:[WSMessageGetdata messageWithParameters:self.parameters inventories:inventories]];
        if (willRequestFilteredBlocks) {
            [self unsafeSendMessage:[WSMessagePing messageWithParameters:self.parameters]];
        }
    });
}

- (void)sendNotfoundMessageWithInventories:(NSArray *)inventories
{
    NSAssert(self.connectionQueue, @"Not connected");
    WSExceptionCheckIllegal(inventories.count > 0, @"Empty inventories");

    dispatch_async(self.connectionQueue, ^{
        [self unsafeSendMessage:[WSMessageNotfound messageWithParameters:self.parameters inventories:inventories]];
    });
}

- (void)sendGetblocksMessageWithLocator:(WSBlockLocator *)locator hashStop:(WSHash256 *)hashStop
{
    NSAssert(self.connectionQueue, @"Not connected");
    WSExceptionCheckIllegal(locator != nil, @"Nil locator");
    
    dispatch_async(self.connectionQueue, ^{
        [self unsafeSendMessage:[WSMessageGetblocks messageWithParameters:self.parameters version:WSPeerProtocol locator:locator hashStop:hashStop]];
    });
}

- (void)sendGetheadersMessageWithLocator:(WSBlockLocator *)locator hashStop:(WSHash256 *)hashStop
{
    NSAssert(self.connectionQueue, @"Not connected");
    WSExceptionCheckIllegal(locator != nil, @"Nil locator");
    
    dispatch_async(self.connectionQueue, ^{
        [self unsafeSendMessage:[WSMessageGetheaders messageWithParameters:self.parameters version:WSPeerProtocol locator:locator hashStop:hashStop]];
    });
}

- (void)sendTxMessageWithTransaction:(WSSignedTransaction *)transaction
{
    NSAssert(self.connectionQueue, @"Not connected");
    WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");

    dispatch_async(self.connectionQueue, ^{
        [self unsafeSendMessage:[WSMessageTx messageWithParameters:self.parameters transaction:transaction]];
    });
}

- (void)sendGetaddr
{
    NSAssert(self.connectionQueue, @"Not connected");
    
    dispatch_async(self.connectionQueue, ^{
        [self unsafeSendMessage:[WSMessageGetaddr messageWithParameters:self.parameters]];
    });
}

- (void)sendMempoolMessage
{
    NSAssert(self.connectionQueue, @"Not connected");
    
    dispatch_async(self.connectionQueue, ^{
        [self unsafeSendMessage:[WSMessageMempool messageWithParameters:self.parameters]];
    });
}

- (void)sendPingMessage
{
    NSAssert(self.connectionQueue, @"Not connected");
    
    dispatch_async(self.connectionQueue, ^{
        @synchronized (self) {
            NSAssert(_nonce, @"Nonce not set, is handshake complete?");
        }
        [self unsafeSendMessage:[WSMessagePing messageWithParameters:self.parameters]];
    });
}

- (void)sendPongMessageWithNonce:(uint64_t)nonce
{
    NSAssert(self.connectionQueue, @"Not connected");
    
    dispatch_async(self.connectionQueue, ^{
        [self unsafeSendMessage:[WSMessagePong messageWithParameters:self.parameters nonce:nonce]];
    });
}

- (void)sendFilterloadMessageWithFilter:(WSBloomFilter *)filter
{
    NSAssert(self.connectionQueue, @"Not connected");
    WSExceptionCheckIllegal(filter != nil, @"Nil filter");

    dispatch_async(self.connectionQueue, ^{
        @synchronized (self) {
            _filteredBlockCount = 0;
        }
        [self unsafeSendMessage:[WSMessageFilterload messageWithParameters:self.parameters filter:filter]];
    });
}

#pragma mark Protocol: receive* (group queue)

- (void)receiveMessage:(id<WSMessage>)message
{
    NSParameterAssert(message);
    
    if (message.originalPayload.length < 1024) {
        DDLogVerbose(@"%@ Received %@ (%u bytes)", self, message, message.originalPayload.length);
    }
    else {
        DDLogVerbose(@"%@ Received %@ (%u bytes, too long to display)", self, [message class], message.originalPayload.length);
    }
    
    SEL selector = NSSelectorFromString([NSString stringWithFormat:@"receive%@Message:", [message.messageType capitalizedString]]);
    if ([self respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        // execute in peer group queue (don't lock connection queue)
        dispatch_async(self.groupQueue, ^{
        
            // stop reading txs for current merkleblock
            @synchronized (self.groupQueue) {
                if (self.currentFilteredBlock && ![message isKindOfClass:[WSMessageTx class]]) {
                    [self endCurrentFilteredBlock];
                }
            }
            
            [self performSelector:selector withObject:message];
        });
        
#pragma clang diagnostic pop
    }
    else {
        DDLogDebug(@"%@ Unhandled message '%@'", self, message.messageType);
    }
    
#ifdef WASPV_TEST_MESSAGE_QUEUE
    [self.messageQueueCondition lock];
    [self.messageQueue addObject:message];
    [self.messageQueueCondition signal];
    [self.messageQueueCondition unlock];
#endif
}

//
// requested message = only received upon manual request
// unsolicited message = received both on request and spontaneously
//
// headers = requested (getheaders)
// inv = requested (getblocks, mempool) or unsolicited
// getdata = unsolicited
// merkleblock = requested (getdata)
// tx = requested (getdata)
// addr = requested (getaddr) or unsolicited
//

- (void)receiveVersionMessage:(WSMessageVersion *)message
{
    self.receivedVersion = message;
    [self sendVerackMessage];
}

- (void)receiveVerackMessage:(WSMessageVerack *)message
{
    @synchronized (self) {
        if (_didReceiveVerack) {
            DDLogWarn(@"%@ Unexpected 'verack' received", self);
            return;
        }
        _connectionTime = [NSDate timeIntervalSinceReferenceDate] - _connectionStartTime;
        _didReceiveVerack = YES;
    }
    DDLogDebug(@"%@ Got 'verack' in %.3fs", self, self.connectionTime);
    
    [self tryFinishHandshake];
}

- (void)receiveAddrMessage:(WSMessageAddr *)message
{
    DDLogDebug(@"%@ Received %u addresses", self, message.addresses.count);
    
    const BOOL isLastRelay = ((message.addresses.count > 1) && (message.addresses.count < WSMessageAddrMaxCount));

    [self.delegate peer:self didReceiveAddresses:message.addresses isLastRelay:isLastRelay];
}

- (void)receiveInvMessage:(WSMessageInv *)message
{
    NSArray *inventories = message.inventories;
    if (inventories.count == 0) {
        DDLogWarn(@"%@ Received empty inventories", self);
        return;
    }
 
    DDLogDebug(@"%@ Received %u inventories", self, message.inventories.count);

    NSMutableArray *requestInventories = [[NSMutableArray alloc] initWithCapacity:message.inventories.count];
    NSMutableArray *requestBlockHashes = [[NSMutableArray alloc] initWithCapacity:message.inventories.count];
    
    for (WSInventory *inv in message.inventories) {
        if ([inv isBlockInventory]) {
            if ([self needsBloomFiltering]) {
                [requestInventories addObject:WSInventoryFilteredBlock(inv.inventoryHash)];
            }
            else {
                [requestInventories addObject:WSInventoryBlock(inv.inventoryHash)];
            }
            [requestBlockHashes addObject:inv.inventoryHash];
        }
        else {
            [requestInventories addObject:inv];
        }
    }
    NSAssert(requestBlockHashes.count <= requestInventories.count, @"Requesting more blocks than total inventories?");

    if (requestInventories.count > 0) {
        if (requestBlockHashes.count > 0) {
            [self aheadRequestOnReceivedBlockHashes:requestBlockHashes];
        }
        [self sendGetdataMessageWithInventories:requestInventories];
    }
}

- (void)receiveGetdataMessage:(WSMessageGetdata *)message
{
    [self.delegate peer:self didReceiveDataRequestWithInventories:message.inventories];
}

- (void)receiveNotfoundMessage:(WSMessageNotfound *)message
{
    DDLogDebug(@"%@ Got 'notfound' with %u items", self, message.inventories.count);
}

- (void)receiveTxMessage:(WSMessageTx *)message
{
    WSSignedTransaction *transaction = message.transaction;

    BOOL outdated = NO;
    if (![self addTransactionToCurrentFilteredBlock:transaction outdated:&outdated] && outdated) {
        return;
    }
    
    [self.delegate peer:self didReceiveTransaction:transaction];
}

- (void)receiveBlockMessage:(WSMessageBlock *)message
{
    WSBlock *block = message.block;
    
    [self.delegate peer:self didReceiveBlock:block];
}

- (void)receiveHeadersMessage:(WSMessageHeaders *)message
{
    NSArray *headers = message.headers;
    if (headers.count == 0) {
        DDLogWarn(@"%@ Received empty headers", self);
        return;
    }

    [self aheadRequestOnReceivedHeaders:headers];
    [self addBlockHeaders:headers];
}

- (void)receivePingMessage:(WSMessagePing *)message
{
    [self sendPongMessageWithNonce:message.nonce];
}

- (void)receivePongMessage:(WSMessagePong *)message
{
    [self.delegate peer:self didReceivePongMesage:message];
}

- (void)receiveMerkleblockMessage:(WSMessageMerkleblock *)message
{
    [self beginFilteredBlock:message.block];
}

- (void)receiveRejectMessage:(WSMessageReject *)message
{
    [self.delegate peer:self didReceiveRejectMessage:message];
}

#pragma mark Sync

- (BOOL)isDownloadPeer
{
    @synchronized (self.groupQueue) {
        return _isDownloadPeer;
    }
}

- (void)setIsDownloadPeer:(BOOL)isDownloadPeer
{
    @synchronized (self.groupQueue) {
        _isDownloadPeer = isDownloadPeer;
    }
}

- (BOOL)downloadBlockChainWithFastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp prestartBlock:(void (^)(NSUInteger, NSUInteger))prestartBlock syncedBlock:(void (^)(NSUInteger))syncedBlock
{
    @synchronized (self.groupQueue) {
        NSAssert(self.isDownloadPeer, @"Not download peer");
        NSAssert(self.isConnected, @"Syncing with disconnected peer?");
        
        if ([self numberOfBlocksLeft] == 0) {
            if (syncedBlock) {
                syncedBlock(self.blockChain.currentHeight);
            }
            return NO;
        }
        
        self.fastCatchUpTimestamp = fastCatchUpTimestamp;
        self.currentFilteredBlock = nil;
        self.currentFilteredTransactions = nil;
        
        WSStorableBlock *checkpoint = [self.parameters lastCheckpointBeforeTimestamp:fastCatchUpTimestamp];
        if (checkpoint) {
            DDLogDebug(@"%@ Last checkpoint before catch-up: %@ (%@)",
                       self, checkpoint, [NSDate dateWithTimeIntervalSince1970:checkpoint.header.timestamp]);
            
            [self.blockChain addCheckpoint:checkpoint error:NULL];
        }
        else {
            DDLogDebug(@"%@ No fast catch-up checkpoint", self);
        }
        
        if (prestartBlock) {
            const NSUInteger fromHeight = self.blockChain.currentHeight;
            const NSUInteger toHeight = self.lastBlockHeight;

            prestartBlock(fromHeight, toHeight);
        }
        
        WSBlockLocator *locator = [self.blockChain currentLocator];

        if (![self shouldDownloadBlocks] || (self.blockChain.currentTimestamp < self.fastCatchUpTimestamp)) {
            [self requestHeadersWithLocator:locator];
        }
        else {
            [self requestBlocksWithLocator:locator];
        }
        
        return YES;
    }
}

- (NSUInteger)numberOfBlocksLeft
{
    @synchronized (self.groupQueue) {
        NSAssert(self.isDownloadPeer, @"Not download peer");
        
        if (self.blockChain.currentHeight >= self.lastBlockHeight) {
            return 0;
        }
        return (self.lastBlockHeight - self.blockChain.currentHeight);
    }
}

- (void)requestOutdatedBlocks
{
    //
    // since receive* and delegate methods run on the same queue,
    // a peer should never request more hashes until delegate processed
    // all blocks with last received hashes
    //
    //
    // 1. start download calling getblocks with current chain locator
    // ...
    // 2. receiveInv called with max 500 inventories (in response to 1)
    // 3. receiveInv: call getblocks with new locator
    // 4. receiveInv: call getdata with received inventories
    // 5. processingBlocksIds.count <= 500
    // ...
    // 6. receiveInv called with max 500 inventories (in response to 3)
    // 7. receiveInv: call getblocks with new locator
    // 8. receiveInv: call getdata with received inventories
    // 9. processingBlocksIds.count <= 1000
    // ...
    // 10. receiveMerkleblock + receiveTx (in response to 4)
    // 11. processingBlockIds.count <= 500
    // ...
    // 12. receiveInv called with max 500 inventories (in response to 7)
    // 13. receiveInv: call getblocks with new locator
    // 14. receiveInv: call getdata with received inventories
    // 15. processingBlockIds.count <= 1000
    // ...
    //
    //
    // that's why processingBlockIds should reach 1000 at most (2 * max)
    //

    NSArray *outdatedIds = nil;
    @synchronized (self) {
//        NSAssert(self.processingBlockIds.count <= 2 * WSMessageBlocksMaxCount, @"Processing too many blocks (%u > %u)",
//                 self.processingBlockIds.count, 2 * WSMessageBlocksMaxCount);

        outdatedIds = [self.processingBlockIds array];
    }
    
#warning XXX: outdatedIds size shouldn't overflow WSMessageMaxInventories

    if (outdatedIds.count > 0) {
        DDLogDebug(@"Requesting %u outdated blocks with updated Bloom filter: %@", outdatedIds.count, outdatedIds);
        [self sendGetdataMessageWithHashes:outdatedIds forInventoryType:WSInventoryTypeFilteredBlock];
    }
    else {
        DDLogDebug(@"No outdated blocks to request with updated Bloom filter");
    }
}

- (void)replaceCurrentBlockChainWithBlockChain:(WSBlockChain *)blockChain
{
    WSExceptionCheckIllegal(blockChain != nil, @"Nil blockChain");
    
    @synchronized (self) {
        self.blockChain = blockChain;
    }
}

#pragma mark Sync automation (group queue)

- (void)aheadRequestOnReceivedHeaders:(NSArray *)headers
{
    NSParameterAssert(headers.count > 0);
    
    @synchronized (self.groupQueue) {
        if (self.isDownloadPeer) {
            const NSUInteger currentHeight = self.blockChain.currentHeight;
            
            DDLogDebug(@"%@ Still behind (%u < %u), requesting more headers ahead of time",
                       self, currentHeight, self.lastBlockHeight);
            
            WSBlockHeader *firstHeader = [headers firstObject];
            WSBlockHeader *lastHeader = [headers lastObject];
            WSBlockHeader *lastHeaderBeforeFCU = nil;
            
            // infer the header we'll stop at
            for (WSBlockHeader *header in headers) {
                if (header.timestamp >= self.fastCatchUpTimestamp) {
                    break;
                }
                lastHeaderBeforeFCU = header;
            }
            
            // we won't cross fast catch-up, request more headers
            if (![self shouldDownloadBlocks] || (lastHeaderBeforeFCU == lastHeader)) {
                WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:@[lastHeader.blockId, firstHeader.blockId]];
                [self requestHeadersWithLocator:locator];
            }
            // we will cross fast catch-up, request blocks from crossing point
            else {

                // all current headers are beyond catch-up, request blocks after chain head
                if (!lastHeaderBeforeFCU) {
                    lastHeaderBeforeFCU = self.blockChain.head.header;
                }
                
                DDLogInfo(@"%@ Last header before catch-up at block %@, timestamp %u (%@)",
                          self, lastHeaderBeforeFCU.blockId, lastHeaderBeforeFCU.timestamp,
                          [NSDate dateWithTimeIntervalSince1970:lastHeaderBeforeFCU.timestamp]);
                
                WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:@[lastHeaderBeforeFCU.blockId, firstHeader.blockId]];
                [self requestBlocksWithLocator:locator];
            }
        }
    }
}

- (void)aheadRequestOnReceivedBlockHashes:(NSArray *)hashes
{
    NSParameterAssert(hashes.count > 0);
    
    @synchronized (self.groupQueue) {
        if (self.isDownloadPeer && (hashes.count >= WSMessageBlocksMaxCount)) {
            const NSUInteger currentHeight = self.blockChain.currentHeight;
            
            DDLogDebug(@"%@ Still behind (%u < %u), requesting more blocks ahead of time",
                       self, currentHeight, self.lastBlockHeight);
            
            WSHash256 *firstId = [hashes firstObject];
            WSHash256 *lastId = [hashes lastObject];
            
            WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:@[lastId, firstId]];
            [self requestBlocksWithLocator:locator];
        }
    }
}

- (void)requestHeadersWithLocator:(WSBlockLocator *)locator
{
    DDLogDebug(@"%@ Behind catch-up (or headers-only mode), requesting headers with locator: %@", self, locator.hashes);
    [self sendGetheadersMessageWithLocator:locator hashStop:nil];
}

- (void)requestBlocksWithLocator:(WSBlockLocator *)locator
{
    DDLogDebug(@"%@ Beyond catch-up (or full blocks mode), requesting block hashes with locator: %@", self, locator.hashes);
    [self sendGetblocksMessageWithLocator:locator hashStop:nil];
}

- (void)addBlockHeaders:(NSArray *)headers
{
    NSParameterAssert(headers.count > 0);
    
    @synchronized (self.groupQueue) {
        for (WSBlockHeader *header in headers) {
            
            // download peer should stop requesting headers when fast catch-up reached
            if ([self shouldDownloadBlocks] && self.isDownloadPeer && (header.timestamp >= self.fastCatchUpTimestamp)) {
                break;
            }
            
            [self.delegate peer:self didReceiveHeader:header];
        }
    }
}

- (void)beginFilteredBlock:(WSFilteredBlock *)filteredBlock
{
    NSParameterAssert(filteredBlock);

    @synchronized (self.groupQueue) {
        self.currentFilteredBlock = filteredBlock;
        self.currentFilteredTransactions = [[NSMutableOrderedSet alloc] init];
    }
}

- (BOOL)addTransactionToCurrentFilteredBlock:(WSSignedTransaction *)transaction outdated:(BOOL *)outdated
{
    NSParameterAssert(transaction);
    NSParameterAssert(outdated);
    
    @synchronized (self.groupQueue) {
        if (!self.currentFilteredBlock) {
            DDLogDebug(@"%@ Transaction %@ outside filtered block", self, transaction.txId);
            return NO;
        }

        // only accept txs from most recently requested block
        @synchronized (self) {
            WSHash256 *blockId = self.currentFilteredBlock.header.blockId;
            if ([self.pendingBlockIds countForObject:blockId] > 1) {
                DDLogDebug(@"%@ Drop transaction %@ from current filtered block %@ (outdated by new pending request)",
                           self, transaction.txId, blockId);

                *outdated = YES;
                return NO;
            }
        }
        
        if (![self.currentFilteredBlock containsTransactionWithId:transaction.txId]) {
            DDLogDebug(@"%@ Transaction %@ is not contained in filtered block %@",
                       self, transaction.txId, self.currentFilteredBlock.header.blockId);

            return NO;
        }

        DDLogVerbose(@"%@ Adding transaction %@ to filtered block %@",
                     self, transaction.txId, self.currentFilteredBlock.header.blockId);

        [self.currentFilteredTransactions addObject:transaction];

        return YES;
    }
}

- (void)endCurrentFilteredBlock
{
    @synchronized (self.groupQueue) {
        WSFilteredBlock *filteredBlock = self.currentFilteredBlock;
        NSOrderedSet *transactions = self.currentFilteredTransactions;
        NSAssert(filteredBlock && transactions, @"Nil filteredBlock or transactions");

        self.currentFilteredBlock = nil;
        self.currentFilteredTransactions = nil;
        
        // only accept most recently requested block
        @synchronized (self) {
            WSHash256 *blockId = filteredBlock.header.blockId;

            [self.pendingBlockIds removeObject:blockId];

            if ([self.pendingBlockIds containsObject:blockId]) {
                DDLogDebug(@"%@ Drop filtered block %@ (outdated by new pending request)", self, blockId);
                return;
            }

            [self.processingBlockIds removeObject:blockId];
        }

        [self.delegate peer:self didReceiveFilteredBlock:filteredBlock withTransactions:transactions];
    }
}

#pragma mark Utils (unsafe)

// run this from connection queue
- (void)unsafeSendMessage:(id<WSMessage>)message
{
    @synchronized (self) {
        if (_peerStatus == WSPeerStatusDisconnected) {
            DDLogWarn(@"%@ Not connected", self);
            return;
        }
    }
    
    NSUInteger headerLength;
    WSBuffer *buffer = [message toNetworkBufferWithHeaderLength:&headerLength];
    if (buffer.length > WSMessageMaxLength) {
        DDLogError(@"%@ Error sending '%@', message is too long (%u > %u)", self, message.messageType, buffer.length, WSMessageMaxLength);
        return;
    }
    
    DDLogVerbose(@"%@ Sending %@ (%u bytes)", self, message, buffer.length - headerLength);
    DDLogVerbose(@"%@ Sending data: %@", self, [buffer.data hexString]);
    
    [self.writer writeData:buffer.data timeout:WSPeerWriteTimeout];
    [self didSendNumberOfBytes:buffer.length];
}

- (BOOL)tryFinishHandshake
{
    @synchronized (self) {
        if ((_peerStatus != WSPeerStatusConnecting) || !_didSendVerack || !_didReceiveVerack) {
            return NO;
        }
        
        _peerStatus = WSPeerStatusConnected;
        _lastSeenTimestamp = WSCurrentTimestamp();
    }
    
    DDLogDebug(@"%@ Handshake complete", self);
    
    dispatch_async(self.groupQueue, ^{
        [self.delegate peerDidConnect:self];
    });
    
    return YES;
}

- (void)didSendNumberOfBytes:(NSUInteger)numberOfBytes
{
    @synchronized (self) {
        _sentBytes += numberOfBytes;

        dispatch_async(self.groupQueue, ^{
            [self.delegate peer:self didSendNumberOfBytes:numberOfBytes];
        });
    }
}

- (void)didReceiveNumberOfBytes:(NSUInteger)numberOfBytes
{
    @synchronized (self) {
        _receivedBytes += numberOfBytes;

        dispatch_async(self.groupQueue, ^{
            [self.delegate peer:self didReceiveNumberOfBytes:numberOfBytes];
        });
    }
}

#pragma mark Testing

- (id<WSMessage>)dequeueMessageSynchronouslyWithTimeout:(NSUInteger)timeout
{
#ifdef WASPV_TEST_MESSAGE_QUEUE
    id<WSMessage> message = nil;

    [self.messageQueueCondition lock];
    if (self.messageQueue.count == 0) {
        [self.messageQueueCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeout]];
    }
    if (self.messageQueue.count > 0) {
        message = [self.messageQueue objectAtIndex:0];
        [self.messageQueue removeObjectAtIndex:0];
    }
    [self.messageQueueCondition unlock];

    return message;
#else
    return nil;
#endif
}

@end

#pragma mark -

@implementation WSConnectionPool (Peer)

- (BOOL)openConnectionToPeer:(WSPeer *)peer
{
    return [self openConnectionToHost:peer.remoteHost port:peer.remotePort processor:peer];
}

- (WSPeer *)openConnectionToPeerHost:(NSString *)peerHost parameters:(id<WSParameters>)parameters
{
    WSPeer *peer = [[WSPeer alloc] initWithHost:peerHost parameters:parameters];
    if (![self openConnectionToHost:peer.remoteHost port:peer.remotePort processor:peer]) {
        return nil;
    }
    return peer;
}

@end
