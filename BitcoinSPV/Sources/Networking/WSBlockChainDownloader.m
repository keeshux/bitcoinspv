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
#import "WSBlockStore.h"
#import "WSBlockChain.h"
#import "WSBlockHeader.h"
#import "WSWallet.h"
#import "WSHDWallet.h"
#import "WSConnectionPool.h"
#import "WSStorableBlock.h"
#import "WSBlockLocator.h"
#import "WSParameters.h"
#import "WSLogging.h"
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
@property (nonatomic, strong) WSPeer *downloadPeer;
@property (nonatomic, strong) NSCountedSet *pendingBlockIds;
@property (nonatomic, strong) NSMutableOrderedSet *processingBlockIds;
@property (nonatomic, assign) NSUInteger filteredBlockCount;
@property (nonatomic, strong) WSBlockLocator *startingBlockChainLocator;

- (WSPeer *)bestPeerAmongPeers:(NSArray *)peers;
//- (void)rebuildBloomFilter;
- (void)loadFilterAndStartDownload;
- (void)downloadBlockChain;
- (void)requestHeadersWithLocator:(WSBlockLocator *)locator;
- (void)requestBlocksWithLocator:(WSBlockLocator *)locator;
//- (void)aheadRequestOnReceivedHeaders:(NSArray *)headers;
//- (void)aheadRequestOnReceivedBlockHashes:(NSArray *)hashes;
//- (void)addBlockHeaders:(NSArray *)headers; // WSBlockHeader

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
    if ((self = [self init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = nil;
        self.fastCatchUpTimestamp = fastCatchUpTimestamp;

        self.shouldDownloadBlocks = NO;
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

        self.shouldDownloadBlocks = NO;
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

- (void)peerGroup:(WSPeerGroup *)peerGroup didStartDownloadWithConnectedPeers:(NSArray *)connectedPeers
{
    self.downloadPeer = [self bestPeerAmongPeers:connectedPeers];
    if (!self.downloadPeer) {
        DDLogInfo(@"Delayed download until peer selection");
        return;
    }
    DDLogInfo(@"Peer %@ is new download peer", self.downloadPeer);

    [self loadFilterAndStartDownload];
}

- (void)peerGroupDidStopDownload:(WSPeerGroup *)peerGroup pool:(WSConnectionPool *)pool
{
    if (self.downloadPeer) {
        DDLogInfo(@"Download from peer %@ is being stopped", self.downloadPeer);

        [pool closeConnectionForProcessor:self.downloadPeer
                                    error:WSErrorMake(WSErrorCodePeerGroupStop, @"Download stopped")];
    }
    self.downloadPeer = nil;
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peerDidConnect:(WSPeer *)peer
{
    if (!self.downloadPeer) {
        self.downloadPeer = peer;
        DDLogInfo(@"Peer %@ connected, is new download peer", self.downloadPeer);

        [self loadFilterAndStartDownload];
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didDisconnectWithError:(NSError *)error connectedPeers:(NSArray *)connectedPeers
{
    if (peer != self.downloadPeer) {
        return;
    }

    DDLogDebug(@"Peer %@ disconnected, was download peer", peer);

    self.downloadPeer = [self bestPeerAmongPeers:connectedPeers];
    if (!self.downloadPeer) {
        DDLogError(@"No more peers for download (%@)", error);
        return;
    }
    DDLogDebug(@"Switched to next best download peer %@", self.downloadPeer);

    [self loadFilterAndStartDownload];
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveHeaders:(NSArray *)headers
{
    if (peer != self.downloadPeer) {
        return;
    }
#warning TODO: download, handle headers
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveBlockHashes:(NSArray *)hashes
{
    if (peer != self.downloadPeer) {
        return;
    }
#warning TODO: download, handle block hashes
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveBlock:(WSBlock *)block
{
    if (peer != self.downloadPeer) {
        return;
    }
#warning FIXME: handle full blocks, blockchain not extending in full blocks mode
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions
{
    if (peer != self.downloadPeer) {
        return;
    }
#warning TODO: download, handle filtered block
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveTransaction:(WSSignedTransaction *)transaction
{
    if (peer != self.downloadPeer) {
        return;
    }
#warning TODO: download, handle transaction
}

#pragma mark Helpers

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

- (void)loadFilterAndStartDownload
{
    if (self.wallet) {
        const NSTimeInterval rebuildStartTime = [NSDate timeIntervalSinceReferenceDate];
        WSBloomFilter *bloomFilter = [self.wallet bloomFilterWithParameters:self.bloomFilterParameters];
        const NSTimeInterval rebuildTime = [NSDate timeIntervalSinceReferenceDate] - rebuildStartTime;

        DDLogDebug(@"Bloom filter rebuilt in %.3fs (false positive rate: %f)",
                   rebuildTime, self.bloomFilterParameters.falsePositiveRate);

        DDLogDebug(@"Loading Bloom filter for download peer %@", self.downloadPeer);
        [self.downloadPeer sendFilterloadMessageWithFilter:bloomFilter];
    }
    else if (self.shouldDownloadBlocks) {
        DDLogDebug(@"No wallet provided, downloading full blocks");
    }
    else {
        DDLogDebug(@"No wallet provided, downloading block headers");
    }

    DDLogInfo(@"Preparing for blockchain download");

    [self downloadBlockChain];
}

- (void)downloadBlockChain
{
    if (self.blockChain.currentHeight >= self.downloadPeer.lastBlockHeight) {
//        if (syncedBlock) {
//            syncedBlock(blockChain.currentHeight);
//        }
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
    
//    if (prestartBlock) {
//        const NSUInteger fromHeight = self.blockChain.currentHeight;
//        const NSUInteger toHeight = self.downloadPeer.lastBlockHeight;
//        
//        prestartBlock(fromHeight, toHeight);
//    }
    
    self.fastCatchUpTimestamp = self.fastCatchUpTimestamp;
    self.startingBlockChainLocator = [self.blockChain currentLocator];
    
    if (!self.shouldDownloadBlocks || (self.blockChain.currentTimestamp < self.fastCatchUpTimestamp)) {
        [self requestHeadersWithLocator:self.startingBlockChainLocator];
    }
    else {
        [self requestBlocksWithLocator:self.startingBlockChainLocator];
    }
}

- (void)requestHeadersWithLocator:(WSBlockLocator *)locator
{
    DDLogDebug(@"%@ Behind catch-up (or headers-only mode), requesting headers with locator: %@", self, locator.hashes);
    [self.downloadPeer sendGetheadersMessageWithLocator:locator hashStop:nil];
}

- (void)requestBlocksWithLocator:(WSBlockLocator *)locator
{
    DDLogDebug(@"%@ Beyond catch-up (or full blocks mode), requesting block hashes with locator: %@", self, locator.hashes);
    [self.downloadPeer sendGetblocksMessageWithLocator:locator hashStop:nil];
}

@end
