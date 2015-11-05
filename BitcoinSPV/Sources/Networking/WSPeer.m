//
//  WSPeer.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 13/06/14.
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

#import "WSPeer.h"
#import "WSProtocolDeserializer.h"
#import "WSNetworkAddress.h"
#import "WSBlock.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSStorableBlock.h"
#import "WSBlockChain.h"
#import "WSBlockLocator.h"
#import "WSInventory.h"
#import "WSTransaction.h"
#import "WSConfig.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "NSData+Binary.h"

@interface WSPeerFlags ()

@property (nonatomic, assign) BOOL needsBloomFiltering;

@end

@implementation WSPeerFlags

- (instancetype)initWithNeedsBloomFiltering:(BOOL)needsBloomFiltering
{
    if ((self = [super init])) {
        self.needsBloomFiltering = needsBloomFiltering;
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
    uint32_t _remoteAddress;
    uint16_t _remotePort;
    uint64_t _remoteServices;
    uint64_t _nonce;
    NSTimeInterval _connectionStartTime;
    NSTimeInterval _connectionTime;
    NSTimeInterval _lastSeenTimestamp;
    WSMessageVersion *_receivedVersion;
}

// set on creation
@property (nonatomic, strong) WSParameters *parameters;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, assign) BOOL shouldDownloadBlocks;
@property (nonatomic, assign) BOOL needsBloomFiltering;

// set on [WSConnectionProcessor openedConnectionToHost:port:handler:]
@property (nonatomic, strong) id<WSConnectionHandler> handler;

// stateful messages
@property (nonatomic, strong) WSFilteredBlock *currentFilteredBlock;
@property (nonatomic, strong) NSMutableOrderedSet *currentFilteredTransactions;

// protocol
- (void)sendVersionMessageWithRelayTransactions:(uint8_t)relayTransactions;
- (void)sendVerackMessage;
- (void)sendPongMessageWithNonce:(uint64_t)nonce;
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

// stateful messages
- (void)beginFilteredBlock:(WSFilteredBlock *)filteredBlock;
- (BOOL)addTransactionToCurrentFilteredBlock:(WSSignedTransaction *)transaction outdated:(BOOL *)outdated;
- (void)endCurrentFilteredBlock;

// helpers
- (void)unsafeSendMessage:(id<WSMessage>)message;
- (void)safelyDelegateBlock:(void (^)())block;
- (BOOL)tryFinishHandshake;

#ifdef BSPV_TEST_MESSAGE_QUEUE
@property (nonatomic, strong) NSCondition *messageQueueCondition;
@property (nonatomic, strong) NSMutableArray *messageQueue;
#endif

@end

@implementation WSPeer

- (instancetype)initWithHost:(NSString *)host parameters:(WSParameters *)parameters flags:(WSPeerFlags *)flags
{
    WSExceptionCheckIllegal(host);
    WSExceptionCheckIllegal(flags);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        self.needsBloomFiltering = flags.needsBloomFiltering;
        self.delegateQueue = dispatch_get_main_queue();

        _peerStatus = WSPeerStatusDisconnected;
        _remoteHost = host;
        _remoteAddress = WSNetworkIPv4FromHost(_remoteHost);
        _remotePort = [self.parameters peerPort];

        self.identifier = [NSString stringWithFormat:@"(%@:%u)", _remoteHost, _remotePort];

#ifdef BSPV_TEST_MESSAGE_QUEUE
        self.messageQueueCondition = [[NSCondition alloc] init];
        self.messageQueue = [[NSMutableArray alloc] init];
#endif
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
    return ((peer.remoteAddress == _remoteAddress) && (peer.remotePort == _remotePort));
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

    const uint32_t remoteAddress = self.remoteAddress;
    uint32_t hash = offset;
    hash = (hash ^ ((remoteAddress >> 24) & 0xff)) * prime;
    hash = (hash ^ ((remoteAddress >> 16) & 0xff)) * prime;
    hash = (hash ^ ((remoteAddress >> 8) & 0xff)) * prime;
    hash = (hash ^ (remoteAddress & 0xff)) * prime;
    hash = (hash ^ ((self.remotePort >> 8) & 0xff)) * prime;
    hash = (hash ^ (self.remotePort & 0xff)) * prime;
    return hash;
}

