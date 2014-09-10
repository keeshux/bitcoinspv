//
//  WSWalletNetworkTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 20/07/14.
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

#import "XCTestCase+WaSPV.h"
#import "WSPeerGroup.h"
#import "WSPeer.h"
#import "WSConnectionPool.h"
#import "WSCoreDataManager.h"
#import "WSMemoryBlockStore.h"
#import "WSCoreDataBlockStore.h"
#import "WSSeed.h"
#import "WSHDWallet.h"
#import "WSTransaction.h"
#import "WSStorableBlock.h"

#define WALLET_GAP_LIMIT            10

@interface WSWalletNetworkTests : XCTestCase

@property (nonatomic, copy) NSString *storeMainPath;
@property (nonatomic, copy) NSString *storeTestPath;
@property (nonatomic, copy) NSString *walletMainPath;
@property (nonatomic, copy) NSString *walletTestPath;
@property (nonatomic, copy) NSString *seedPhrase;
@property (nonatomic, strong) id<WSBlockStore> currentStore;
@property (nonatomic, strong) NSString *currentWalletPath;
@property (nonatomic, assign) volatile BOOL stopOnSync;

- (id<WSBlockStore>)networkStore;
- (NSString *)networkWalletPath;
- (WSHDWallet *)loadWalletFromCurrentPath;
- (void)saveWallet:(id<WSWallet>)wallet;

@end

@implementation WSWalletNetworkTests

- (void)setUp
{
    [super setUp];

    self.storeMainPath = [self mockPathForFile:@"WalletNetworkTests-Main.sqlite"];
    self.storeTestPath = [self mockPathForFile:@"WalletNetworkTests-Test3.sqlite"];
    self.walletMainPath = [self mockPathForFile:@"WalletNetworkTests-Main.wallet"];
    self.walletTestPath = [self mockPathForFile:@"WalletNetworkTests-Test3.wallet"];
    self.seedPhrase = [self mockWalletMnemonic];

//    [[NSNotificationCenter defaultCenter] addObserverForName:WSPeerGroupDidDownloadBlockNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
//        WSStorableBlock *block = note.userInfo[WSPeerGroupDownloadBlockKey];
//
//        DDLogInfo(@"Downloaded block: %@", block);
//    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:WSPeerGroupDidFinishDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {

        // XXX
        id<WSWallet> wallet = [note.object valueForKey:@"wallet"];
        [self saveWallet:wallet];
        
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
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    self.currentStore = [self networkStore];
    self.currentWalletPath = [self networkWalletPath];
    self.stopOnSync = YES;

    WSHDWallet *wallet = [self loadWalletFromCurrentPath];
    if (!wallet) {
        wallet = [[WSHDWallet alloc] initWithSeed:[self newWalletSeed] gapLimit:WALLET_GAP_LIMIT];
        [wallet saveToPath:self.currentWalletPath];
        wallet.shouldAutosave = YES;
    }
    
    DDLogInfo(@"Receive address: %@", [wallet receiveAddress]);
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.currentStore wallet:wallet];
    peerGroup.maxConnections = 5;
    peerGroup.shouldDisconnectOnEnterBackground = YES;
    peerGroup.shouldReconnectOnBecomeActive = YES;
    [peerGroup startConnections];
    [peerGroup startBlockChainDownload];
    
    [self runForever];
}

- (void)testChain
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);

    self.currentStore = [self networkStore];
    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:self.currentStore];
    
    DDLogInfo(@"Blockchain: %@", [chain descriptionWithMaxBlocks:50]);
}

- (void)testWallet
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    self.currentStore = [self networkStore];
    self.currentWalletPath = [self networkWalletPath];
    WSHDWallet *wallet = [self loadWalletFromCurrentPath];

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
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    self.currentStore = [self networkStore];
    self.currentWalletPath = [self networkWalletPath];
    WSHDWallet *wallet = [self loadWalletFromCurrentPath];

    WSAddress *address = WSAddressFromString(@"mnChN9xy1zvyixmkof6yKxPyuuTb6YDPTX");
    
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
    
    builder = [wallet buildWipeTransactionToAddress:address fee:25000 error:&error];
    XCTAssertNotNil(builder, @"Unable to build wipe transaction: %@", error);
    XCTAssertEqual([builder fee], 25000);
    
    tx = [wallet signedTransactionWithBuilder:builder error:&error];
    XCTAssertNotNil(tx, @"Unable to sign transaction: %@", error);

    DDLogInfo(@"Wipe tx (fee: %llu): %@", [builder fee], tx);
}

