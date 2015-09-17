//
//  WSPeerTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 24/06/14.
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

#import <netdb.h>
#import <arpa/inet.h>

#import "XCTestCase+BitcoinSPV.h"
#import "WSConfig.h"
#import "WSBlockChain.h"
#import "WSPeer.h"
#import "WSBlockLocator.h"

@interface WSPeerTests : XCTestCase

@property (nonatomic, strong) WSConnectionPool *pool;
@property (nonatomic, strong) WSPeer *peer;
@property (nonatomic, strong) WSBIP37FilterParameters *bloomFilterParameters;

@end

@implementation WSPeerTests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeTestnet3;

    self.pool = [[WSConnectionPool alloc] initWithParameters:self.networkParameters];
    self.bloomFilterParameters = [[WSBIP37FilterParameters alloc] init];
    self.bloomFilterParameters.falsePositiveRate = WSBlockChainDownloaderDefaultBFRateMin;
    DDLogInfo(@"Bloom filter parameters: %@", self.bloomFilterParameters);

    NSString *dnsSeed = [self.networkParameters dnsSeeds][0];

    DDLogInfo(@"Peers from %@", dnsSeed);
    NSMutableArray *addresses = [[NSMutableArray alloc] init];
    struct hostent *entries = gethostbyname(dnsSeed.UTF8String);
    XCTAssertTrue((entries != NULL) && (entries->h_length > 0), @"Peer lookup failed");
    
    for (int i = 0; entries->h_addr_list[i]; ++i) {
        struct in_addr *addressPtr = (struct in_addr *)entries->h_addr_list[i];
        NSString *host = [NSString stringWithUTF8String:inet_ntoa(*addressPtr)];
        DDLogInfo(@"\t%@", host);

//        const uint32_t address = CFSwapInt32BigToHost(addressPtr->s_addr);
//        [addresses addObject:@(address)];
        [addresses addObject:host];
    }

    NSString *address = addresses[mrand48() % addresses.count];
    address = @"5.9.123.81";
    self.peer = [self.pool openConnectionToPeerHost:address
                                         parameters:self.networkParameters
                                              flags:[[WSPeerFlags alloc] initWithNeedsBloomFiltering:YES]];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testConnection
{
    [self assertPeerMessageSequence:@[[WSMessageVersion class], [WSMessageVerack class]]];
}

- (void)testGetaddr
{
    [self assertPeerHandshake];
    [self.peer sendGetaddr];
    
    WSMessageAddr *message = (WSMessageAddr *)[self assertPeerMessageClass:[WSMessageAddr class] timeout:10.0];
    DDLogInfo(@"Addresses count: %lu", (unsigned long)message.addresses.count);
}

- (void)testGetblocks
{
    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
    WSBlockChain *bc = [[WSBlockChain alloc] initWithStore:store];
    WSBlockLocator *locator = [bc currentLocator];
    WSHash256 *hashStop = nil;
    
    [self assertPeerHandshake];
    [self.peer sendGetblocksMessageWithLocator:locator hashStop:hashStop];

    WSMessageInv *message = (WSMessageInv *)[self assertPeerMessageClass:[WSMessageInv class]];
    DDLogInfo(@"Blocks count: %lu", (unsigned long)message.inventories.count);
    XCTAssertEqual(message.inventories.count, WSMessageBlocksMaxCount, @"Must return maximum blocks from genesis");
}

- (void)testGetheaders
{
//    NSArray *hashes = @[WSHash256FromHex(@"00000000b6293822dd615fb57ad734ad4f13cf460c289eb89910d0c7016e8841")];
//    WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:hashes];
//    WSHash256 *hashStop = WSHash256FromHex(@"00000000a487b2df64e40903d47e2e96b1b9ce4471f491709af15b80a7ec5dd1");
    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
    WSBlockChain *bc = [[WSBlockChain alloc] initWithStore:store];
    WSBlockLocator *locator = [bc currentLocator];
    WSHash256 *hashStop = nil;

    [self assertPeerHandshake];
    [self.peer sendGetheadersMessageWithLocator:locator hashStop:hashStop];

    WSMessageHeaders *message = (WSMessageHeaders *)[self assertPeerMessageClass:[WSMessageHeaders class]];
    DDLogInfo(@"Headers count: %lu", (unsigned long)message.headers.count);
    XCTAssertEqual(message.headers.count, WSMessageHeadersMaxCount, @"Must return maximum headers from genesis");

//    for (NSUInteger i = 0; i < 20; ++i) {
//        id<WSBlockHeader> header = message.blockHeaders[i];
//        DDLogInfo(@"%@", [[header toBuffer] hexString]);
//    }
}