- (NSString *)description
{
    return self.identifier;
}

#pragma mark WSConnectionProcessor (handler queue)

- (void)openedConnectionToHost:(NSString *)host port:(uint16_t)port handler:(id<WSConnectionHandler>)handler
{
    NSAssert([host isEqualToString:self.remoteHost], @"Connected host differs from remoteHost");
    NSAssert(port == self.remotePort, @"Connected port differs from remotePort");

    @synchronized (self) {
        self.handler = handler;

        _peerStatus = WSPeerStatusConnecting;
        _didReceiveVerack = NO;
        _didSendVerack = NO;
        _remoteServices = 0;
        _nonce = arc4random();
        _connectionStartTime = DBL_MAX;
        _connectionTime = DBL_MAX;
        _lastSeenTimestamp = NSTimeIntervalSince1970;
        _receivedVersion = nil;
    }

    DDLogDebug(@"%@ Connection opened", self);

    [self sendVersionMessageWithRelayTransactions:(uint8_t)!self.needsBloomFiltering];
}

- (void)processMessage:(id<WSMessage>)message
{
    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceiveNumberOfBytes:message.length];
        [self.delegate peerDidKeepAlive:self];
    }];
    
    [self.handler submitBlock:^{
        if (message.originalLength < 1024) {
            DDLogVerbose(@"%@ Received %@ (%lu+%lu bytes)",
                         self, message, (unsigned long)WSMessageHeaderLength, (unsigned long)message.originalLength);
        }
        else {
            DDLogVerbose(@"%@ Received %@ (%lu+%lu bytes, too long to display)",
                         self, [message class], (unsigned long)WSMessageHeaderLength, (unsigned long)message.originalLength);
        }
        
        // stop reading txs for current merkleblock
        if (self.currentFilteredBlock && ![message isKindOfClass:[WSMessageTx class]]) {
            [self endCurrentFilteredBlock];
        }

        SEL selector = NSSelectorFromString([NSString stringWithFormat:@"receive%@Message:", [message.messageType capitalizedString]]);
        if ([self respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            
            [self performSelector:selector withObject:message];
            
#pragma clang diagnostic pop
        }
        else {
            DDLogDebug(@"%@ Unhandled message '%@'", self, message.messageType);
        }
        
#ifdef BSPV_TEST_MESSAGE_QUEUE
        [self.messageQueueCondition lock];
        [self.messageQueue addObject:message];
        [self.messageQueueCondition signal];
        [self.messageQueueCondition unlock];
#endif
    }];
}

- (void)closedConnectionWithError:(NSError *)error
{
    DDLogDebug(@"%@ Connection closed%@", self, WSStringOptional(error, @" (%@)"));

    BOOL wasConnected = NO;
    
    @synchronized (self) {
        wasConnected = (_peerStatus == WSPeerStatusConnected);
        _peerStatus = WSPeerStatusDisconnected;
    }

    [self safelyDelegateBlock:^{
        if (wasConnected) {
            [self.delegate peer:self didDisconnectWithError:error];
        }
        else {
            [self.delegate peer:self didFailToConnectWithError:error];
        }
    }];
}

#pragma mark State

- (WSPeerStatus)peerStatus
{
    @synchronized (self) {
        return _peerStatus;
    }
}

- (NSString *)remoteHost
{
    return _remoteHost;
}

- (uint32_t)remoteAddress
{
    return _remoteAddress;
}

