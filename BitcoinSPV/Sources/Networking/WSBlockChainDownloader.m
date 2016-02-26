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
#import "WSBlock.h"
#import "WSFilteredBlock.h"
#import "WSTransaction.h"
#import "WSStorableBlock.h"
#import "WSStorableBlock+BlockChain.h"
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
@property (nonatomic, strong) WSParameters *parameters;
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
@property (nonatomic, strong) WSBlockLocator *startingBlockChainLocator;
@property (nonatomic, assign) NSTimeInterval lastKeepAliveTime;

- (instancetype)initWithParameters:(WSParameters *)parameters;

// business
- (BOOL)needsBloomFiltering;
- (WSPeer *)bestPeerAmongPeers:(NSArray *)peers; // WSPeer
- (void)downloadBlockChain;
- (void)rebuildBloomFilter;
- (void)requestHeadersWithLocator:(WSBlockLocator *)locator;
- (void)requestBlocksWithLocator:(WSBlockLocator *)locator;
- (void)aheadRequestOnReceivedHeaders:(NSArray *)headers; // WSBlockHeader
- (void)aheadRequestOnReceivedBlockHashes:(NSArray *)hashes; // WSHash256
- (void)requestOutdatedBlocks;
- (void)trySaveBlockChainToCoreData;
- (void)detectDownloadTimeout;

// blockchain
- (BOOL)appendBlockHeaders:(NSArray *)headers error:(NSError **)error; // WSBlockHeader
- (BOOL)appendBlock:(WSBlock *)fullBlock error:(NSError **)error;
- (BOOL)appendFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions error:(NSError **)error; // WSSignedTransaction
- (void)truncateBlockChainForRescan;

// entity handlers
- (void)handleAddedBlock:(WSStorableBlock *)block previousHead:(WSStorableBlock *)previousHead originalEntity:(id)entity;
- (void)handleReceivedTransaction:(WSSignedTransaction *)transaction;
- (void)handleReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks;
- (void)recoverMissedBlockTransactions:(WSStorableBlock *)block originalEntity:(id)entity;
- (BOOL)maybeRebuildAndSendBloomFilter;

// macros
- (void)logAddedBlock:(WSStorableBlock *)block location:(WSBlockChainLocation)location;
- (void)logRejectedEntity:(id)entity location:(WSBlockChainLocation)location error:(NSError *)error;
- (void)storeRelevantError:(NSError *)error intoError:(NSError **)outError;

@end

@implementation WSBlockChainDownloader

- (instancetype)initWithParameters:(WSParameters *)parameters
{
    NSParameterAssert(parameters);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        self.shouldAutoSaveWallet = YES;
        self.bloomFilterRateMin = WSBlockChainDownloaderDefaultBFRateMin;
        self.bloomFilterRateDelta = WSBlockChainDownloaderDefaultBFRateDelta;
        self.bloomFilterObservedRateMax = WSBlockChainDownloaderDefaultBFObservedRateMax;
        self.bloomFilterLowPassRatio = WSBlockChainDownloaderDefaultBFLowPassRatio;
        self.bloomFilterTxsPerBlock = WSBlockChainDownloaderDefaultBFTxsPerBlock;
        self.requestTimeout = WSBlockChainDownloaderDefaultRequestTimeout;

        self.pendingBlockIds = [[NSCountedSet alloc] init];
        self.processingBlockIds = [[NSMutableOrderedSet alloc] initWithCapacity:(2 * WSMessageBlocksMaxCount)];
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store headersOnly:(BOOL)headersOnly
{
    return [self initWithStore:store maxSize:WSBlockChainDefaultMaxSize headersOnly:headersOnly];
}

- (instancetype)initWithStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    return [self initWithStore:store maxSize:WSBlockChainDefaultMaxSize fastCatchUpTimestamp:fastCatchUpTimestamp];
}

- (instancetype)initWithStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet
{
    return [self initWithStore:store maxSize:WSBlockChainDefaultMaxSize wallet:wallet];
}