- (void)testGetheadersWith20To40Locator
{
    NSArray *hexes = @[@"00000000ede57f31cc598dc241d129ccb4d8168ef112afbdc870dc60a85f5dd3",
                       @"000000009b3bca4909f38313f2746120129cce4a699a1f552390955da470c5a9",
                       @"000000008d55c3e978639f70af1d2bf1fe6f09cb3143e104405a599215c89a48",
                       @"00000000fe198cce4c8abf9dca0fee1182cb130df966cc428ad2a230df8da743",
                       @"00000000c4cbd75af741f3a2b2ff72d9ed4d83a048462c1efe331be31ccf006b",
                       @"000000009425e151b8bab13f801282ef0f3dcefc55ec4b2e0355e513db4cd328",
                       @"000000006408fcd00d8bb0428b9d2ad872333c317f346f8fee05b538a9913913",
                       @"0000000092c69507e1628a6a91e4e69ea28fe378a1a6a636b9c3157e84c71b78",
                       @"000000004705938332863b772ff732d2d5ac8fe60ee824e37813569bda3a1f00",
                       @"00000000adde5256150e514644c5ec4f81bda990faec90230a2c80a929cae027",
                       @"00000000700e92a916b46b8b91a14d1303d5d91ef0b09eecc3151fb958fd9a2e",
                       @"000000009cbaa1b39a336d3afa300a6d73fab6d81413b2f7965418932a14e2f9",
                       @"000000008b5d0af9ffb1741e38b17b193bd12d7683401cecd2fd94f548b6e5dd",
                       @"00000000b873e79784647a6c82962c70d228557d24a747ea4d1b8bbe878e1206"];
    
    NSMutableArray *hashes = [[NSMutableArray alloc] initWithCapacity:hexes.count];
    for (NSString *hex in hexes) {
        [hashes addObject:WSHash256FromHex(hex)];
    }
    WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:hashes];
    WSHash256 *hashStop = WSHash256FromHex(@"00000000283a18616ffce66d4ae48407aa03ac3bcee847d1b02e9b6c0716f493");

    [self assertPeerHandshake];
    [self.peer sendGetheadersMessageWithLocator:locator hashStop:hashStop];

    WSMessageHeaders *message = (WSMessageHeaders *)[self assertPeerMessageClass:[WSMessageHeaders class]];
    DDLogInfo(@"Headers count: %lu", (unsigned long)message.headers.count);
    XCTAssertEqual(message.headers.count, 20);
}

- (void)testGetheadersInTransition
{
    // retarget transition (44352, 46368 - 1)

//    NSArray *hashes = @[WSHash256FromHex(@"000000003775b96d6b362d4804afe2d9c3cf3cbb46a45c3ccc377c94e83edd23"),      // 44351
//                        WSHash256FromHex(@"000000000f995096c0f2ee2bd0ab173afcbdda6d062378b534f7092b5baa1148")];     // 44352
    
    NSArray *hashes = @[WSHash256FromHex(@"000000000c8693b70842f1e384e12e4e83ecb07163aced213b0fd3300b9701cc"),      // 46366
                        WSHash256FromHex(@"00000000037835a92404acb2f18768a49d4f93685ead30aad6bb3b073f411e02"),      // 46367
                        WSHash256FromHex(@"0000000004483cef8f6aa5ecd991b82943afdfdee406f74bbf5c14eced56a8bf")];     // 46368
    
    WSBlockLocator *locator = [[WSBlockLocator alloc] initWithHashes:hashes];
    
    [self assertPeerHandshake];
    [self.peer sendGetheadersMessageWithLocator:locator hashStop:[hashes lastObject]];
    [self assertPeerMessageClass:[WSMessageHeaders class]];
}