- (uint16_t)remotePort
{
    return _remotePort;
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

- (uint32_t)version
{
    @synchronized (self) {
        return self.receivedVersion.version;
    }
}

- (uint64_t)services
{
    @synchronized (self) {
        return self.receivedVersion.services;
    }
}

- (uint64_t)timestamp
{
    @synchronized (self) {
        return self.receivedVersion.timestamp;
    }
}

- (NSString *)userAgent
{
    @synchronized (self) {
        return self.receivedVersion.userAgent;
    }
}

- (uint32_t)lastBlockHeight
{
    @synchronized (self) {
        return self.receivedVersion.lastBlockHeight;
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
//- (void)cleanUpConnectionData
//{
//    self.delegate = nil;
//
//    self.remoteHost = nil;
//    self.remotePort = 0;
//    self.remoteServices = 0;
//    self.nonce = 0;
//    self.pingTime = DBL_MAX;
//    self.lastSeenTimestamp = NSTimeIntervalSince1970;
//    self.receivedVersion = nil;
//}

#pragma mark Protocol: send* (any queue)

// private
- (void)sendVersionMessageWithRelayTransactions:(uint8_t)relayTransactions
{
    [self.handler submitBlock:^{
        WSNetworkAddress *networkAddress = [[WSNetworkAddress alloc] initWithTimestamp:0 services:_remoteServices ipv4Address:_remoteAddress port:_remotePort];
        WSMessageVersion *message = [WSMessageVersion messageWithParameters:self.parameters
                                                                    version:WSPeerProtocol
                                                                   services:WSPeerEnabledServices
                                                       remoteNetworkAddress:networkAddress
                                                                  localPort:[self.parameters peerPort]
                                                          relayTransactions:relayTransactions];
        
        _nonce = message.nonce;
        _connectionStartTime = [NSDate timeIntervalSinceReferenceDate];
        
        [self unsafeSendMessage:message];
    }];
}

// private
- (void)sendVerackMessage
{
    [self.handler submitBlock:^{
        if (_didSendVerack) {
            DDLogWarn(@"%@ Unexpected 'verack' sending", self);
            return;
        }
        
        [self unsafeSendMessage:[WSMessageVerack messageWithParameters:self.parameters]];
        _didSendVerack = YES;

        [self tryFinishHandshake];
    }];
}

- (void)sendInvMessageWithInventory:(WSInventory *)inventory
{
    WSExceptionCheckIllegal(inventory);
    
    [self sendInvMessageWithInventories:@[inventory]];
}

- (void)sendInvMessageWithInventories:(NSArray *)inventories
{
    WSExceptionCheckIllegal(inventories.count > 0);

    [self.handler submitBlock:^{
        [self unsafeSendMessage:[WSMessageInv messageWithParameters:self.parameters inventories:inventories]];
    }];
}

- (void)sendGetdataMessageWithHashes:(NSArray *)hashes forInventoryType:(WSInventoryType)inventoryType
{
    WSExceptionCheckIllegal(hashes.count > 0);

    NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:hashes.count];
    for (WSHash256 *hash in hashes) {
        [inventories addObject:[[WSInventory alloc] initWithType:inventoryType hash:hash]];
    }
    [self sendGetdataMessageWithInventories:inventories];
}

- (void)sendGetdataMessageWithInventories:(NSArray *)inventories
{
    WSExceptionCheckIllegal(inventories.count > 0);

    [self.handler submitBlock:^{
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

        [self unsafeSendMessage:[WSMessageGetdata messageWithParameters:self.parameters inventories:inventories]];
        if (willRequestFilteredBlocks) {
            [self unsafeSendMessage:[WSMessagePing messageWithParameters:self.parameters]];
        }
    }];
}

- (void)sendNotfoundMessageWithInventories:(NSArray *)inventories
{
    WSExceptionCheckIllegal(inventories.count > 0);

    [self.handler submitBlock:^{
        [self unsafeSendMessage:[WSMessageNotfound messageWithParameters:self.parameters inventories:inventories]];
    }];
}

- (void)sendGetblocksMessageWithLocator:(WSBlockLocator *)locator hashStop:(WSHash256 *)hashStop
{
    WSExceptionCheckIllegal(locator);
    
    [self.handler submitBlock:^{
        [self unsafeSendMessage:[WSMessageGetblocks messageWithParameters:self.parameters version:WSPeerProtocol locator:locator hashStop:hashStop]];
    }];
}

- (void)sendGetheadersMessageWithLocator:(WSBlockLocator *)locator hashStop:(WSHash256 *)hashStop
{
    WSExceptionCheckIllegal(locator);
    
    [self.handler submitBlock:^{
        [self unsafeSendMessage:[WSMessageGetheaders messageWithParameters:self.parameters version:WSPeerProtocol locator:locator hashStop:hashStop]];
    }];
}

- (void)sendTxMessageWithTransaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction);

    [self.handler submitBlock:^{
        [self unsafeSendMessage:[WSMessageTx messageWithParameters:self.parameters transaction:transaction]];
    }];
}

