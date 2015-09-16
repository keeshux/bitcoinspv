//
//  WSDownloadWalletTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 20/07/14.
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

#define WALLET_GAP_LIMIT            10

@interface WSDownloadWalletTests : XCTestCase

@property (nonatomic, strong) id<WSWallet> persistentWallet;
@property (nonatomic, assign) volatile BOOL stopOnSync;

@end

@implementation WSDownloadWalletTests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeTestnet3;
    
//    [[NSNotificationCenter defaultCenter] addObserverForName:WSPeerGroupDidDownloadBlockNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
//        WSStorableBlock *block = note.userInfo[WSPeerGroupDownloadBlockKey];
//
//        DDLogInfo(@"Downloaded block: %@", block);
//    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:WSPeerGroupDidFinishDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self saveWallet:self.persistentWallet];
        
        [self runForSeconds:3.0];
        if (self.stopOnSync) {
            [self stopRunning];
        }
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:WSWalletDidRegisterTransactionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self saveWallet:note.object];
        
        WSSignedTransaction *tx = note.userInfo[WSWalletTransactionKey];
        DDLogInfo(@"Relayed transaction: %@", tx);
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:WSWalletDidUpdateBalanceNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        id<WSWallet> wallet = note.object;
        
        DDLogInfo(@"Balance: %llu", [wallet balance]);
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:WSWalletDidUpdateAddressesNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        id<WSWallet> wallet = note.object;
        
        DDLogInfo(@"New receive address: %@", [wallet receiveAddress]);
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:WSWalletDidUpdateTransactionsMetadataNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSDictionary *metadataById = note.userInfo[WSWalletTransactionsMetadataKey];
        
        DDLogInfo(@"Mined transactions: %@", metadataById);
    }];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSync
{
    self.stopOnSync = YES;

    WSHDWallet *wallet = [self loadWallet];
    if (!wallet) {
        wallet = [[WSHDWallet alloc] initWithParameters:self.networkParameters seed:[self walletSeed] gapLimit:WALLET_GAP_LIMIT];
        [wallet saveToPath:[self walletPath]];
        wallet.shouldAutosave = YES;
    }
    self.persistentWallet = wallet;
    
    DDLogInfo(@"Receive address: %@", [wallet receiveAddress]);

    id<WSBlockStore> store = [self memoryStore];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store wallet:wallet];
    downloader.coreDataManager = [self persistentManager];
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 5;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    [self runForever];
}

- (void)testRescan
{
    self.stopOnSync = YES;
    
    WSHDWallet *wallet = [self loadWallet];
    if (!wallet) {
        wallet = [[WSHDWallet alloc] initWithParameters:self.networkParameters seed:[self walletSeed] gapLimit:WALLET_GAP_LIMIT];
        [wallet saveToPath:[self walletPath]];
        wallet.shouldAutosave = YES;
    }
    self.persistentWallet = wallet;
    
    id<WSBlockStore> store = [self memoryStore];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store wallet:wallet];
    downloader.coreDataManager = [self persistentManager];

    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 3;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    [peerGroup performSelector:@selector(rescanBlockChain) withObject:nil afterDelay:20.0];
    [self runForever];
}

- (void)testChain
{
    id<WSBlockStore> store = [self memoryStore];
    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:store];
    [chain loadFromCoreDataManager:[self persistentManager]];
    
    DDLogInfo(@"Blockchain: %@", [chain descriptionWithMaxBlocks:50]);
}

