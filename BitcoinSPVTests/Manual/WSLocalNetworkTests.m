//
//  WSLocalNetworkTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 21/07/14.
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

#import "XCTestCase+BitcoinSPV.h"

@interface WSHDWallet ()

- (void)sortTransactions;

@end

@interface WSLocalNetworkTests : XCTestCase

@end

@implementation WSLocalNetworkTests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeRegtest;
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testMemorySync
{
    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store headersOnly:NO];
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.peerHosts = @[@"127.0.0.1",
                            @"173.230.142.58"];

    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    [self runForever];
}

//
// ENVIRONMENT #1
//
// STEP 1
//
// start 1 bitcoind node (local) on regtest
// connect and sync to height 0
// mine 3 blocks
// we should sync to height 3
//
//
//
// ENVIRONMENT #2
//
// STEP 1
//
// start 2 bitcoind nodes (local, remote) on regtest
// mine 5 blocks on one of them
// both nodes should have the same 5+1 (genesis) nodes, height is 5
//
// STEP 2
//
// connect and sync to both nodes
// our height is now also 5
//
// STEP 3
//
// stop remote node
// mine 2 blocks on local node
// we're synced to height 7
//
// STEP 4
//
// stop local node
// start remote node
// mine 4 blocks on remote node
// stop remote node
// start local node
// connect to both nodes
// we're synced to height 7
//
// STEP 5
//
// start remote node
// should reorg to height 9
//
//
//
// ENVIRONMENT #3
//
// STEP 1
//
// start 2 bitcoind nodes (local, remote) on regtest
// addnode to sync each other
// mine 3 blocks on one of them
// both nodes will have the same 3+1 (genesis) nodes, height is 3
//
// STEP 2
//
// connect and sync to both nodes
// our height is now also 3
//
// STEP 3
//
// stop remote node
// mine 5 blocks on local node until height 8
// connect and sync with local node
//
// STEP 4
//
// stop local node
// start remote node
// mine 7 blocks on remote node until height 10
//
// STEP 5
//
// connect to remote node
// sync
// should reorg to height 10
//
// STEP 6
//
// stop remote node
// start local node
// mine 10 blocks on local node until height 18
// start remote node
// remote node should reorg to height 18
//
// STEP 7
//
// connect to both nodes
// should reorg to height 18
//
// STEP 8
//
// stop local node
// mine 12 blocks on remote node until height 30
// stop remote node
// start local node
//
// STEP 9
//
// connect to both nodes (persistently)
// we're synced to height 18
// start remote node
// should relay blocks and reorg to height 30
//
// STEP 10
//
// mine 20 blocks on local node
// we and remote node should sync to height 50
//
- (void)testPersistentReorganize
{
    NSString *storePath = [self mockPathForFile:@"LocalNetworkTests-Reorganize.sqlite"];
    WSCoreDataManager *manager = [[WSCoreDataManager alloc] initWithPath:storePath error:NULL];
    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store headersOnly:YES];
    downloader.coreDataManager = manager;
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:WSPeerGroupDidDownloadBlockNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        WSStorableBlock *block = note.userInfo[WSPeerGroupDownloadBlockKey];
        
        DDLogInfo(@"Downloaded block #%u: %@", block.height, block);
    }];

    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.peerHosts = @[
                            @"127.0.0.1",
                            @"173.230.142.58"
                            ];
    
    peerGroup.maxConnections = 2;
    [peerGroup startConnections];
    [self runForSeconds:3.0];
    [peerGroup startDownloadWithDownloader:downloader];
//    [self runForever];
    [self runForSeconds:3.0];
    [peerGroup saveState];
}

