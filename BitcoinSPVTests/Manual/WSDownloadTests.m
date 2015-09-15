//
//  WSDownloadTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 12/07/14.
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
#import "WSPeerGroup.h"

@interface WSDownloadTests : XCTestCase

@property (nonatomic, strong) id<WSBlockStore> store;
@property (nonatomic, assign) volatile BOOL stopOnSync;

- (id<WSBlockStore>)memoryStore;
- (NSString *)storePath;

@end

@implementation WSDownloadTests

- (void)setUp
{
    [super setUp];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserverForName:WSPeerGroupDidStartDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        const NSUInteger from = [note.userInfo[WSPeerGroupDownloadFromHeightKey] unsignedIntegerValue];
        const NSUInteger to = [note.userInfo[WSPeerGroupDownloadToHeightKey] unsignedIntegerValue];
        
        DDLogInfo(@"Download started, status = %u/%u", from, to);
    }];
    [nc addObserverForName:WSPeerGroupDidFinishDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        DDLogInfo(@"Download finished");

        if (self.stopOnSync) {
            [self stopRunning];
        }
    }];

    [nc addObserverForName:WSPeerGroupDidDownloadBlockNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        WSStorableBlock *block = note.userInfo[WSPeerGroupDownloadBlockKey];
        
        if (block.height % 100 == 0) {
            DDLogInfo(@"Downloaded block #%u: %@", block.height, block);
        }
    }];
    [nc addObserverForName:WSPeerGroupDidRelayTransactionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        WSSignedTransaction *tx = note.userInfo[WSPeerGroupRelayTransactionKey];
        
        DDLogInfo(@"Relayed transaction: %@", tx);
    }];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMemory
{
    self.networkType = WSNetworkTypeTestnet3;

    self.store = [self memoryStore];
    
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:self.store headersOnly:YES];
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 1;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    [self runForever];
}

- (void)testMemoryWithFCU
{
    self.networkType = WSNetworkTypeTestnet3;

    self.store = [self memoryStore];
    const uint32_t timestamp = WSTimestampFromISODate(@"2013-08-29");
    
    DDLogInfo(@"Catch-up: %u", timestamp);

    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:self.store fastCatchUpTimestamp:timestamp];
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 1;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    [self runForSeconds:10.0];
}

- (void)testPersistent
{
    self.networkType = WSNetworkTypeTestnet3;

    self.store = [self memoryStore];
    WSCoreDataManager *manager = [[WSCoreDataManager alloc] initWithPath:self.storePath error:NULL];
    
//    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:self.store fastCatchUpTimestamp:WSTimestampFromISODate(@"2012-04-18")];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:self.store headersOnly:YES];
    downloader.coreDataManager = manager;
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 3;
    peerGroup.maxConnectionFailures = 20;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
//    [self runForSeconds:5.0];
//    [peerGroup stopDownload];
//    [peerGroup stopConnectionsWithCompletionBlock:NULL];
    [self runForever];
}

- (void)testPersistentWithFCU_Test3
{
    self.networkType = WSNetworkTypeTestnet3;
    
    [self privateTestPersistentWithFCU];
}

- (void)testPersistentWithFCU_Main
{
    self.networkType = WSNetworkTypeMain;

    [self privateTestPersistentWithFCU];
}

- (void)testPersistentStoredHeads
{
    self.networkType = WSNetworkTypeTestnet3;
    self.store = [self persistentStoreTruncating:NO];
    DDLogInfo(@"Test: %@", self.store.head);

    self.networkType = WSNetworkTypeMain;
    self.store = [self persistentStoreTruncating:NO];
    DDLogInfo(@"Main: %@", self.store.head);
}

- (void)testPersistentStoredWork_Test3
{
    self.networkType = WSNetworkTypeTestnet3;
    
    [self privateTestPersistentStoredWork];
}

- (void)testPersistentStoredWork_Main
{
    self.networkType = WSNetworkTypeMain;
    
    [self privateTestPersistentStoredWork];
}

