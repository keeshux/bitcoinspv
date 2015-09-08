//
//  WSBlockChainDownloader.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 24/08/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
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

#import "WSBlockChainDownloader.h"
#import "WSPeerGroup+Download.h"
#import "WSBlockStore.h"
#import "WSBlockChain.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSStorableBlock.h"
#import "WSWallet.h"
#import "WSHDWallet.h"
#import "WSConnectionPool.h"
#import "WSBlockLocator.h"
#import "WSParameters.h"
#import "WSHash256.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "WSConfig.h"

@interface WSBlockChainDownloader ()

// configuration
@property (nonatomic, strong) id<WSBlockStore> store;
@property (nonatomic, strong) WSBlockChain *blockChain;
@property (nonatomic, strong) id<WSSynchronizableWallet> wallet;
@property (nonatomic, assign) uint32_t fastCatchUpTimestamp;
@property (nonatomic, assign) BOOL shouldDownloadBlocks;
@property (nonatomic, strong) WSBIP37FilterParameters *bloomFilterParameters;

// state
@property (nonatomic, weak) WSPeerGroup *peerGroup;
@property (nonatomic, strong) WSPeer *downloadPeer;
@property (nonatomic, strong) WSBloomFilter *bloomFilter;
@property (nonatomic, strong) NSCountedSet *pendingBlockIds;
@property (nonatomic, strong) NSMutableOrderedSet *processingBlockIds;
@property (nonatomic, assign) NSUInteger filteredBlockCount;
@property (nonatomic, strong) WSBlockLocator *startingBlockChainLocator;
@property (nonatomic, assign) NSTimeInterval lastKeepAliveTime;

// business
- (WSPeer *)bestPeerAmongPeers:(NSArray *)peers; // WSPeer
- (void)downloadBlockChain;
- (void)rebuildBloomFilter;
- (void)requestHeadersWithLocator:(WSBlockLocator *)locator;
- (void)requestBlocksWithLocator:(WSBlockLocator *)locator;
- (void)aheadRequestOnReceivedHeaders:(NSArray *)headers; // WSBlockHeader
- (void)aheadRequestOnReceivedBlockHashes:(NSArray *)hashes; // WSHash256
- (void)trySaveBlockChainToCoreData;
- (void)detectDownloadTimeout;

// blockchain
- (BOOL)appendBlockHeaders:(NSArray *)headers error:(NSError **)error; // WSBlockHeader
- (BOOL)appendBlock:(WSBlock *)block error:(NSError **)error;
- (BOOL)appendFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions error:(NSError **)error; // WSSignedTransaction

// entity handlers
- (void)handleAddedBlock:(WSStorableBlock *)block;
- (void)handleReplacedBlock:(WSStorableBlock *)block;
- (void)handleReceivedTransaction:(WSSignedTransaction *)transaction;
- (void)handleReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks;
- (void)recoverMissedBlockTransactions:(WSStorableBlock *)block;
- (BOOL)maybeRebuildAndSendBloomFilter;

@end

@implementation WSBlockChainDownloader