- (void)testGetdataTx
{
    NSArray *txHashes = @[@"24d58bb11efdd86164b4dc8c3fe67d0ab9fff924f2e11492f20f9c0381576c80"];
    NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:txHashes.count];
    for (NSString *hex in txHashes) {
        [inventories addObject:WSInventoryTxFromHex(hex)];
    }
    
    [self assertPeerHandshake];
    [self.peer sendGetdataMessageWithInventories:inventories];
    [self assertPeerMessageClass:[WSMessageNotfound class]];
}

//- (void)testGetdataBlock
//{
////    NSArray *blockHashes = @[@"000000000000cb954e391729b27c5ed4f4ee0712cafe3c2bcffe99d12d6ee536"];
//    NSArray *blockHashes = @[@"00000000b6293822dd615fb57ad734ad4f13cf460c289eb89910d0c7016e8841"]; // contains tx from testPublishTransaction1
//    
//    NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:blockHashes.count];
//    for (NSString *hex in blockHashes) {
//        [inventories addObject:WSInventoryBlock(hex)];
//    }
//
//    [self assertPeerHandshake];
//    [self.peer sendGetdataMessageWithInventories:inventories];
//    [self assertPeerMessageSequence:@[[WSMessageBlock class]]];
//}

- (void)testGetdataFilteredBlockAll
{
    self.networkType = WSNetworkTypeTestnet3;
    
//    NSArray *hashes = @[@"00000000467b46cf63182d0e27b1ce131b126de360f0b192ee1a63616dbb98ee",
//                        @"00000000e49a264880bfdec87f968d23ea8aaff4264becdabe5d90a3242631ed",
//                        @"000000000000df0677697ab96d8baab647b0711b6563965abf3aa84d00d9765c"];
//    NSArray *hashes = @[@"00000000467b46cf63182d0e27b1ce131b126de360f0b192ee1a63616dbb98ee"];
//    NSArray *hashes = @[@"00000000442c8b04081994b98b259a287f50f0bacd078929a07a30cab7173259"];
//    NSArray *hashes = @[@"00000000cfdc9784b99f99adc3ae4070973353274c2466324a26a0ecae4165b5"];
//    NSArray *hashes = @[@"000000000000b42d6863f846942d8a47e532eeb6f326ff56dea6a73e7323b628"]; // output = 2-to-3 multisig
//    NSArray *hashes = @[@"000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943"]; // testnet genesis
//    NSArray *hashes = @[@"000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"]; // mainnet genesis
    NSArray *hashes = @[@"0000000000006a4ac43153c23121f95ce7cced8e18abcf6ece0235e6435472f5"];

    NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:hashes.count];
    for (NSString *hex in hashes) {
        [inventories addObject:WSInventoryFilteredBlockFromHex(hex)];
    }

    [self assertPeerHandshake];
    [self.peer sendGetdataMessageWithInventories:inventories];
//    [self assertPeerMessageSequence:@[[WSMessageMerkleblock class], [WSMessageTx class], [WSMessageTx class]]];
    [self runForever];
}