- (void)sendGetaddr
{
    [self.handler submitBlock:^{
        [self unsafeSendMessage:[WSMessageGetaddr messageWithParameters:self.parameters]];
    }];
}

- (void)sendMempoolMessage
{
    [self.handler submitBlock:^{
        [self unsafeSendMessage:[WSMessageMempool messageWithParameters:self.parameters]];
    }];
}

- (void)sendPingMessage
{
    [self.handler submitBlock:^{
        NSAssert(_nonce, @"Nonce not set, is handshake complete?");

        [self unsafeSendMessage:[WSMessagePing messageWithParameters:self.parameters]];
    }];
}

- (void)sendPongMessageWithNonce:(uint64_t)nonce
{
    [self.handler submitBlock:^{
        [self unsafeSendMessage:[WSMessagePong messageWithParameters:self.parameters nonce:nonce]];
    }];
}

- (void)sendFilterloadMessageWithFilter:(WSBloomFilter *)filter
{
    WSExceptionCheckIllegal(filter);

    [self.handler submitBlock:^{
        [self unsafeSendMessage:[WSMessageFilterload messageWithParameters:self.parameters filter:filter]];
    }];
}

#pragma mark Protocol: receive* (connection queue)

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
    @synchronized (self) {
        _receivedVersion = message;
    }

    [self sendVerackMessage];
    [self tryFinishHandshake];
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
        DDLogDebug(@"%@ Got 'verack' in %.3fs", self, _connectionTime);
    }
    
    [self tryFinishHandshake];
}

- (void)receiveAddrMessage:(WSMessageAddr *)message
{
    DDLogDebug(@"%@ Received %lu addresses", self, (unsigned long)message.addresses.count);
    
    const BOOL isLastRelay = ((message.addresses.count > 1) && (message.addresses.count < WSMessageAddrMaxCount));

    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceiveAddresses:message.addresses isLastRelay:isLastRelay];
    }];
}

- (void)receiveInvMessage:(WSMessageInv *)message
{
    NSArray *inventories = message.inventories;
    if (inventories.count == 0) {
        DDLogWarn(@"%@ Received empty inventories", self);
        return;
    }
 
    const NSUInteger count = message.inventories.count;
    if (count < 10) {
        DDLogDebug(@"%@ Received %lu inventories: %@", self, (unsigned long)count, message.inventories);
    }
    else {
        DDLogDebug(@"%@ Received %lu inventories", self, (unsigned long)count);
    }

    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceiveInventories:inventories];
    }];
}

- (void)receiveGetdataMessage:(WSMessageGetdata *)message
{
    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceiveDataRequestWithInventories:message.inventories];
    }];
}

- (void)receiveNotfoundMessage:(WSMessageNotfound *)message
{
    DDLogDebug(@"%@ Got 'notfound' with %lu items", self, (unsigned long)message.inventories.count);
}

- (void)receiveTxMessage:(WSMessageTx *)message
{
    WSSignedTransaction *transaction = message.transaction;

    BOOL outdated = NO;
    if (![self addTransactionToCurrentFilteredBlock:transaction outdated:&outdated] && outdated) {
        return;
    }
    
    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceiveTransaction:transaction];
    }];
}

- (void)receiveBlockMessage:(WSMessageBlock *)message
{
    WSBlock *block = message.block;

    NSError *error;
    if (![block.header verifyWithError:&error]) {
        [self.handler disconnectWithError:error];
        return;
    }
    
    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceiveBlock:block];
    }];
}