- (void)testWallet
{
    WSHDWallet *wallet = [self loadWallet];

    DDLogInfo(@"Balance: %llu", wallet.balance);
    DDLogInfo(@"Receive addresses: %@", wallet.allReceiveAddresses);
    DDLogInfo(@"Change addresses: %@", wallet.allChangeAddresses);
    DDLogInfo(@"Current receive address: %@", wallet.receiveAddress);
    DDLogInfo(@"Current change address: %@", wallet.changeAddress);
    DDLogInfo(@"Watched receive addresses: %@", wallet.watchedReceiveAddresses);
    DDLogInfo(@"Used addresses: %@", wallet.usedAddresses);
    
    NSArray *txs = wallet.allTransactions;
    DDLogInfo(@"Wallet has %u transactions", txs.count);
    for (WSSignedTransaction *tx in txs) {
        DDLogInfo(@"%@", tx);
        DDLogInfo(@"Sent:     %llu", [wallet sentValueByTransaction:tx]);
        DDLogInfo(@"Received: %llu", [wallet receivedValueFromTransaction:tx]);
        DDLogInfo(@"Internal: %u", [wallet isInternalTransaction:tx]);

        DDLogInfo(@"Value:    %lld", [wallet valueForTransaction:tx]);
        DDLogInfo(@"Fee:      %llu", [wallet feeForTransaction:tx]);
    }
}

- (void)testSignedTransaction
{
    WSHDWallet *wallet = [self loadWallet];

    WSAddress *address = WSAddressFromString(self.networkParameters, @"mnChN9xy1zvyixmkof6yKxPyuuTb6YDPTX");
    
    NSError *error;
    uint64_t value;
    WSTransactionBuilder *builder;
    WSSignedTransaction *tx;
    
    value = 500000;
    builder = [wallet buildTransactionToAddress:address forValue:value fee:0 error:&error];
    XCTAssertNotNil(builder, @"Unable to build transaction: %@", error);
    tx = [wallet signedTransactionWithBuilder:builder error:&error];
    XCTAssertNotNil(tx, @"Unable to sign transaction: %@", error);
    
    DDLogInfo(@"Tx (fee: %llu): %@", [builder fee], tx);
    
    value = [wallet balance] + 1;
    builder = [wallet buildTransactionToAddress:address forValue:value fee:0 error:&error];
    XCTAssertNil(builder, @"Should fail for insufficient funds");
    
    value = [wallet balance];
    builder = [wallet buildTransactionToAddress:address forValue:value fee:0 error:&error];
    XCTAssertNil(builder, @"Should fail for insufficient funds");
    
    builder = [wallet buildSweepTransactionToAddress:address fee:25000 error:&error];
    XCTAssertNotNil(builder, @"Unable to build wipe transaction: %@", error);
    XCTAssertEqual([builder fee], 25000);
    
    tx = [wallet signedTransactionWithBuilder:builder error:&error];
    XCTAssertNotNil(tx, @"Unable to sign transaction: %@", error);

    DDLogInfo(@"Wipe tx (fee: %llu): %@", [builder fee], tx);
}

- (void)testPublishTransactionSingleInput
{
    WSHDWallet *wallet = [self loadWallet];
    
    NSError *error;
    WSAddress *address = WSAddressFromString(self.networkParameters, @"mnChN9xy1zvyixmkof6yKxPyuuTb6YDPTX");
    const uint64_t value = 100000;

    WSTransactionBuilder *builder = [wallet buildTransactionToAddress:address forValue:value fee:0 error:&error];
    XCTAssertNotNil(builder, @"Unable to build transaction: %@", error);
    XCTAssertEqual([builder fee], 1000);

    WSSignedTransaction *tx = [wallet signedTransactionWithBuilder:builder error:&error];
    XCTAssertNotNil(tx, @"Unable to sign transaction: %@", error);

    DDLogInfo(@"Tx: %@", tx);
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 5;
    [peerGroup startConnections];
    [self runForSeconds:3.0];
    [peerGroup publishTransaction:tx];
    [self runForever];
}