- (void)testGetdataFilteredBlockWithAddresses
{
    NSArray *receiveAddresses = @[@"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP",
                                  @"mm4Z6thuZxVAYXXVU35KxzirnfFZ7YwszT",
                                  @"mo6oWnaMKDE9Bq2w97p3RWCHAqDiFdyYQH"];
    
    NSArray *changeAddresses = @[@"mgjkgSBEfR2K4XZM1vM5xxYzFfTExsvYc9",
                                 @"mo6HhdAEKnLDivSZjWaeBN7AY26bxo78cT",
                                 @"mkW2kGUwWQmVLEhmhjXZEPpHqhXreYemh1"];
    
    //
    // None, min fp rate (3)
    //
    // 8b84151eaab153071ac2a7b255dc8bcaf2a33d21b9d79874405c15c4a3bcddbb
    // 44adb08ca9a7faec651b3f50e020be7c24702533e1dcc1dde0fa4e056047ba22 (FP)
    // a905b3814244e7710ce5ec696193c4b87111a788a8c0033e1a4b9b4851fa746d
    //
    // None / P2PubKeyOnly, max fp rate (5)
    //
    // 8b84151eaab153071ac2a7b255dc8bcaf2a33d21b9d79874405c15c4a3bcddbb
    // 3300f31b4a4b49ffcf8b8d83ab06301b626c50c8945fea41771b300870991c10 (FP)
    // b740063e669820f0e96082ebd700fc97d798651f9f47a14cd5d2972772f5cc2d (FP)
    // b8e88db0e34b656f588cb7fce945eb27264f61fdcb1fd93f6ea38361ad40a37b (FP)
    // a905b3814244e7710ce5ec696193c4b87111a788a8c0033e1a4b9b4851fa746d
    //

    NSArray *addresses = [receiveAddresses arrayByAddingObjectsFromArray:changeAddresses];
    WSMutableBloomFilter *filter = [[WSMutableBloomFilter alloc] initWithParameters:self.bloomFilterParameters capacity:addresses.count];
    for (NSString *encoded in addresses) {
        [filter insertAddress:WSAddressFromString(self.networkParameters, encoded)];
    }
    
    NSArray *blockHashes = @[@"00000000b6293822dd615fb57ad734ad4f13cf460c289eb89910d0c7016e8841", // contains tx from testPublishTransaction1
                             @"00000000000008ac05a77ab8a82ce8de160fc88307732282e43a47a3f8735fd8"]; // contains tx from testPublishTransaction2
    
    NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:blockHashes.count];
    for (NSString *hex in blockHashes) {
        [inventories addObject:WSInventoryFilteredBlockFromHex(hex)];
    }

    [self assertPeerHandshake];
    [self.peer sendFilterloadMessageWithFilter:filter];
    [self.peer sendGetdataMessageWithInventories:inventories];
    [self assertPeerMessageSequence:@[[WSMessageMerkleblock class], [WSMessageTx class]]];
}

- (void)testGetdataFilteredBlockWithPubKeys
{
    NSArray *pubKeys = @[@"03a10880b8093620696dbf0e8a5948ff94bbdc555b2bf75600a3c1456d795dea0f",
                         @"02ceab68fe2441c3e6f5ffa05c53fe43292cef05462a53021fa359b4bbfdfc27e3",
                         @"02ef3f4addfa59094019df5723264d2e7d53de7fe8465f2c2786fb48651e535a37",
                         @"031f11127e8e21da4ec5a825b0b674b24c502e6f153573e52c4480863f418ebf4c",
                         @"03dea0733eca82690714e3c0ba434d076a107e10ec3b9779a804a028260aeff1d1",
                         @"027f44768224ac279f9bd3ea27ec08c01db2b6ec77b80461ee61c8ce00cd4f5f2e"];
    
    //
    // None, min fp rate (2)
    //
    // 8b84151eaab153071ac2a7b255dc8bcaf2a33d21b9d79874405c15c4a3bcddbb
    // a905b3814244e7710ce5ec696193c4b87111a788a8c0033e1a4b9b4851fa746d
    //

    WSMutableBloomFilter *filter = [[WSMutableBloomFilter alloc] initWithParameters:self.bloomFilterParameters capacity:pubKeys.count];
    for (NSString *encoded in pubKeys) {
        WSPublicKey *pubKey = WSPublicKeyFromHex(encoded);
        [filter insertData:[pubKey data]];
//        [filter insertData:[pubKey hash160]];
    }
    
    NSArray *blockHashes = @[@"00000000b6293822dd615fb57ad734ad4f13cf460c289eb89910d0c7016e8841", // contains tx from testPublishTransaction1
                             @"00000000000008ac05a77ab8a82ce8de160fc88307732282e43a47a3f8735fd8"]; // contains tx from testPublishTransaction2
    
    NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:blockHashes.count];
    for (NSString *hex in blockHashes) {
        [inventories addObject:WSInventoryFilteredBlockFromHex(hex)];
    }

    [self assertPeerHandshake];
    [self.peer sendFilterloadMessageWithFilter:filter];
    [self.peer sendGetdataMessageWithInventories:inventories];
    [self assertPeerMessageSequence:@[[WSMessageMerkleblock class], [WSMessageTx class]]];
}

