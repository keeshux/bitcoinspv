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

@interface WSBlockChainDownloader ()

// configuration
@property (nonatomic, strong) id<WSBlockStore> store;
@property (nonatomic, strong) WSBlockChain *blockChain;
@property (nonatomic, strong) id<WSSynchronizableWallet> wallet;
@property (nonatomic, assign) uint32_t fastCatchUpTimestamp;
@property (nonatomic, assign) BOOL shouldDownloadBlocks;
@property (nonatomic, assign) BOOL needsBloomFiltering;

// state
@property (nonatomic, assign) BOOL isDownloading;
@property (nonatomic, strong) NSCountedSet *pendingBlockIds;
@property (nonatomic, strong) NSMutableOrderedSet *processingBlockIds;
@property (nonatomic, assign) NSUInteger filteredBlockCount;
@property (nonatomic, strong) WSBlockLocator *startingBlockChainLocator;

- (void)aheadRequestOnReceivedHeaders:(NSArray *)headers;
- (void)aheadRequestOnReceivedBlockHashes:(NSArray *)hashes;
- (void)requestHeadersWithLocator:(WSBlockLocator *)locator;
- (void)requestBlocksWithLocator:(WSBlockLocator *)locator;
- (void)addBlockHeaders:(NSArray *)headers; // WSBlockHeader

@end

@implementation WSBlockChainDownloader

- (instancetype)initWithStore:(id<WSBlockStore>)store headersOnly:(BOOL)headersOnly
{
    if ((self = [super init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = nil;
        self.fastCatchUpTimestamp = 0;

        self.shouldDownloadBlocks = !headersOnly;
        self.needsBloomFiltering = NO;
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    if ((self = [super init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = nil;
        self.fastCatchUpTimestamp = fastCatchUpTimestamp;

        self.shouldDownloadBlocks = NO;
        self.needsBloomFiltering = NO;
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet
{
    if ((self = [super init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = wallet;
        self.fastCatchUpTimestamp = [self.wallet earliestKeyTimestamp];

        self.shouldDownloadBlocks = NO;
        self.needsBloomFiltering = YES;
    }
    return self;
}

- (id<WSParameters>)parameters
{
    return [self.store parameters];
}

#pragma mark Download helpers (unsafe)

//- (WSPeer *)bestPeer
//{
//    WSPeer *bestPeer = nil;
//    for (WSPeer *peer in self.connectedPeers) {
//
//        // double check connection status
//        if (peer.peerStatus != WSPeerStatusConnected) {
//            continue;
//        }
//
//        // max chain height or min ping
//        if (!bestPeer ||
//            (peer.lastBlockHeight > bestPeer.lastBlockHeight) ||
//            ((peer.lastBlockHeight == bestPeer.lastBlockHeight) && (peer.connectionTime < bestPeer.connectionTime))) {
//
//            bestPeer = peer;
//        }
//    }
//    return bestPeer;
//}

@end