- (instancetype)init
{
    if ((self = [super init])) {
        self.bloomFilterRateMin = WSBlockChainDownloaderDefaultBFRateMin;
        self.bloomFilterRateDelta = WSBlockChainDownloaderDefaultBFRateDelta;
        self.bloomFilterObservedRateMax = WSBlockChainDownloaderDefaultBFObservedRateMax;
        self.bloomFilterLowPassRatio = WSBlockChainDownloaderDefaultBFLowPassRatio;
        self.bloomFilterTxsPerBlock = WSBlockChainDownloaderDefaultBFTxsPerBlock;
        self.blockStoreSize = WSBlockChainDownloaderDefaultBlockStoreSize;
        self.requestTimeout = WSBlockChainDownloaderDefaultRequestTimeout;
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store headersOnly:(BOOL)headersOnly
{
    if (!headersOnly) {
        WSExceptionRaiseUnsupported(@"Full blocks download not yet implemented");
    }
    
    if ((self = [self init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = nil;
        self.fastCatchUpTimestamp = 0;

        self.shouldDownloadBlocks = !headersOnly;
        self.bloomFilterParameters = nil;
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    WSExceptionRaiseUnsupported(@"Full blocks download not yet implemented");

    if ((self = [self init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = nil;
        self.fastCatchUpTimestamp = fastCatchUpTimestamp;

        self.shouldDownloadBlocks = YES;
        self.bloomFilterParameters = nil;
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet
{
    if ((self = [self init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = wallet;
        self.fastCatchUpTimestamp = [self.wallet earliestKeyTimestamp];

        self.shouldDownloadBlocks = YES;
        self.bloomFilterParameters = [[WSBIP37FilterParameters alloc] init];
#if BSPV_WALLET_FILTER == BSPV_WALLET_FILTER_UNSPENT
        self.bloomFilterParameters.flags = WSBIP37FlagsUpdateAll;
#endif
    }
    return self;
}

- (id<WSParameters>)parameters
{
    return [self.store parameters];
}

- (BOOL)needsBloomFiltering
{
    return (self.bloomFilterParameters != nil);
}

#pragma mark WSPeerGroupDownloadDelegate

- (void)peerGroupDidStartDownload:(WSPeerGroup *)peerGroup
{
    self.peerGroup = peerGroup;
    self.downloadPeer = [self bestPeerAmongPeers:[peerGroup allConnectedPeers]];
    if (!self.downloadPeer) {
        DDLogInfo(@"Delayed download until peer selection");
        return;
    }
    DDLogInfo(@"Peer %@ is new download peer", self.downloadPeer);

    [self downloadBlockChain];
}

- (void)peerGroupDidStopDownload:(WSPeerGroup *)peerGroup
{
    [self trySaveBlockChainToCoreData];
    
    if (self.downloadPeer) {
        DDLogInfo(@"Download from peer %@ is being stopped", self.downloadPeer);

        [peerGroup disconnectPeer:self.downloadPeer error:WSErrorMake(WSErrorCodePeerGroupStop, @"Download stopped")];
    }
    self.downloadPeer = nil;
    self.peerGroup = nil;
}

- (void)peerGroupShouldPersistDownloadState:(WSPeerGroup *)peerGroup
{
    [self trySaveBlockChainToCoreData];
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peerDidConnect:(WSPeer *)peer
{
    if (!self.downloadPeer) {
        self.downloadPeer = peer;
        DDLogInfo(@"Peer %@ connected, is new download peer", self.downloadPeer);

        [self downloadBlockChain];
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didDisconnectWithError:(NSError *)error
{
    if (peer != self.downloadPeer) {
        return;
    }

    DDLogDebug(@"Peer %@ disconnected, was download peer", peer);

    self.downloadPeer = [self bestPeerAmongPeers:[peerGroup allConnectedPeers]];
    if (!self.downloadPeer) {
        DDLogError(@"No more peers for download (%@)", error);
        return;
    }
    DDLogDebug(@"Switched to next best download peer %@", self.downloadPeer);

    [self downloadBlockChain];
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peerDidKeepAlive:(WSPeer *)peer
{
    if (peer != self.downloadPeer) {
        return;
    }
    
    self.lastKeepAliveTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveHeaders:(NSArray *)headers
{
    if (peer != self.downloadPeer) {
        return;
    }

    [self aheadRequestOnReceivedHeaders:headers];

    NSError *error;
    if (![self appendBlockHeaders:headers error:&error]) {
        [peerGroup reportMisbehavingPeer:self.downloadPeer error:error];
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveInventories:(NSArray *)inventories
{
    if (peer != self.downloadPeer) {
        return;
    }

    NSMutableArray *requestInventories = [[NSMutableArray alloc] initWithCapacity:inventories.count];
    NSMutableArray *requestBlockHashes = [[NSMutableArray alloc] initWithCapacity:inventories.count];
    
    for (WSInventory *inv in inventories) {
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
        [peer sendGetdataMessageWithInventories:requestInventories];
        
        if (requestBlockHashes.count > 0) {
            [self aheadRequestOnReceivedBlockHashes:requestBlockHashes];
        }
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveBlock:(WSBlock *)block
{
    if (peer != self.downloadPeer) {
        return;
    }

    NSError *error;
    if (![self appendBlock:block error:&error]) {
        [peerGroup reportMisbehavingPeer:self.downloadPeer error:error];
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions
{
    if (peer != self.downloadPeer) {
        return;
    }

    NSError *error;
    if (![self appendFilteredBlock:filteredBlock withTransactions:transactions error:&error]) {
        [peerGroup reportMisbehavingPeer:self.downloadPeer error:error];
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveTransaction:(WSSignedTransaction *)transaction
{
    if (peer != self.downloadPeer) {
        return;
    }

    [self handleReceivedTransaction:transaction];
}

- (BOOL)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer shouldAcceptHeader:(WSBlockHeader *)header error:(NSError *__autoreleasing *)error
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

#pragma mark Business

- (WSPeer *)bestPeerAmongPeers:(NSArray *)peers
{
    WSPeer *bestPeer = nil;
    for (WSPeer *peer in peers) {

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

- (void)downloadBlockChain
{
    if (self.wallet) {
        [self rebuildBloomFilter];

        DDLogDebug(@"Loading Bloom filter for download peer %@", self.downloadPeer);
        [self.downloadPeer sendFilterloadMessageWithFilter:self.bloomFilter];
    }
    else if (self.shouldDownloadBlocks) {
        DDLogDebug(@"No wallet provided, downloading full blocks");
    }
    else {
        DDLogDebug(@"No wallet provided, downloading block headers");
    }

    DDLogInfo(@"Preparing for blockchain download");

    if (self.blockChain.currentHeight >= self.downloadPeer.lastBlockHeight) {
#warning TODO: download, notifier
//        const NSUInteger height = self.blockChain.currentHeight;
//        [self.notifier notifyDownloadStartedFromHeight:height toHeight:height];
        
        DDLogInfo(@"Blockchain is up to date");
        
        [self trySaveBlockChainToCoreData];
        
#warning TODO: download, notifier
//        [self.notifier notifyDownloadFinished];
        return;
    }

    WSStorableBlock *checkpoint = [self.parameters lastCheckpointBeforeTimestamp:self.fastCatchUpTimestamp];
    if (checkpoint) {
        DDLogDebug(@"%@ Last checkpoint before catch-up: %@ (%@)",
                   self, checkpoint, [NSDate dateWithTimeIntervalSince1970:checkpoint.header.timestamp]);
        
        [self.blockChain addCheckpoint:checkpoint error:NULL];
    }
    else {
        DDLogDebug(@"%@ No fast catch-up checkpoint", self);
    }
    
#warning TODO: download, notifier
//    const NSUInteger fromHeight = self.blockChain.currentHeight;
//    const NSUInteger toHeight = self.downloadPeer.lastBlockHeight;
//    [self.notifier notifyDownloadStartedFromHeight:fromHeight toHeight:toHeight];
    
    self.fastCatchUpTimestamp = self.fastCatchUpTimestamp;
    self.startingBlockChainLocator = [self.blockChain currentLocator];
    self.lastKeepAliveTime = [NSDate timeIntervalSinceReferenceDate];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(detectDownloadTimeout) object:nil];
        [self performSelector:@selector(detectDownloadTimeout) withObject:nil afterDelay:self.requestTimeout];
    });
    
    if (!self.shouldDownloadBlocks || (self.blockChain.currentTimestamp < self.fastCatchUpTimestamp)) {
        [self requestHeadersWithLocator:self.startingBlockChainLocator];
    }
    else {
        [self requestBlocksWithLocator:self.startingBlockChainLocator];
    }
}

- (void)rebuildBloomFilter
{
    const NSTimeInterval rebuildStartTime = [NSDate timeIntervalSinceReferenceDate];
    self.bloomFilter = [self.wallet bloomFilterWithParameters:self.bloomFilterParameters];
    const NSTimeInterval rebuildTime = [NSDate timeIntervalSinceReferenceDate] - rebuildStartTime;
    
    DDLogDebug(@"Bloom filter rebuilt in %.3fs (false positive rate: %f)",
               rebuildTime, self.bloomFilterParameters.falsePositiveRate);
}

- (void)requestHeadersWithLocator:(WSBlockLocator *)locator
{
    NSParameterAssert(locator);

    DDLogDebug(@"%@ Behind catch-up (or headers-only mode), requesting headers with locator: %@", self, locator.hashes);
    [self.downloadPeer sendGetheadersMessageWithLocator:locator hashStop:nil];
}

- (void)requestBlocksWithLocator:(WSBlockLocator *)locator
{
    NSParameterAssert(locator);

    DDLogDebug(@"%@ Beyond catch-up (or full blocks mode), requesting block hashes with locator: %@", self, locator.hashes);
    [self.downloadPeer sendGetblocksMessageWithLocator:locator hashStop:nil];
}

- (void)aheadRequestOnReceivedHeaders:(NSArray *)headers
{
    NSParameterAssert(headers.count > 0);
    
//    const NSUInteger currentHeight = self.blockChain.currentHeight;
//
//    DDLogDebug(@"%@ Still behind (%u < %u), requesting more headers ahead of time",
//               self, currentHeight, self.lastBlockHeight);
    
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
//    NSAssert(lastHeaderBeforeFCU, @"No headers should have been requested beyond catch-up");
    
    if (self.shouldDownloadBlocks && !lastHeaderBeforeFCU) {
        DDLogInfo(@"%@ All received headers beyond catch-up, rerequesting blocks", self);
        
        [self requestBlocksWithLocator:self.startingBlockChainLocator];
    }
    else {
        // we won't cross fast catch-up, request more headers
        if (!self.shouldDownloadBlocks || (lastHeaderBeforeFCU == lastHeader)) {
            WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:@[lastHeader.blockId, firstHeader.blockId]];
            [self requestHeadersWithLocator:locator];
        }
        // we will cross fast catch-up, request blocks from crossing point
        else {
            DDLogInfo(@"%@ Last header before catch-up at block %@, timestamp %u (%@)",
                      self, lastHeaderBeforeFCU.blockId, lastHeaderBeforeFCU.timestamp,
                      [NSDate dateWithTimeIntervalSince1970:lastHeaderBeforeFCU.timestamp]);
            
            WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:@[lastHeaderBeforeFCU.blockId, firstHeader.blockId]];
            [self requestBlocksWithLocator:locator];
        }
    }
}

- (void)aheadRequestOnReceivedBlockHashes:(NSArray *)hashes
{
    NSParameterAssert(hashes.count > 0);
    
    if (hashes.count < WSMessageBlocksMaxCount) {
        return;
    }
    
//    const NSUInteger currentHeight = self.blockChain.currentHeight;
//
//    DDLogDebug(@"%@ Still behind (%u < %u), requesting more blocks ahead of time",
//               self, currentHeight, self.lastBlockHeight);
    
    WSHash256 *firstId = [hashes firstObject];
    WSHash256 *lastId = [hashes lastObject];
    
    WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:@[lastId, firstId]];
    [self requestBlocksWithLocator:locator];
}

- (void)trySaveBlockChainToCoreData
{
    if (self.coreDataManager) {
        [self.blockChain saveToCoreDataManager:self.coreDataManager];
    }
}

// main queue
- (void)detectDownloadTimeout
{
    [self.peerGroup executeBlockInGroupQueue:^{
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
            [self.peerGroup disconnectPeer:self.downloadPeer
                                     error:WSErrorMake(WSErrorCodePeerGroupTimeout, @"Download timed out, disconnecting")];
        }
    } synchronously:YES];
}

#pragma mark Blockchain

- (BOOL)appendBlockHeaders:(NSArray *)headers error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(headers.count > 0);
    
    for (WSBlockHeader *header in headers) {
        
        // download peer should stop requesting headers when fast catch-up reached
        if (self.shouldDownloadBlocks && (header.timestamp >= self.fastCatchUpTimestamp)) {
            break;
        }

        NSError *localError;
        WSStorableBlock *block = nil;
        __weak WSBlockChainDownloader *weakSelf = self;
        
        NSArray *connectedOrphans;
        block = [self.blockChain addBlockWithHeader:header reorganizeBlock:^(WSStorableBlock *base, NSArray *oldBlocks, NSArray *newBlocks) {
            
            [weakSelf handleReorganizeAtBase:base oldBlocks:oldBlocks newBlocks:newBlocks];
            
        } connectedOrphans:&connectedOrphans error:&localError];
        
        if (!block) {
            if (!localError) {
                DDLogDebug(@"Header not added: %@", header);
            }
            else {
                DDLogDebug(@"Error adding header (%@): %@", localError, header);
                
                if ((localError.domain == WSErrorDomain) && (localError.code == WSErrorCodeInvalidBlock)) {
                    if (error) {
                        *error = localError;
                    }
                }
            }
            DDLogDebug(@"Current head: %@", self.blockChain.head);
            
            return NO;
        }
        
        for (WSStorableBlock *addedBlock in [connectedOrphans arrayByAddingObject:block]) {
            [self handleAddedBlock:addedBlock];
        }
    }

    return YES;
}

- (BOOL)appendBlock:(WSBlock *)block error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(block);

#warning FIXME: handle full blocks, blockchain not extending in full blocks mode

    // a dummy "return NO" here would case download peer to be
    // disconnected as misbehaving each time a block is appended.
    // the problem is that the peer would seem to disconnect
    // "intentionally" because no disconnection error is specified

    return YES;
}

- (BOOL)appendFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(filteredBlock);
    NSParameterAssert(transactions);

    NSError *localError;
    WSStorableBlock *block = nil;
    WSStorableBlock *previousHead = nil;
    __weak WSBlockChainDownloader *weakSelf = self;
    
    NSArray *connectedOrphans;
    previousHead = self.blockChain.head;
    block = [self.blockChain addBlockWithHeader:filteredBlock.header transactions:transactions reorganizeBlock:^(WSStorableBlock *base, NSArray *oldBlocks, NSArray *newBlocks) {
        
        [weakSelf handleReorganizeAtBase:base oldBlocks:oldBlocks newBlocks:newBlocks];
        
    } connectedOrphans:&connectedOrphans error:&localError];
    
    if (!block) {
        if (!localError) {
            DDLogDebug(@"Filtered block not added: %@", filteredBlock);
        }
        else {
            DDLogDebug(@"Error adding filtered block (%@): %@", localError, filteredBlock);
            
            if ((localError.domain == WSErrorDomain) && (localError.code == WSErrorCodeInvalidBlock)) {
                if (error) {
                    *error = localError;
                }
            }
        }
        DDLogDebug(@"Current head: %@", self.blockChain.head);
        
        return NO;
    }
    
    for (WSStorableBlock *addedBlock in [connectedOrphans arrayByAddingObject:block]) {
        if (![addedBlock.blockId isEqual:previousHead.blockId]) {
            [self handleAddedBlock:addedBlock];
        }
        else {
            [self handleReplacedBlock:addedBlock];
        }
    }
    
    return YES;
}

#pragma mark Entity handlers

- (void)handleAddedBlock:(WSStorableBlock *)block
{
#warning TODO: download, notifier
//    [self.notifier notifyBlockAdded:block];
    
    const NSUInteger lastBlockHeight = self.downloadPeer.lastBlockHeight;
    const BOOL isDownloadFinished = (block.height == lastBlockHeight);
    
    if (isDownloadFinished) {
        for (WSPeer *peer in [self.peerGroup allConnectedPeers]) {
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
#warning TODO: download, notifier
//        [self.notifier notifyDownloadFinished];
    }
    
    //
    
    if (self.wallet) {
        [self recoverMissedBlockTransactions:block];
    }
}

- (void)handleReplacedBlock:(WSStorableBlock *)block
{
    if (self.wallet) {
        [self recoverMissedBlockTransactions:block];
    }
}

- (void)handleReceivedTransaction:(WSSignedTransaction *)transaction
{
#warning TODO: download, notifier
//    const BOOL isPublished = [self findAndRemovePublishedTransaction:transaction];
//    [self.notifier notifyTransaction:transaction fromPeer:peer isPublished:isPublished];
    
    //
    
    BOOL didGenerateNewAddresses = NO;
    if (self.wallet && ![self.wallet registerTransaction:transaction didGenerateNewAddresses:&didGenerateNewAddresses]) {
        return;
    }
    
    if (didGenerateNewAddresses) {
        DDLogDebug(@"Last transaction triggered new addresses generation");
        
        if ([self maybeRebuildAndSendBloomFilter]) {
#warning FIXME: download, outdated blocks
//            [peer requestOutdatedBlocks];
        }
    }
}

- (void)handleReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks
{
    DDLogDebug(@"Reorganized blockchain at block: %@", base);
    DDLogDebug(@"Reorganize, old blocks: %@", oldBlocks);
    DDLogDebug(@"Reorganize, new blocks: %@", newBlocks);
    
#warning TODO: download, notifier
//    for (WSStorableBlock *block in newBlocks) {
//        for (WSSignedTransaction *transaction in block.transactions) {
//            const BOOL isPublished = [self findAndRemovePublishedTransaction:transaction];
//            [self.notifier notifyTransaction:transaction fromPeer:peer isPublished:isPublished];
//        }
//    }
    
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
        
        if ([self maybeRebuildAndSendBloomFilter]) {
#warning FIXME: download, outdated blocks
//            [peer requestOutdatedBlocks];
        }
    }
}

- (void)recoverMissedBlockTransactions:(WSStorableBlock *)block
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

        if ([self maybeRebuildAndSendBloomFilter]) {
#warning FIXME: download, outdated blocks
//            [peer requestOutdatedBlocks];
        }
    }
}

- (BOOL)maybeRebuildAndSendBloomFilter
{
    if (![self needsBloomFiltering]) {
        return NO;
    }
    
    DDLogDebug(@"Bloom filter may be outdated (height: %u, receive: %u, change: %u)",
               self.blockChain.currentHeight, self.wallet.allReceiveAddresses.count, self.wallet.allChangeAddresses.count);
    
    if ([self.wallet isCoveredByBloomFilter:self.bloomFilter]) {
        DDLogDebug(@"Wallet is still covered by current Bloom filter, not rebuilding");
        return NO;
    }
    
    DDLogDebug(@"Wallet is not covered by current Bloom filter anymore, rebuilding now");
    
    if ([self.wallet isKindOfClass:[WSHDWallet class]]) {
        WSHDWallet *hdWallet = (WSHDWallet *)self.wallet;
        
        DDLogDebug(@"HD wallet: generating %u look-ahead addresses", hdWallet.gapLimit);
        [hdWallet generateAddressesWithLookAhead:hdWallet.gapLimit];
        DDLogDebug(@"HD wallet: receive: %u, change: %u)", hdWallet.allReceiveAddresses.count, hdWallet.allChangeAddresses.count);
    }
    
    [self rebuildBloomFilter];
    
    if ([self needsBloomFiltering]) {
        if (self.blockChain.currentHeight < self.downloadPeer.lastBlockHeight) {
            DDLogDebug(@"Still syncing, loading rebuilt Bloom filter only for download peer %@", self.downloadPeer);
            [self.downloadPeer sendFilterloadMessageWithFilter:self.bloomFilter];
        }
        else {
            for (WSPeer *peer in [self.peerGroup allConnectedPeers]) {
                DDLogDebug(@"Synced, loading rebuilt Bloom filter for peer %@", peer);
                [peer sendFilterloadMessageWithFilter:self.bloomFilter];
            }
        }
    }
    
    return YES;
}

@end