- (void)testPersistent1
{
    self.networkType = WSNetworkTypeTestnet3;
    
    // WARNING: check this, may clear all blockchain store!
    self.store = [self persistentStoreTruncating:YES];
    self.stopOnSync = YES;
    
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:self.store headersOnly:YES];
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 1;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    
    [self runForever];
}

- (void)testPersistent2
{
    self.networkType = WSNetworkTypeTestnet3;
    
    // WARNING: check this, may clear all blockchain store!
    self.store = [self persistentStoreTruncating:NO];
    self.stopOnSync = YES;

    // = ?, headers should stop at #266668
    const uint32_t timestamp = WSTimestampFromISODate(@"2014-07-04");
//    const uint32_t timestamp = 0;

//    // = 1401055200, headers should stop at #267965
//    const uint32_t timestamp = WSTimestampFromISODate(@"2014-07-10");

//    // = 1405288800, headers should stop at #268578
//    const uint32_t timestamp = WSTimestampFromISODate(@"2014-07-14");

    DDLogInfo(@"Catch-up: %u", timestamp);
    
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:self.store fastCatchUpTimestamp:timestamp];
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 10;
    [peerGroup startConnections];
//    [peerGroup startSyncingUntilHeight:266000];     // fcu 10/07 -> headers only
//    [peerGroup startSyncingUntilHeight:268000];     // fcu 14/07 -> headers only
//    [peerGroup startSyncingUntilHeight:268583];     // fcu 14/07 -> headers + 5 blocks

    //
    // fcu 04/07 (266921)
    //
    // 262080 -> 269000 = 6920 storable
    //
    // 266668 - 262080 = 4588 headers
    // 269000 - 266668 = 2332 blocks
    //
    // 4588 headers + 2332 blocks = 6920
    //
    // last retarget at floor(6920 / 2016) * 2016 = 3 * 2016 = 6048
    //
    // 6920 - 6048 = 872 + 1 (head) blocks after pruning
    //
    [peerGroup startDownloadWithDownloader:downloader];
    
    [self runForever];
//    [self runForSeconds:15.0];
//    [self.store save];
}

- (void)testPersistent2StoredHead
{
    self.networkType = WSNetworkTypeTestnet3;

    self.store = [self persistentStoreTruncating:NO];
    DDLogInfo(@"Head: %@", [self.store head]);
}

- (void)testPersistent2StoredChain
{
    self.networkType = WSNetworkTypeTestnet3;
    
    self.store = [self persistentStoreTruncating:NO];
    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:self.store];
    DDLogInfo(@"Chain: %@", [chain descriptionWithMaxBlocks:50]);
}

- (void)testPersistent2StoredBlock
{
    self.networkType = WSNetworkTypeTestnet3;
    
    self.store = [self persistentStoreTruncating:NO];
    
    WSHash256 *blockId = WSHash256FromHex(@"0000000000006a4ac43153c23121f95ce7cced8e18abcf6ece0235e6435472f5");
    WSStorableBlock *block = [self.store blockForId:blockId];
    
    DDLogInfo(@"Transactions in #%u = %u", block.height, block.transactions.count);
    XCTAssertEqual(block.height, 268977);
    XCTAssertEqual(block.transactions.count, 10);

    for (WSSignedTransaction *tx in block.transactions) {
        DDLogInfo(@"%@", tx);
    }
}