- (void)receiveHeadersMessage:(WSMessageHeaders *)message
{
    NSArray *headers = message.headers;
    if (headers.count == 0) {
        DDLogWarn(@"%@ Received empty headers", self);
        return;
    }
    
    for (WSBlockHeader *header in message.headers) {
        NSError *error;
        if (![header verifyWithError:&error]) {
            [self.handler disconnectWithError:error];
            return;
        }
    }

    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceiveHeaders:headers];
    }];
}

- (void)receivePingMessage:(WSMessagePing *)message
{
    [self sendPongMessageWithNonce:message.nonce];
}

- (void)receivePongMessage:(WSMessagePong *)message
{
    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceivePongMesage:message];
    }];
}

- (void)receiveMerkleblockMessage:(WSMessageMerkleblock *)message
{
    NSError *error;
    if (![message.block.header verifyWithError:&error]) {
        [self.handler disconnectWithError:error];
        return;
    }

    [self beginFilteredBlock:message.block];
}

- (void)receiveRejectMessage:(WSMessageReject *)message
{
    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceiveRejectMessage:message];
    }];
}

#pragma mark Complex messages

- (void)beginFilteredBlock:(WSFilteredBlock *)filteredBlock
{
    NSParameterAssert(filteredBlock);

    self.currentFilteredBlock = filteredBlock;
    self.currentFilteredTransactions = [[NSMutableOrderedSet alloc] init];
}

- (BOOL)addTransactionToCurrentFilteredBlock:(WSSignedTransaction *)transaction outdated:(BOOL *)outdated
{
    NSParameterAssert(transaction);
    NSParameterAssert(outdated);
    
    if (!self.currentFilteredBlock) {
        DDLogDebug(@"%@ Transaction %@ outside filtered block", self, transaction.txId);
        return NO;
    }
    
    if (self.delegate && ![self.delegate peer:self shouldAddTransaction:transaction toFilteredBlock:self.currentFilteredBlock]) {
        return NO;
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

- (void)endCurrentFilteredBlock
{
    WSFilteredBlock *filteredBlock = self.currentFilteredBlock;
    NSOrderedSet *transactions = self.currentFilteredTransactions;
    NSAssert(filteredBlock && transactions, @"Nil filteredBlock or transactions");

    self.currentFilteredBlock = nil;
    self.currentFilteredTransactions = nil;
    
    [self safelyDelegateBlock:^{
        [self.delegate peer:self didReceiveFilteredBlock:filteredBlock withTransactions:transactions];
    }];
}

#pragma mark Helpers

- (void)unsafeSendMessage:(id<WSMessage>)message
{
//    @synchronized (self) {
//        if (_peerStatus == WSPeerStatusDisconnected) {
//            DDLogWarn(@"%@ Not connected", self);
//            return;
//        }
//    }

    [self.handler writeMessage:message];

    [self safelyDelegateBlock:^{
        [self.delegate peer:self didSendNumberOfBytes:message.length];
    }];
}

- (void)safelyDelegateBlock:(void (^)())block
{
    if (!self.delegate || !self.delegateQueue) {
        return;
    }
    dispatch_async(self.delegateQueue, block);
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

    [self safelyDelegateBlock:^{
        [self.delegate peerDidConnect:self];
    }];
    
    return YES;
}

#pragma mark Testing

- (id<WSMessage>)dequeueMessageSynchronouslyWithTimeout:(NSUInteger)timeout
{
#ifdef BSPV_TEST_MESSAGE_QUEUE
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

- (WSPeer *)openConnectionToPeerHost:(NSString *)peerHost parameters:(WSParameters *)parameters flags:(WSPeerFlags *)flags
{
    WSPeer *peer = [[WSPeer alloc] initWithHost:peerHost parameters:parameters flags:flags];
    if (![self openConnectionToHost:peer.remoteHost port:peer.remotePort processor:peer]) {
        return nil;
    }
    return peer;
}

@end