- (void)testPublishTransactionSingleInput
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    self.currentStore = [self networkStore];
    self.currentWalletPath = [self networkWalletPath];
    WSHDWallet *wallet = [self loadWalletFromCurrentPath];
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.currentStore wallet:wallet];
    peerGroup.maxConnections = 2;
    [peerGroup startConnections];
    [peerGroup startBlockChainDownload];
    
    NSError *error;
    WSAddress *address = WSAddressFromString(@"mnChN9xy1zvyixmkof6yKxPyuuTb6YDPTX");
    const uint64_t value = 100000;

    WSTransactionBuilder *builder = [wallet buildTransactionToAddress:address forValue:value fee:0 error:&error];
    XCTAssertNotNil(builder, @"Unable to build transaction: %@", error);
    XCTAssertEqual([builder fee], 1000);

    WSSignedTransaction *tx = [wallet signedTransactionWithBuilder:builder error:&error];
    XCTAssertNotNil(tx, @"Unable to sign transaction: %@", error);

    DDLogInfo(@"Tx: %@", tx);
    
    [self runForSeconds:3.0];

    [peerGroup publishTransaction:tx];
    
    [self runForever];
}

- (void)testPublishTransactionMultipleInputs
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    self.currentStore = [self networkStore];
    self.currentWalletPath = [self networkWalletPath];
    WSHDWallet *wallet = [self loadWalletFromCurrentPath];
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.currentStore wallet:wallet];
    peerGroup.maxConnections = 2;
    [peerGroup startConnections];
    [peerGroup startBlockChainDownload];

    NSArray *addresses = @[WSAddressFromString(@"mvm26jv7vPUruu9RAgo4fL5ib5ewirdrgR"),  // account 5
                           WSAddressFromString(@"n2Rne11pvJBtpVX7KkinPcSs5JJdpLPvaz")]; // account 6
    
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
    
    [self runForSeconds:3.0];

    for (WSSignedTransaction *tx in txs) {
        [peerGroup publishTransaction:tx];
    }
    
    [self runForever];
}

- (void)testWipe
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);

    self.currentStore = [self networkStore];
    self.currentWalletPath = [self networkWalletPath];
    WSHDWallet *wallet = [self loadWalletFromCurrentPath];
    
    NSError *error;
    WSAddress *address = WSAddressFromString(@"n1tUe8bgzDnyDv8V2P4iSrBUMUxXMX597E");
    WSTransactionBuilder *builder = [wallet buildWipeTransactionToAddress:address fee:0 error:&error];
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
    
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.currentStore wallet:wallet];
    peerGroup.maxConnections = 5;
    [peerGroup startConnections];
    [peerGroup startBlockChainDownload];
    
    [self runForSeconds:2.0];
    [peerGroup publishTransaction:tx];
    [self runForever];
}

#pragma mark Helpers

- (id<WSBlockStore>)networkStore
{
    NSString *path = nil;
    if (WSParametersGetCurrentType() == WSParametersTypeMain) {
        path = self.storeMainPath;
    }
    else {
        path = self.storeTestPath;
    }
    WSCoreDataManager *manager = [[WSCoreDataManager alloc] initWithPath:path error:NULL];
    return [[WSCoreDataBlockStore alloc] initWithManager:manager];
}

- (NSString *)networkWalletPath
{
    NSString *path = nil;
    if (WSParametersGetCurrentType() == WSParametersTypeMain) {
        path = self.walletMainPath;
    }
    else {
        path = self.walletTestPath;
    }
    return path;
}

- (WSSeed *)newWalletSeed
{
    const NSTimeInterval creationTime = WSTimestampFromISODate(@"2014-06-02") - NSTimeIntervalSince1970;
//    const NSTimeInterval creationTime = WSTimestampFromISODate(@"2014-07-16") - NSTimeIntervalSince1970;
//    const NSTimeInterval creationTime = 0.0;

    return WSSeedMake(self.seedPhrase, creationTime);
}

- (WSHDWallet *)loadWalletFromCurrentPath
{
    return [WSHDWallet loadFromPath:self.currentWalletPath mnemonic:self.seedPhrase];
}

- (void)saveWallet:(id<WSWallet>)wallet
{
    if ([wallet saveToPath:self.currentWalletPath]) {
        DDLogInfo(@"Wallet successfully saved to %@", self.currentWalletPath);
    }
    else {
        DDLogInfo(@"Failed to save wallet to %@", self.currentWalletPath);
    }
}

@end