- (void)testRelevantTransactionsWithSingleAddress
{
    //
    // 1. Blockchain sync fetches all block headers (80 + 1 bytes)
    //
    // 2. Wallet sync fetches ALL filtered blocks starting from wallet creation time
    //    and with its Bloom filter loaded the peer announces relevant transactions
    //    together with filtered blocks. Merkle trees are built from filtered blocks
    //    for verification
    //
    
    //
    // mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP
    //
    // Relevant transactions = 3
    //
    // 6b1201d44406058df8e47e1afe3f5f8f9200449c18cfcb2def7beb3b2fbb7465 =  +20000000 (balance: 20000000)
    // 24d58bb11efdd86164b4dc8c3fe67d0ab9fff924f2e11492f20f9c0381576c80 =  -20000000 (balance: 19866544)
    // a905b3814244e7710ce5ec696193c4b87111a788a8c0033e1a4b9b4851fa746d =   +6619000 (balance: 19857000)
    //

    NSArray *pubKeys = @[@"03a10880b8093620696dbf0e8a5948ff94bbdc555b2bf75600a3c1456d795dea0f"];

    NSArray *relevantBlockHashes = @[@"00000000000008ac05a77ab8a82ce8de160fc88307732282e43a47a3f8735fd8",
                                     @"000000000000cb954e391729b27c5ed4f4ee0712cafe3c2bcffe99d12d6ee536",
                                     @"00000000ccc899426a9fa292038e1459db72b140d063ca24bf5598f57129173f"];

    const int FILTER_MATCH_PUBKEY = 1;
    const int FILTER_MATCH_ADDRESS = 2;
    const int FILTER_MATCH_PUBKEY_ADDRESS = 3;

//    const int FILTER_MATCH = FILTER_MATCH_PUBKEY;
    const int FILTER_MATCH = FILTER_MATCH_PUBKEY_ADDRESS;

    NSMutableArray *filterElements = [[NSMutableArray alloc] init];
    
    /////////////////////////////////////////
    //
    // PUBKEY
    //
    // 1/3 relevant, 0/2 FP (0%)
    //
    // 24d58bb11efdd86164b4dc8c3fe67d0ab9fff924f2e11492f20f9c0381576c80 (sending)
    //
    /////////////////////////////////////////

    if (FILTER_MATCH == FILTER_MATCH_PUBKEY) {
        for (NSString *encoded in pubKeys) {
            WSPublicKey *pubKey = WSPublicKeyFromHex(encoded);
            [filterElements addObject:[pubKey data]];
        }
    }

    /////////////////////////////////////////
    //
    // ADDRESS
    //
    // 2/3 relevant, 0/2 FP (0%)
    //
    // a905b3814244e7710ce5ec696193c4b87111a788a8c0033e1a4b9b4851fa746d (receiving)
    // 6b1201d44406058df8e47e1afe3f5f8f9200449c18cfcb2def7beb3b2fbb7465 (receiving)
    //
    /////////////////////////////////////////

    else if (FILTER_MATCH == FILTER_MATCH_ADDRESS) {
        for (NSString *encoded in pubKeys) {
            WSPublicKey *pubKey = WSPublicKeyFromHex(encoded);
            [filterElements addObject:[pubKey hash160]];
        }
    }
    
    /////////////////////////////////////////
    //
    // PUBKEY + ADDRESS
    //
    // 3/3 relevant, 0/3 FP (0%)
    //
    // a905b3814244e7710ce5ec696193c4b87111a788a8c0033e1a4b9b4851fa746d
    // 24d58bb11efdd86164b4dc8c3fe67d0ab9fff924f2e11492f20f9c0381576c80
    // 6b1201d44406058df8e47e1afe3f5f8f9200449c18cfcb2def7beb3b2fbb7465
    //
    /////////////////////////////////////////
    
    else if (FILTER_MATCH == FILTER_MATCH_PUBKEY_ADDRESS) {
        for (NSString *encoded in pubKeys) {
            WSPublicKey *pubKey = WSPublicKeyFromHex(encoded);
            [filterElements addObject:[pubKey data]];
            [filterElements addObject:[pubKey hash160]];
        }
    }

    WSMutableBloomFilter *filter = [[WSMutableBloomFilter alloc] initWithParameters:self.bloomFilterParameters capacity:filterElements.count];
    for (NSData *element in filterElements) {
        [filter insertData:element];
    }

    NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:relevantBlockHashes.count];
    for (NSString *hex in relevantBlockHashes) {
        [inventories addObject:WSInventoryFilteredBlockFromHex(hex)];
    }

    [self assertPeerHandshake];
    [self.peer sendFilterloadMessageWithFilter:filter];
    [self.peer sendGetdataMessageWithInventories:inventories];
    [self assertPeerMessageSequence:@[[WSMessageMerkleblock class], [WSMessageTx class]]];
}