//- (void)testPersistent2ConnectedTransactions
//{
//    self.networkType = WSNetworkTypeTestnet3;
//
//    self.store = [self persistentStoreTruncating:NO];
//
//    // considering:
//    //
//    // checkpoint = #262080
//    // fcu = 2014/07/04 (#266668)
//    //
//    // headers from #262080 until #266667
//    // blocks from #266668 until #269000
//
//    NSArray *hexes = @[@"72ff2259ab9207f5ffb8bb8725cdd44f717366d7063c40edd3dd829cb845778e",     // GOOD
//                       @"64dff9790f8360088575d83df3ef1aefb2ff62cafdc6ea5f8512a9db40e8a8f0",     // GOOD
//                       @"06e7162630f2f24cae7f22e601390e2aabbee4beda7b822df150f0611b20639b",     // GOOD, nil previous, from coinbase
//                       @"5ede1c303512b10b78226bdd0532c401960b7cfad5ede17c2f39fc16d879b0fd",     // GOOD
//                       @"33f497a0985ec946cb8712c670a7364415be601d349d90da035b62664ce3d44d",     // GOOD: inputs #1 and #3 have nil previous, from txs before catch-up
//                       @"083b5aa36b588f38be23f11718d6a4044548f2872239ad929bdde5b612d7c2d4"];    // GOOD
//    
//    NSArray *connected = @[@(YES),
//                           @(YES),
//                           @(NO),
//                           @(YES),
//                           @(NO),
//                           @(YES)];
//
//    NSUInteger i = 0;
//    for (NSString *hex in hexes) {
//        WSSignedTransaction *tx = [self.store transactionForId:WSHash256FromHex(hex) connect:YES];
//
//        XCTAssertEqual([tx isConnected], [connected[i] boolValue]);
//        
//        uint64_t fee;
//        NSError *error;
//        if ([tx verifyWithEffectiveFee:&fee error:&error]) {
//            DDLogInfo(@"Valid (fee: %llu): %@", fee, tx);
//        }
//        else {
//            DDLogInfo(@"Invalid (%@): %@", error, tx);
//        }
//        
//        ++i;
//    }
//}

- (void)testMemorySearchingNullBlockChainBug
{
    self.networkType = WSNetworkTypeTestnet3;
    
    self.store = [self memoryStore];
    
    const uint32_t timestamp = 1489667954;//1482932908 + mrand48() % 10000000;
    
    DDLogInfo(@"Catch-up: %u", timestamp);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:WSPeerGroupDidFinishDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self stopRunning];
        
        [self performSelector:@selector(testMemorySearchingNullBlockChainBug) withObject:self afterDelay:2.0];
    }];
    
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:self.store fastCatchUpTimestamp:timestamp];
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
//    peerGroup.peerHosts = @[@"203.69.212.66"];
    peerGroup.maxConnections = 10;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    
    [self runForever];
}

#pragma mark Reusable

- (void)privateTestPersistentWithFCU
{
    // WARNING: check this, may clear all blockchain store!
    self.store = [self persistentStoreTruncating:NO];
    self.stopOnSync = YES;

    const uint32_t timestamp = WSTimestampFromISODate(@"2013-02-09");
    DDLogInfo(@"Catch-up: %u", timestamp);

    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:self.store fastCatchUpTimestamp:timestamp];
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 10;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    
    [self runForever];
}

- (void)privateTestPersistentStoredWork
{
    // WARNING: check this, may clear all blockchain store!
    self.store = [self persistentStoreTruncating:NO];
    
    DDLogInfo(@"Head: %@", self.store.head);
    
    //
    // notice delta(work) changing at:
    //
    // 28 * 2016 = 56448 (+11)
    // 27 * 2016 = 54432 (+12)
    // 26 * 2016 = 52416 (+11)
    // 25 * 2016 = 50400 (+7)
    // 24 * 2016 = 48384 (+6)
    // 23 * 2016 = 46368 (+4)
    // ...
    // ...
    //
    //    WSStorableBlock *block = chain.head;
    //    while (block) {
    //        DDLogInfo(@"Work at #%u = %@", block.height, block.workString);
    //        block = [block previousBlockInChain:chain];
    //    }
}

#pragma mark Helpers

- (id<WSBlockStore>)memoryStore
{
    return [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
}

- (NSString *)storePath
{
    return [self mockNetworkPathForFilename:@"SyncTests" extension:@"sqlite"];
    
}

@end