- (void)testPublishTransactionMultipleInputs
{
    WSHDWallet *wallet = [self loadWallet];
    
    NSArray *addresses = @[WSAddressFromString(self.networkParameters, @"mvm26jv7vPUruu9RAgo4fL5ib5ewirdrgR"),  // account 5
                           WSAddressFromString(self.networkParameters, @"n2Rne11pvJBtpVX7KkinPcSs5JJdpLPvaz")]; // account 6
    
    NSArray *values = @[@(120000),
                        @(350000)];
    
    NSMutableArray *txs = [[NSMutableArray alloc] initWithCapacity:2];

    for (NSUInteger i = 0; i < 2; ++i) {
        NSError *error;
        WSTransactionBuilder *builder = [wallet buildTransactionToAddress:addresses[i]
                                                                 forValue:[values[i] unsignedLongLongValue]
                                                                      fee:2500
                                                                    error:&error];

        XCTAssertNotNil(builder, @"Unable to build transaction: %@", error);
        XCTAssertEqual([builder fee], 2500);

        WSSignedTransaction *tx = [wallet signedTransactionWithBuilder:builder error:&error];
        XCTAssertNotNil(tx, @"Unable to sign transaction: %@", error);

        DDLogInfo(@"Tx: %@", tx);
    }
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 5;
    [peerGroup startConnections];
    [self runForSeconds:3.0];
    for (WSSignedTransaction *tx in txs) {
        [peerGroup publishTransaction:tx];
    }
    [self runForever];
}

- (void)testSweep
{
    WSHDWallet *wallet = [self loadWallet];
    
    NSError *error;
    WSAddress *address = WSAddressFromString(self.networkParameters, @"n1tUe8bgzDnyDv8V2P4iSrBUMUxXMX597E");
    WSTransactionBuilder *builder = [wallet buildSweepTransactionToAddress:address fee:0 error:&error];
    XCTAssertNotNil(builder, @"Unable to build transaction: %@", error);

    WSSignedTransaction *tx = [wallet signedTransactionWithBuilder:builder error:&error];
    XCTAssertNotNil(tx, @"Unable to sign transaction: %@", error);
    
    DDLogInfo(@"Tx: %@", tx);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:WSPeerGroupDidRelayTransactionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        WSSignedTransaction *published = note.userInfo[WSPeerGroupRelayTransactionKey];
        const BOOL isPublished = [note.userInfo[WSPeerGroupRelayIsPublishedKey] boolValue];

        if (isPublished && (published == tx)) {
            DDLogInfo(@"Wallet emptied, leaving");
            [self stopRunning];
        }
    }];
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 5;
    [peerGroup startConnections];
    [self runForSeconds:3.0];
    [peerGroup publishTransaction:tx];
    [self runForever];
}

#pragma mark Helpers

- (id<WSBlockStore>)memoryStore
{
    return [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
}

- (WSCoreDataManager *)persistentManager
{
    return [[WSCoreDataManager alloc] initWithPath:[self storePath] error:NULL];
}

- (WSHDWallet *)loadWallet
{
    return [WSHDWallet loadFromPath:[self walletPath] parameters:self.networkParameters seed:[self walletSeed]];
}

- (void)saveWallet:(id<WSWallet>)wallet
{
    NSString *path = [self walletPath];
    if ([wallet saveToPath:path]) {
        DDLogInfo(@"Wallet successfully saved to %@", path);
    }
    else {
        DDLogInfo(@"Failed to save wallet to %@", path);
    }
}

- (NSString *)storePath
{
    return [self mockNetworkPathForFilename:@"DownloadWalletTests" extension:@"sqlite"];
}

- (NSString *)walletPath
{
    return [self mockNetworkPathForFilename:@"DownloadWalletTests" extension:@"wallet"];
}

- (WSSeed *)walletSeed
{
//    // spam blocks around #205000 on testnet + dropped blocks analysis
//    const NSTimeInterval creationTime = WSTimestampFromISODate(@"2014-01-01") - NSTimeIntervalSince1970;
//    const NSTimeInterval creationTime = 1393813869 - NSTimeIntervalSince1970;
    
    const NSTimeInterval creationTime = WSTimestampFromISODate(@"2014-06-02") - NSTimeIntervalSince1970;
//    const NSTimeInterval creationTime = WSTimestampFromISODate(@"2014-07-16") - NSTimeIntervalSince1970;
//    const NSTimeInterval creationTime = 0.0;
    
    return WSSeedMake([self mockWalletMnemonic], creationTime);
}

@end