- (void)testRelevantTransactionsWithWallet
{
    //
    // Relevant transactions = 4
    //
    // 6b1201d44406058df8e47e1afe3f5f8f9200449c18cfcb2def7beb3b2fbb7465 = 20000000
    // 24d58bb11efdd86164b4dc8c3fe67d0ab9fff924f2e11492f20f9c0381576c80 = 19866544
    // 8b84151eaab153071ac2a7b255dc8bcaf2a33d21b9d79874405c15c4a3bcddbb = 19860000
    // a905b3814244e7710ce5ec696193c4b87111a788a8c0033e1a4b9b4851fa746d = 19857000
    //

    WSSeed *seed = WSSeedMakeNow([self mockWalletMnemonic]);
    WSHDWallet *wallet = [[WSHDWallet alloc] initWithParameters:self.networkParameters seed:seed];

    DDLogInfo(@"Wallet receive addresses: %@", wallet.allReceiveAddresses);
    DDLogInfo(@"Wallet change addresses: %@", wallet.allChangeAddresses);

    WSBloomFilter *filter = [wallet bloomFilterWithParameters:self.bloomFilterParameters];

    NSArray *relevantBlockHashes = @[@"00000000000008ac05a77ab8a82ce8de160fc88307732282e43a47a3f8735fd8",
                                     @"000000000000cb954e391729b27c5ed4f4ee0712cafe3c2bcffe99d12d6ee536",
                                     @"00000000ccc899426a9fa292038e1459db72b140d063ca24bf5598f57129173f",
                                     @"00000000b6293822dd615fb57ad734ad4f13cf460c289eb89910d0c7016e8841"];

    NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:relevantBlockHashes.count];
    for (NSString *hex in relevantBlockHashes) {
        [inventories addObject:WSInventoryFilteredBlockFromHex(hex)];
    }
    
    [self assertPeerHandshake];
    [self.peer sendFilterloadMessageWithFilter:filter];
    [self.peer sendGetdataMessageWithInventories:inventories];
    [self assertPeerMessageSequence:@[[WSMessageMerkleblock class], [WSMessageTx class]]];

    // wait to get all data
    [self runForSeconds:3.0];
}