- (instancetype)initWithStore:(id<WSBlockStore>)store maxSize:(NSUInteger)maxSize headersOnly:(BOOL)headersOnly
{
    WSExceptionCheckIllegal(store);
    
    if ((self = [self initWithParameters:store.parameters])) {
        self.blockChain = [[WSBlockChain alloc] initWithStore:store maxSize:maxSize];
        self.wallet = nil;
        self.fastCatchUpTimestamp = 0;

        self.shouldDownloadBlocks = !headersOnly;
        self.bloomFilterParameters = nil;
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store maxSize:(NSUInteger)maxSize fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    WSExceptionCheckIllegal(store);

    if ((self = [self initWithParameters:store.parameters])) {
        self.blockChain = [[WSBlockChain alloc] initWithStore:store maxSize:maxSize];
        self.wallet = nil;
        self.fastCatchUpTimestamp = fastCatchUpTimestamp;

        self.shouldDownloadBlocks = YES;
        self.bloomFilterParameters = nil;
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store maxSize:(NSUInteger)maxSize wallet:(id<WSSynchronizableWallet>)wallet
{
    WSExceptionCheckIllegal(store);
    WSExceptionCheckIllegal(wallet);

    if ((self = [self initWithParameters:store.parameters])) {
        self.blockChain = [[WSBlockChain alloc] initWithStore:store maxSize:maxSize];
        self.wallet = wallet;
        self.fastCatchUpTimestamp = [self.wallet earliestKeyTimestamp];

        self.shouldDownloadBlocks = YES;
        self.bloomFilterParameters = [[WSBIP37FilterParameters alloc] init];
#if BSPV_WALLET_FILTER == BSPV_WALLET_FILTER_UNSPENT
        self.bloomFilterParameters.flags = WSBIP37FlagsUpdateAll;
#endif

        [self.wallet setShouldAutoSave:self.shouldAutoSaveWallet];
    }
    return self;
}

- (void)setCoreDataManager:(WSCoreDataManager *)coreDataManager
{
    _coreDataManager = coreDataManager;

    if (_coreDataManager) {
        [self.blockChain loadFromCoreDataManager:_coreDataManager];
    }
}

- (void)setShouldAutoSaveWallet:(BOOL)shouldAutoSaveWallet
{
    _shouldAutoSaveWallet = shouldAutoSaveWallet;
    
    [self.wallet setShouldAutoSave:_shouldAutoSaveWallet];
}

#pragma mark WSPeerGroupDownloader

- (void)startWithPeerGroup:(WSPeerGroup *)peerGroup
{
    WSExceptionCheckIllegal(peerGroup);
    
    self.peerGroup = peerGroup;
    self.downloadPeer = [self bestPeerAmongPeers:[peerGroup allConnectedPeers]];
    if (!self.downloadPeer) {
        DDLogInfo(@"Delayed download until peer selection");
        return;
    }
    DDLogInfo(@"Peer %@ is new download peer", self.downloadPeer);
    
    [self downloadBlockChain];
}

- (void)stop
{
    [self trySaveBlockChainToCoreData];
    
    if (self.downloadPeer) {
        DDLogInfo(@"Download from peer %@ is being stopped", self.downloadPeer);
        
        [self.peerGroup disconnectPeer:self.downloadPeer
                                 error:WSErrorMake(WSErrorCodePeerGroupStop, @"Download stopped")];
    }
    self.downloadPeer = nil;
    self.peerGroup = nil;
}

- (uint32_t)lastBlockHeight
{
    if (!self.downloadPeer) {
        return WSBlockUnknownHeight;
    }
    return self.downloadPeer.lastBlockHeight;
}

- (uint32_t)currentHeight
{
    return self.blockChain.currentHeight;
}

- (NSUInteger)numberOfBlocksLeft
{
    return (self.downloadPeer.lastBlockHeight - self.blockChain.currentHeight);
}

- (BOOL)isSynced
{
    return (self.blockChain.currentHeight >= self.downloadPeer.lastBlockHeight);
}

- (BOOL)isPeerDownloadPeer:(WSPeer *)peer
{
    return (peer == self.downloadPeer);
}

- (NSArray *)recentBlocksWithCount:(NSUInteger)count
{
    WSExceptionCheckIllegal(count > 0);

    NSMutableArray *recentBlocks = [[NSMutableArray alloc] initWithCapacity:count];
    WSStorableBlock *block = self.blockChain.head;
    while (block && (recentBlocks.count < count)) {
        [recentBlocks addObject:block];
        block = [block previousBlockInChain:self.blockChain];
    }
    return recentBlocks;
}

- (void)reconnectForDownload
{
    if (!self.downloadPeer) {
        return;
    }
    [self.peerGroup disconnectPeer:self.downloadPeer
                             error:WSErrorMake(WSErrorCodePeerGroupDownload, @"Rehashing download peer")];
}

- (void)rescanBlockChain
{
    if (!self.downloadPeer) {
        [self truncateBlockChainForRescan];
        return;
    }
    [self.peerGroup disconnectPeer:self.downloadPeer
                             error:WSErrorMake(WSErrorCodePeerGroupRescan, @"Preparing for rescan")];
}

- (void)saveState
{
    [self trySaveBlockChainToCoreData];
    if (self.shouldAutoSaveWallet) {
        [self.wallet save];
    }
}

#pragma mark WSPeerGroupDownloadDelegate

- (void)peerGroup:(WSPeerGroup *)peerGroup peerDidConnect:(WSPeer *)peer
{
    if (!self.downloadPeer) {
        self.downloadPeer = peer;
        DDLogInfo(@"Peer %@ connected, is new download peer", self.downloadPeer);

        [self downloadBlockChain];
    }
    // new peer is way ahead
    else if (peer.lastBlockHeight > self.downloadPeer.lastBlockHeight + 10) {
        DDLogInfo(@"Peer %@ connected, is way ahead of current download peer (%u >> %u)",
                  peer, peer.lastBlockHeight, self.downloadPeer.lastBlockHeight);
        
        [self.peerGroup disconnectPeer:self.downloadPeer
                                 error:WSErrorMake(WSErrorCodePeerGroupDownload, @"Found a better download peer")];
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didDisconnectWithError:(NSError *)error
{
    if (peer != self.downloadPeer) {
        return;
    }

    DDLogDebug(@"Peer %@ disconnected, was download peer", peer);

    [self.pendingBlockIds removeAllObjects];
    [self.processingBlockIds removeAllObjects];

    switch (error.code) {
        case WSErrorCodePeerGroupDownload: {
            break;
        }
        case WSErrorCodePeerGroupRescan: {
            [self truncateBlockChainForRescan];
            break;
        }
    }
    
    self.downloadPeer = [self bestPeerAmongPeers:[peerGroup allConnectedPeers]];
    if (!self.downloadPeer) {
//        if (!self.keepDownloading) {
//            [self.peerGroup.notifier notifyDownloadFailedWithError:WSErrorMake(WSErrorCodePeerGroupStop, @"Download stopped")];
//        }
//        else {
            [self.peerGroup.notifier notifyDownloadFailedWithError:WSErrorMake(WSErrorCodePeerGroupDownload, @"No more peers for download")];
//        }
        return;
    }

    [self.peerGroup.notifier notifyDownloadFailedWithError:error];

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
    if (![self appendBlockHeaders:headers error:&error] && error) {
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
    
#warning XXX: if !shouldDownloadBlocks, only download headers of new announced blocks
    
    // ignore blockchain tip inventory if already an orphan
    if (inventories.count == 1) {
        WSInventory *headInventory = [inventories lastObject];
        if ([self.blockChain isKnownOrphanBlockWithId:headInventory.inventoryHash]) {
            return;
        }
    }
    
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
        [self.pendingBlockIds addObjectsFromArray:requestBlockHashes];
        [self.processingBlockIds addObjectsFromArray:requestBlockHashes];
        
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
    if (![self appendBlock:block error:&error] && error) {
        [peerGroup reportMisbehavingPeer:self.downloadPeer error:error];
    }
}

- (BOOL)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer shouldAddTransaction:(WSSignedTransaction *)transaction toFilteredBlock:(WSFilteredBlock *)filteredBlock
{
    if (peer != self.downloadPeer) {
        return YES;
    }

    // only accept txs from most recently requested block
    WSHash256 *blockId = filteredBlock.header.blockId;
    if ([self.pendingBlockIds countForObject:blockId] > 1) {
        DDLogDebug(@"Drop transaction %@ from current filtered block %@ (outdated by new pending request)",
                   transaction.txId, blockId);
        
        return NO;
    }
    return YES;
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions
{
    if (peer != self.downloadPeer) {
        return;
    }

    WSHash256 *blockId = filteredBlock.header.blockId;

    [self.pendingBlockIds removeObject:blockId];
    if ([self.pendingBlockIds containsObject:blockId]) {
        DDLogDebug(@"Drop filtered block %@ (outdated by new pending request)", blockId);
        return;
    }
    
    [self.processingBlockIds removeObject:blockId];

    NSError *error;
    if (![self appendFilteredBlock:filteredBlock withTransactions:transactions error:&error] && error) {
        [peerGroup reportMisbehavingPeer:self.downloadPeer error:error];
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveTransaction:(WSSignedTransaction *)transaction
{
//    if (peer != self.downloadPeer) {
//        return;
//    }

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

- (BOOL)needsBloomFiltering
{
    return (self.bloomFilterParameters != nil);
}

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
        const uint32_t height = self.blockChain.currentHeight;
        [self.peerGroup.notifier notifyDownloadStartedFromHeight:height toHeight:height];
        
        DDLogInfo(@"Blockchain is up to date");
        
        [self trySaveBlockChainToCoreData];
        
        [self.peerGroup.notifier notifyDownloadFinished];
        return;
    }

    WSStorableBlock *checkpoint = [self.parameters lastCheckpointBeforeTimestamp:self.fastCatchUpTimestamp];
    if (checkpoint) {
        DDLogDebug(@"Last checkpoint before catch-up: %@ (%@)",
                   checkpoint, [NSDate dateWithTimeIntervalSince1970:checkpoint.header.timestamp]);
        
        if (![self.blockChain addCheckpoint:checkpoint error:NULL]) {
            DDLogDebug(@"Checkpoint discarded, local blockchain is ahead");
        }
    }
    else {
        DDLogDebug(@"No fast catch-up checkpoint");
    }
    
    const uint32_t fromHeight = self.blockChain.currentHeight;
    const uint32_t toHeight = self.downloadPeer.lastBlockHeight;
    [self.peerGroup.notifier notifyDownloadStartedFromHeight:fromHeight toHeight:toHeight];
    
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

    DDLogDebug(@"Behind catch-up (or headers-only mode), requesting headers with locator: %@", locator.hashes);
    [self.downloadPeer sendGetheadersMessageWithLocator:locator hashStop:nil];
}

- (void)requestBlocksWithLocator:(WSBlockLocator *)locator
{
    NSParameterAssert(locator);

    DDLogDebug(@"Beyond catch-up (or full blocks mode), requesting block hashes with locator: %@", locator.hashes);
    [self.downloadPeer sendGetblocksMessageWithLocator:locator hashStop:nil];
}

- (void)aheadRequestOnReceivedHeaders:(NSArray *)headers
{
    NSParameterAssert(headers.count > 0);
    
//    const uint32_t currentHeight = self.blockChain.currentHeight;
//
//    DDLogDebug(@"Still behind (%u < %u), requesting more headers ahead of time",
//               currentHeight, self.lastBlockHeight);
    
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
        DDLogInfo(@"All received headers beyond catch-up, rerequesting blocks");
        
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
            DDLogInfo(@"Last header before catch-up at block %@, timestamp %u (%@)",
                      lastHeaderBeforeFCU.blockId, lastHeaderBeforeFCU.timestamp,
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
    
//    const uint32_t currentHeight = self.blockChain.currentHeight;
//
//    DDLogDebug(@"Still behind (%u < %u), requesting more blocks ahead of time",
//               currentHeight, self.lastBlockHeight);
    
    WSHash256 *firstId = [hashes firstObject];
    WSHash256 *lastId = [hashes lastObject];
    
    WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:@[lastId, firstId]];
    [self requestBlocksWithLocator:locator];
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
    
    //        NSAssert(self.processingBlockIds.count <= 2 * WSMessageBlocksMaxCount, @"Processing too many blocks (%u > %u)",
    //                 self.processingBlockIds.count, 2 * WSMessageBlocksMaxCount);
    
    NSArray *outdatedIds = [self.processingBlockIds array];
    
#warning XXX: outdatedIds size shouldn't overflow WSMessageMaxInventories
    
    if (outdatedIds.count > 0) {
        DDLogDebug(@"Requesting %lu outdated blocks with updated Bloom filter: %@", (unsigned long)outdatedIds.count, outdatedIds);
        [self.downloadPeer sendGetdataMessageWithHashes:outdatedIds forInventoryType:WSInventoryTypeFilteredBlock];
    }
    else {
        DDLogDebug(@"No outdated blocks to request with updated Bloom filter");
    }
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
    } synchronously:NO];
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
        WSStorableBlock *addedBlock = nil;
        WSStorableBlock *previousHead = nil;
        __weak WSBlockChainDownloader *weakSelf = self;
        
        WSBlockChainLocation location;
        NSArray *connectedOrphans;
        previousHead = self.blockChain.head;
        addedBlock = [self.blockChain addBlockWithHeader:header
                                            transactions:nil
                                                location:&location
                                        connectedOrphans:&connectedOrphans
                                         reorganizeBlock:^(WSStorableBlock *base, NSArray *oldBlocks, NSArray *newBlocks) {
            
            [weakSelf handleReorganizeAtBase:base oldBlocks:oldBlocks newBlocks:newBlocks];
            
        } error:&localError];
        
        if (!addedBlock) {
            [self logRejectedEntity:header location:location error:localError];
            [self storeRelevantError:localError intoError:error];
            return NO;
        }
        
        [self logAddedBlock:addedBlock location:location];

        [self handleAddedBlock:addedBlock previousHead:previousHead originalEntity:header];
        for (WSStorableBlock *block in connectedOrphans) {
            [self handleAddedBlock:block previousHead:previousHead originalEntity:nil];
        }
    }

    return YES;
}

- (BOOL)appendBlock:(WSBlock *)fullBlock error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(fullBlock);

    NSError *localError;
    WSStorableBlock *addedBlock = nil;
    WSStorableBlock *previousHead = nil;
    __weak WSBlockChainDownloader *weakSelf = self;
    
    WSBlockChainLocation location;
    NSArray *connectedOrphans;
    previousHead = self.blockChain.head;
    addedBlock = [self.blockChain addBlockWithHeader:fullBlock.header
                                        transactions:fullBlock.transactions
                                            location:&location
                                    connectedOrphans:&connectedOrphans
                                     reorganizeBlock:^(WSStorableBlock *base, NSArray *oldBlocks, NSArray *newBlocks) {
        
        [weakSelf handleReorganizeAtBase:base oldBlocks:oldBlocks newBlocks:newBlocks];
        
    } error:&localError];
    
    if (!addedBlock) {
        [self logRejectedEntity:fullBlock location:location error:localError];
        [self storeRelevantError:localError intoError:error];
        return NO;
    }
    
    [self logAddedBlock:addedBlock location:location];

    [self handleAddedBlock:addedBlock previousHead:previousHead originalEntity:fullBlock];
    for (WSStorableBlock *block in connectedOrphans) {
        [self handleAddedBlock:block previousHead:previousHead originalEntity:nil];
    }

    return YES;
}

- (BOOL)appendFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(filteredBlock);
    NSParameterAssert(transactions);

    NSError *localError;
    WSStorableBlock *addedBlock = nil;
    WSStorableBlock *previousHead = nil;
    __weak WSBlockChainDownloader *weakSelf = self;
    
    WSBlockChainLocation location;
    NSArray *connectedOrphans;
    previousHead = self.blockChain.head;
    addedBlock = [self.blockChain addBlockWithHeader:filteredBlock.header
                                        transactions:transactions
                                            location:&location
                                    connectedOrphans:&connectedOrphans
                                     reorganizeBlock:^(WSStorableBlock *base, NSArray *oldBlocks, NSArray *newBlocks) {
        
        [weakSelf handleReorganizeAtBase:base oldBlocks:oldBlocks newBlocks:newBlocks];
        
    } error:&localError];
    
    if (!addedBlock) {
        [self logRejectedEntity:filteredBlock location:location error:localError];
        [self storeRelevantError:localError intoError:error];
        return NO;
    }
    
    [self logAddedBlock:addedBlock location:location];

    [self handleAddedBlock:addedBlock previousHead:previousHead originalEntity:filteredBlock];
    for (WSStorableBlock *block in connectedOrphans) {
        [self handleAddedBlock:block previousHead:previousHead originalEntity:nil];
    }
    
    return YES;
}

- (void)truncateBlockChainForRescan
{
    DDLogDebug(@"Rescan, preparing to truncate blockchain and wallet (if any)");
    
    [self.blockChain truncate];
    NSAssert(self.blockChain.currentHeight == 0, @"Expected genesis blockchain");
    [self.wallet removeAllTransactions];
    
    DDLogDebug(@"Rescan, truncate complete");
    [self.peerGroup.notifier notifyRescan];
}

#pragma mark Entity handlers

- (void)handleAddedBlock:(WSStorableBlock *)block previousHead:(WSStorableBlock *)previousHead originalEntity:(id)entity
{
    NSParameterAssert(block);
    NSParameterAssert(previousHead);

    // new block
    if (![block.blockId isEqual:previousHead.blockId]) {
        [self.peerGroup.notifier notifyBlock:block];
        
        // download finished
        if (block.height == self.downloadPeer.lastBlockHeight) {
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
            [self.peerGroup.notifier notifyDownloadFinished];
        }
    }
    
    if (self.wallet) {
        [self recoverMissedBlockTransactions:block originalEntity:entity];
    }
}

- (void)handleReceivedTransaction:(WSSignedTransaction *)transaction
{
    NSParameterAssert(transaction);

    if (self.wallet) {
        BOOL didGenerateNewAddresses = NO;
        if (![self.wallet registerTransaction:transaction didGenerateNewAddresses:&didGenerateNewAddresses]) {
            return;
        }
    
        if (didGenerateNewAddresses) {
            DDLogDebug(@"Last transaction triggered new addresses generation");
            
            if ([self maybeRebuildAndSendBloomFilter]) {
                [self requestOutdatedBlocks];
            }
        }
    }
}

- (void)handleReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks
{
    NSParameterAssert(base);
    NSParameterAssert(oldBlocks);
    NSParameterAssert(newBlocks);

    DDLogDebug(@"Reorganized blockchain at block: %@", base);
    DDLogDebug(@"Reorganize, old blocks: %@", oldBlocks);
    DDLogDebug(@"Reorganize, new blocks: %@", newBlocks);
    
    [self.peerGroup.notifier notifyReorganizationWithOldBlocks:oldBlocks newBlocks:newBlocks];
    
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
    
    if (self.wallet) {
        BOOL didGenerateNewAddresses = NO;
        [self.wallet reorganizeWithOldBlocks:oldBlocks newBlocks:newBlocks didGenerateNewAddresses:&didGenerateNewAddresses];
        
        if (didGenerateNewAddresses) {
            DDLogWarn(@"Reorganize triggered (unexpected) new addresses generation");
            
            if ([self maybeRebuildAndSendBloomFilter]) {
                [self requestOutdatedBlocks];
            }
        }
    }
}

- (void)recoverMissedBlockTransactions:(WSStorableBlock *)block originalEntity:(id)entity
{
    NSParameterAssert(block);
    
    // don't register orphan blocks
    if ([self.blockChain isKnownOrphanBlockWithId:block.blockId]) {
        return;
    }

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

    // optionally merge txids from empty filtered block
    WSFilteredBlock *filteredBlock;
    if ([entity isKindOfClass:[WSFilteredBlock class]]) {
        filteredBlock = entity;
    }
    [self.wallet registerBlock:block matchingFilteredBlock:filteredBlock];

    if (didGenerateNewAddresses) {
        DDLogWarn(@"Block registration triggered new addresses generation");

        if ([self maybeRebuildAndSendBloomFilter]) {
            [self requestOutdatedBlocks];
        }
    }
}

- (BOOL)maybeRebuildAndSendBloomFilter
{
    if (![self needsBloomFiltering]) {
        return NO;
    }
    
    DDLogDebug(@"Bloom filter may be outdated (height: %u, receive: %lu, change: %lu)",
               self.blockChain.currentHeight,
               (unsigned long)self.wallet.allReceiveAddresses.count,
               (unsigned long)self.wallet.allChangeAddresses.count);
    
    if ([self.wallet isCoveredByBloomFilter:self.bloomFilter]) {
        DDLogDebug(@"Wallet is still covered by current Bloom filter, not rebuilding");
        return NO;
    }
    
    DDLogDebug(@"Wallet is not covered by current Bloom filter anymore, rebuilding now");
    
    if ([self.wallet isKindOfClass:[WSHDWallet class]]) {
        WSHDWallet *hdWallet = (WSHDWallet *)self.wallet;
        
        DDLogDebug(@"HD wallet: generating %lu look-ahead addresses", (unsigned long)hdWallet.gapLimit);
        [hdWallet generateAddressesWithLookAhead:hdWallet.gapLimit];
        DDLogDebug(@"HD wallet: receive: %lu, change: %lu)",
                   (unsigned long)hdWallet.allReceiveAddresses.count,
                   (unsigned long)hdWallet.allChangeAddresses.count);
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

#pragma mark Macros

- (void)logAddedBlock:(WSStorableBlock *)block location:(WSBlockChainLocation)location
{
    NSParameterAssert(block);
    
    if ([self isSynced]) {
        switch (location) {
            case WSBlockChainLocationMain: {
                DDLogInfo(@"New head: %@", self.blockChain.head);
                break;
            }
            case WSBlockChainLocationFork: {
                DDLogInfo(@"New fork block: %@", block);
                DDLogInfo(@"Fork base: %@", [self.blockChain findForkBaseFromHead:block]);
                break;
            }
            case WSBlockChainLocationOrphan: {
                DDLogInfo(@"New orphan: %@", block);
                break;
            }
            case WSBlockChainLocationNone: {
                break;
            }
        }
    }
}

- (void)logRejectedEntity:(id)entity location:(WSBlockChainLocation)location error:(NSError *)error
{
    NSParameterAssert(entity);

    if (location == WSBlockChainLocationOrphan) {
        return;
    }
    if (!error) {
        DDLogDebug(@"%@ not added: %@", [entity class], entity);
    }
    else {
        DDLogDebug(@"Error adding %@ (%@): %@", [entity class], error, entity);
    }
    DDLogDebug(@"Current head: %@", self.blockChain.head);
}

- (void)storeRelevantError:(NSError *)error intoError:(NSError *__autoreleasing *)outError
{
    if (!error || !outError) {
        return;
    }
    if ((error.domain == WSErrorDomain) && (error.code == WSErrorCodeInvalidBlock)) {
        *outError = error;
    }
}

@end
