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
#import "WSStorableBlock+BlockChain.h"

@interface WSDownloadTests : XCTestCase

@property (nonatomic, assign) volatile BOOL stopOnSync;

@end

@implementation WSDownloadTests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeTestnet3;
    
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
        
        if (block.height % 10 == 0) {
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

- (void)testMemoryHeaders
{
    id<WSBlockStore> store = [self memoryStore];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store headersOnly:YES];

    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 3;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    [self runForever];
}

- (void)testMemoryWithFCU
{
    id<WSBlockStore> store = [self memoryStore];
    const uint32_t timestamp = WSTimestampFromISODate(@"2013-08-29");
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store fastCatchUpTimestamp:timestamp];

    DDLogInfo(@"Catch-up: %u", timestamp);

    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 3;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
//    [self runForSeconds:10.0];
    [self runForever];
}

- (void)testPersistentHeaders
{
    id<WSBlockStore> store = [self memoryStore];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store headersOnly:YES];
    downloader.coreDataManager = [self persistentManager];
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 3;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    [self runForever];
}

- (void)testPersistentWithFCU
{
    self.stopOnSync = YES;
    
    id<WSBlockStore> store = [self memoryStore];
    const uint32_t timestamp = WSTimestampFromISODate(@"2013-02-09");
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store fastCatchUpTimestamp:timestamp];
    downloader.coreDataManager = [self persistentManager];

    DDLogInfo(@"Catch-up: %u", timestamp);
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 10;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    [self runForSeconds:10.0];
    [peerGroup saveState];
    [self runForSeconds:5.0];
//    [self runForever];
}

- (void)testPersistentStoredHead
{
    WSBlockChain *blockChain = [self persistentChain];
    DDLogInfo(@"Head: %@", blockChain.head);
}

- (void)testPersistentStoredWork
{
    WSBlockChain *blockChain = [self persistentChain];
    DDLogInfo(@"Head: %@", blockChain.head);
    
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

    WSStorableBlock *block = blockChain.head;
    while (block) {
        DDLogInfo(@"Work at #%u = %@", block.height, block.workString);
        block = [block previousBlockInChain:blockChain];
    }
}

- (void)testAnalysis
{
    self.stopOnSync = YES;
    
    id<WSBlockStore> store = [self memoryStore];

    // = ?, headers should stop at #266668
    const uint32_t timestamp = WSTimestampFromISODate(@"2014-07-04");
//    const uint32_t timestamp = 0;

//    // = 1401055200, headers should stop at #267965
//    const uint32_t timestamp = WSTimestampFromISODate(@"2014-07-10");

//    // = 1405288800, headers should stop at #268578
//    const uint32_t timestamp = WSTimestampFromISODate(@"2014-07-14");

    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store fastCatchUpTimestamp:timestamp];
    downloader.coreDataManager = [self persistentManager];

    DDLogInfo(@"Catch-up: %u", timestamp);
    
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
    
    [self runForSeconds:20.0];
    [peerGroup saveState];
    [self runForSeconds:5.0];
//    [self runForever];
}

- (void)testAnalysisStoredHead
{
    WSBlockChain *blockChain = [self persistentChain];
    DDLogInfo(@"Head: %@", blockChain.head);
}

- (void)testAnalysisStoredChain
{
    WSBlockChain *blockChain = [self persistentChain];
    DDLogInfo(@"Chain: %@", [blockChain descriptionWithMaxBlocks:50]);
}

- (void)testAnalysisStoredBlock
{
    id<WSBlockStore> store = [self memoryStore];
    WSBlockChain *blockChain = [[WSBlockChain alloc] initWithStore:store];
    [blockChain loadFromCoreDataManager:[self persistentManager]];
    
    WSHash256 *blockId = WSHash256FromHex(@"000000009c3754679ccef8a8a4266c4e5eb84fe1c1791e274ad7a617ff9874b6");
    WSStorableBlock *block = [store blockForId:blockId];
    
    DDLogInfo(@"Transactions in #%u = %u", block.height, block.transactions.count);
    XCTAssertEqual(block.height, 266749);
    XCTAssertEqual(block.transactions.count, 198);

    for (WSSignedTransaction *tx in block.transactions) {
        DDLogInfo(@"%@", tx);
    }
}

//- (void)testAnalysisConnectedTransactions
//{
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

#pragma mark Helpers

- (id<WSBlockStore>)memoryStore
{
    return [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
}

- (WSCoreDataManager *)persistentManager
{
    return [[WSCoreDataManager alloc] initWithPath:[self storePath] error:NULL];
}

- (WSBlockChain *)persistentChain
{
    WSBlockChain *blockChain = [[WSBlockChain alloc] initWithStore:[self memoryStore]];
    [blockChain loadFromCoreDataManager:[self persistentManager]];
    return blockChain;
}

- (NSString *)storePath
{
    return [self mockNetworkPathForFilename:@"DownloadTests" extension:@"sqlite"];
    
}

@end