- (void)testPublishTransaction1
{
    WSTransactionOutPoint *unspent = [WSTransactionOutPoint outpointWithParameters:self.networkParameters txId:WSHash256FromHex(@"24d58bb11efdd86164b4dc8c3fe67d0ab9fff924f2e11492f20f9c0381576c80") index:1];
    WSAddress *previousAddress = WSAddressFromString(self.networkParameters, @"mgjkgSBEfR2K4XZM1vM5xxYzFfTExsvYc9");
    WSKey *previousKey = WSKeyFromWIF(self.networkParameters, @"cQukrUmHpU3Wp4qMr1ziAL6ztr3r8bvdhNJ5mGAq8wnmAMscYZid");
    const uint64_t previousValue = 19866544;
    WSTransactionOutput *previousOutput = [[WSTransactionOutput alloc] initWithAddress:previousAddress value:previousValue];
    WSAddress *outputAddress = WSAddressFromString(self.networkParameters, @"myxg6ABN2yr5yZ1fJScMwN566TuGbQpqDg");
    WSAddress *changeAddress = WSAddressFromString(self.networkParameters, @"mo6HhdAEKnLDivSZjWaeBN7AY26bxo78cT");

    const uint64_t outputValue = 5544;
    const uint64_t expFee = 1000;
    const uint64_t changeValue = previousValue - outputValue - expFee;
    
    WSTransactionBuilder *builder = [[WSTransactionBuilder alloc] init];
    [builder addSignableInput:[[WSSignableTransactionInput alloc] initWithPreviousOutput:previousOutput outpoint:unspent]];
    [builder addOutput:[[WSTransactionOutput alloc] initWithAddress:outputAddress value:outputValue]];
    [builder addOutput:[[WSTransactionOutput alloc] initWithAddress:changeAddress value:changeValue]];

//    WSBuffer *signable = [tx.inputs[0] signableBufferForTransaction:tx];
//    DDLogInfo(@"Tx (signable): %@", [signable.data hexString]);

    NSDictionary *inputKeys = @{[previousKey addressWithParameters:self.networkParameters]: previousKey};

//    uint64_t fee;
    NSError *error;
    WSSignedTransaction *tx = [builder signedTransactionWithInputKeys:inputKeys error:&error];
//    XCTAssertTrue([tx verifyWithEffectiveFee:&fee error:&error], @"Invalid tx: %@", error);
//    XCTAssertEqual(fee, expFee);
    XCTAssertEqual(tx.size, 226);

    NSString *txHex = [[tx toBuffer] hexString];
    NSString *expTxHex = @"0100000001806c5781039c0ff29214e1f224f9ffb90a7de63f8cdcb46461d8fd1eb18bd524010000006b4830450221008f2afef578ce0119e7389656254482204a4d67556e8ecf55284c5db57959b610022002afe71fc51fd67480d9d45f82d4839a61773bf09aee6c61126dd97f64dfa0c4012102ceab68fe2441c3e6f5ffa05c53fe43292cef05462a53021fa359b4bbfdfc27e3ffffffff02a8150000000000001976a914ca4f8d42241a5ba8d4947ea767b2761c1a74dbff88ac200a2f01000000001976a9145316ce8e4614948c6bd49ee1c48b7bbf90d5fb7488ac00000000";
    DDLogInfo(@"Tx hex  : %@", txHex);
    DDLogInfo(@"Expected: %@", expTxHex);
    XCTAssertEqualObjects(txHex, expTxHex, @"Transaction body");
    
    DDLogInfo(@"Tx: %@", tx);
    WSHash256 *txId = tx.txId;
    WSHash256 *expTxId = WSHash256FromHex(@"8b84151eaab153071ac2a7b255dc8bcaf2a33d21b9d79874405c15c4a3bcddbb");
    XCTAssertEqualObjects(txId, expTxId, @"Transaction ID");

//    [self.pool openConnections];
//    [self runForSeconds:2.0];
//    [self.peer sendMessage:[WSMessageTx messageWithTransaction:tx]];
//    [self runForever];
}