//
// ENVIRONMENT
//
// mine 101 blocks to have balance = 50BTC
//
// send 10BTC to account 0
// mine 1 tx in block 102
//
// send 1BTC to account 0
// mine 1 tx in block 103
//
// send 0.1BTC to accounts 1, 2, 3, 4
// mine 4 txs in block 104
//
// send 0.1BTC to accounts 5, 6, 7, 8, 9
// mine 5 txs in block 105
//
// gap limit = 2
// expected wallet txs = 11
// expected wallet balance = 11.9BTC
//
- (void)testPersistentWalletSync
{
    NSString *storePath = [self mockPathForFile:@"LocalNetworkTests-WalletSync.sqlite"];
    NSString *walletPath = [self mockPathForFile:@"LocalNetworkTests-WalletSync.wallet"];

    [[NSFileManager defaultManager] removeItemAtPath:walletPath error:NULL];

    NSString *mnemonic = [self mockWalletMnemonic];
    WSSeed *seed = WSSeedMakeUnknown(mnemonic);
    WSHDWallet *wallet = [WSHDWallet loadFromPath:walletPath parameters:self.networkParameters seed:seed];
    if (!wallet) {
        wallet = [[WSHDWallet alloc] initWithParameters:self.networkParameters
                                                   seed:seed
                                             chainsPath:WSBIP32DefaultPath
                                               gapLimit:4];
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserverForName:WSPeerGroupDidDownloadBlockNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            WSStorableBlock *block = note.userInfo[WSPeerGroupDownloadBlockKey];
            
            DDLogInfo(@"Downloaded block #%u: %@", block.height, block);
        }];
        [nc addObserverForName:WSPeerGroupDidFinishDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [self stopRunning];
        }];
        [nc addObserverForName:WSWalletDidRegisterTransactionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [wallet saveToPath:walletPath];
            
            WSSignedTransaction *tx = note.userInfo[WSWalletDidRegisterTransactionNotification];
            DDLogInfo(@"Registered transaction: %@", tx);
        }];
        [nc addObserverForName:WSWalletDidUpdateBalanceNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            id<WSWallet> wallet = note.object;
            
            DDLogInfo(@"Balance: %llu", wallet.balance);
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:WSWalletDidUpdateTransactionsMetadataNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            NSDictionary *metadataById = note.userInfo[WSWalletTransactionsMetadataKey];
            
            DDLogInfo(@"Mined transactions: %@", metadataById);
        }];
    });
    
    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store wallet:wallet];
    downloader.coreDataManager = [[WSCoreDataManager alloc] initWithPath:storePath error:NULL];
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.peerHosts = @[@"127.0.0.1"];
    peerGroup.maxConnections = 1;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
//    [self runForSeconds:10.0];
    [self runForever];
    
//    if (wallet.allTransactions.count == 11) {
//        [self runForSeconds:3.0];
//        [self performSelectorOnMainThread:@selector(testPersistentWalletSync) withObject:nil waitUntilDone:YES];
//    }
}

- (void)testPersistentWalletSyncStatus
{
    NSString *storePath = [self mockPathForFile:@"LocalNetworkTests-WalletSync.sqlite"];
    NSString *walletPath = [self mockPathForFile:@"LocalNetworkTests-WalletSync.wallet"];

    WSCoreDataManager *manager = [[WSCoreDataManager alloc] initWithPath:storePath error:NULL];
    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:store];
    [chain loadFromCoreDataManager:manager];

    DDLogInfo(@"Blockchain: %@", [chain descriptionWithMaxBlocks:10]);

    NSString *mnemonic = [self mockWalletMnemonic];
    WSHDWallet *wallet = [WSHDWallet loadFromPath:walletPath parameters:self.networkParameters seed:WSSeedMakeUnknown(mnemonic)];

    [wallet sortTransactions];
    DDLogInfo(@"Receive addresses: %@", wallet.allReceiveAddresses);
    DDLogInfo(@"Change addresses: %@", wallet.allChangeAddresses);
    DDLogInfo(@"Current receive address: %@", wallet.receiveAddress);
    DDLogInfo(@"Current change address: %@", wallet.changeAddress);
    DDLogInfo(@"Used addresses: %@", wallet.usedAddresses);
    
    NSArray *txs = wallet.sortedTransactions;
    DDLogInfo(@"Wallet has %lu transactions", (unsigned long)txs.count);
    for (WSSignedTransaction *tx in txs) {
        DDLogInfo(@"%@", tx);
    }
}

@end