- (void)testPublishTransaction2
{
    WSTransactionOutPoint *unspent = [WSTransactionOutPoint outpointWithParameters:self.networkParameters txId:WSHash256FromHex(@"8b84151eaab153071ac2a7b255dc8bcaf2a33d21b9d79874405c15c4a3bcddbb") index:1];
    WSAddress *previousAddress = WSAddressFromString(self.networkParameters, @"mo6HhdAEKnLDivSZjWaeBN7AY26bxo78cT");
    WSKey *previousKey = WSKeyFromWIF(self.networkParameters, @"cNnLnY3ZfpCQ2dF22uAVaYsyxXQGHBHRVg2y9NgWgn95i5xb9XFK");
    const uint64_t previousValue = 19860000;
    WSTransactionOutput *previousOutput = [[WSTransactionOutput alloc] initWithAddress:previousAddress value:previousValue];

    NSArray *outputAddresses = @[@"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP",
                                 @"mm4Z6thuZxVAYXXVU35KxzirnfFZ7YwszT",
                                 @"mo6oWnaMKDE9Bq2w97p3RWCHAqDiFdyYQH"];
    
    const uint64_t expFee = 3000;
    const uint64_t totalOutputValue = previousValue - expFee;
    const uint64_t outputValue = totalOutputValue / outputAddresses.count;
    
    WSTransactionBuilder *builder = [[WSTransactionBuilder alloc] init];
    [builder addSignableInput:[[WSSignableTransactionInput alloc] initWithPreviousOutput:previousOutput outpoint:unspent]];
    for (NSString *encoded in outputAddresses) {
        [builder addOutput:[[WSTransactionOutput alloc] initWithAddress:WSAddressFromString(self.networkParameters, encoded) value:outputValue]];
    }
    
//    WSBuffer *signable = [tx.inputs[0] signableBufferForTransaction:tx];
//    DDLogInfo(@"Tx (signable): %@", [signable.data hexString]);
    
    NSDictionary *inputKeys = @{[previousKey addressWithParameters:self.networkParameters]: previousKey};

//    uint64_t fee;
    NSError *error;
    WSSignedTransaction *tx = [builder signedTransactionWithInputKeys:inputKeys error:&error];
//    XCTAssertTrue([tx verifyWithEffectiveFee:&fee error:&error], @"Invalid tx: %@", error);
//    XCTAssertEqual(fee, expFee);
    XCTAssertEqual(tx.size, 260);
    
    NSString *txHex = [[tx toBuffer] hexString];
    NSString *expTxHex = @"0100000001bbddbca3c4155c407498d7b9213da3f2ca8bdc55b2a7c21a0753b1aa1e15848b010000006b483045022100a5a48d98adec77ff6897107be31d9a1761cf17bfad0c886465200ec3bfa7f8e90220087c6736184088e02dc73c8cad833f5de7d82e66b7ad10e034c82f964a3011c50121031f11127e8e21da4ec5a825b0b674b24c502e6f153573e52c4480863f418ebf4cffffffff0378ff6400000000001976a914bf49c258def640bb8a4860384f277379e3be92c288ac78ff6400000000001976a9143cd29461eb29bdb48c90651896b4ab00f00da11488ac78ff6400000000001976a914532fb190ec8296cb55afe6e422b443fea4650d4788ac00000000";
    DDLogInfo(@"Tx hex  : %@", txHex);
    DDLogInfo(@"Expected: %@", expTxHex);
    XCTAssertEqualObjects(txHex, expTxHex, @"Transaction body");
    
    DDLogInfo(@"Tx: %@", tx);
    WSHash256 *txId = tx.txId;
    WSHash256 *expTxId = WSHash256FromHex(@"a905b3814244e7710ce5ec696193c4b87111a788a8c0033e1a4b9b4851fa746d");
    XCTAssertEqualObjects(txId, expTxId, @"Transaction ID");
    
//    [self.pool openConnections];
//    [self runForSeconds:2.0];
//    [self.peer sendMessage:[WSMessageTx messageWithTransaction:tx]];
//    [self runForever];
}

#pragma mark Helpers

- (id<WSMessage>)assertPeerMessageClass:(Class)clazz
{
    return [self assertPeerMessageClass:clazz timeout:3.0];
}

- (id<WSMessage>)assertPeerMessageClass:(Class)clazz timeout:(NSTimeInterval)timeout
{
    return [super assertMessageSequenceForPeer:self.peer expectedClasses:@[clazz] timeout:timeout];
}

- (id<WSMessage>)assertPeerMessageSequence:(NSArray *)sequence
{
    return [super assertMessageSequenceForPeer:self.peer expectedClasses:sequence timeout:3.0];
}

- (id<WSMessage>)assertPeerHandshake
{
    return [self assertPeerMessageSequence:@[[WSMessageVersion class], [WSMessageVerack class], [WSMessagePing class]]];
}

@end
