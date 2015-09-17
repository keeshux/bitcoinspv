//
//  WSBlockChainTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 02/07/14.
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
#import "WSBlockLocator.h"
#import "WSFilteredBlock.h"
#import "WSBlockChain.h"
#import "WSStorableBlock+BlockChain.h"

static WSBlockHeader *WSMakeDummyHeader(WSParameters *networkParameters, WSHash256 *blockId, WSHash256 *previousBlockId, NSUInteger work);
static NSOrderedSet *WSMakeDummyTransactions(WSParameters *networkParameters, WSHash256 *blockId);

@interface WSBlockChainTests : XCTestCase <WSBlockChainDelegate>

@property (nonatomic, strong) WSHDWallet *wallet;

@end

@implementation WSBlockChainTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testHead
{
    self.networkType = WSNetworkTypeTestnet3;
    
    WSBlockChain *chain = [self chainWithLocalHeaders];
    WSHash256 *headId = WSHash256FromHex(@"00000000ede57f31cc598dc241d129ccb4d8168ef112afbdc870dc60a85f5dd3");
    XCTAssertEqualObjects(headId, chain.head.blockId);
}

- (void)testIds
{
    self.networkType = WSNetworkTypeTestnet3;
    
    NSArray *expIds = @[@"00000000ede57f31cc598dc241d129ccb4d8168ef112afbdc870dc60a85f5dd3",
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
                        @"0000000050ff3053ada24e6ad581fa0295297f20a2747d034997ffc899aa931e",
                        @"000000009cbaa1b39a336d3afa300a6d73fab6d81413b2f7965418932a14e2f9",
                        @"00000000e29e3aa65f3d12440eac9081844c464aeba7c6e6121dfc8ac0c02ba6",
                        @"000000006633685edce4fa4d8f12d001781c6849837d1632c4e2dd6ff2090a7b",
                        @"00000000bc45ac875fbd34f43f7732789b6ec4e8b5974b4406664a75d43b21a1",
                        @"000000008b5d0af9ffb1741e38b17b193bd12d7683401cecd2fd94f548b6e5dd",
                        @"000000008b896e272758da5297bcd98fdc6d97c9b765ecec401e286dc1fdbe10",
                        @"000000006c02c8ea6e4ff69651f7fcde348fb9d557a06e6957b65552002a7820",
                        @"00000000b873e79784647a6c82962c70d228557d24a747ea4d1b8bbe878e1206",
                        @"000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943"];

    WSBlockChain *chain = [self chainWithLocalHeaders];
    NSArray *hashes = [chain allBlockIds];
    NSMutableArray *expHashes = [[NSMutableArray alloc] initWithCapacity:expIds.count];
    for (NSString *hex in expIds) {
        [expHashes addObject:WSHash256FromHex(hex)];
    }
    DDLogInfo(@"Ids (head first): %@", hashes);
    XCTAssertEqualObjects(hashes, expHashes);
}

- (void)testPrevious
{
    self.networkType = WSNetworkTypeTestnet3;

    WSBlockChain *chain = [self chainWithLocalHeaders];
    WSStorableBlock *block = nil;
    WSStorableBlock *previousBlock = nil;

    block = chain.head;
    DDLogInfo(@"Block: %@", block.blockId);
    XCTAssertEqualObjects(block.blockId, WSHash256FromHex(@"00000000ede57f31cc598dc241d129ccb4d8168ef112afbdc870dc60a85f5dd3"));

    block = [block previousBlockInChain:chain maxStep:3 lastPreviousBlock:&previousBlock];
    DDLogInfo(@"Block: %@", block.blockId);
    XCTAssertEqualObjects(block.blockId, WSHash256FromHex(@"00000000fe198cce4c8abf9dca0fee1182cb130df966cc428ad2a230df8da743"));
    DDLogInfo(@"Last previous block: %@", previousBlock.blockId);
    XCTAssertEqualObjects(previousBlock.blockId, WSHash256FromHex(@"000000008d55c3e978639f70af1d2bf1fe6f09cb3143e104405a599215c89a48"));

    block = [block previousBlockInChain:chain maxStep:10 lastPreviousBlock:NULL];
    XCTAssertEqualObjects(block.blockId, WSHash256FromHex(@"00000000e29e3aa65f3d12440eac9081844c464aeba7c6e6121dfc8ac0c02ba6"));

    block = [block previousBlockInChain:chain maxStep:10000 lastPreviousBlock:&previousBlock];
    XCTAssertEqualObjects(block, nil);
    XCTAssertEqualObjects(previousBlock.blockId, WSHash256FromHex(@"000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943"));
}

- (void)testEmptyLocator
{
    self.networkType = WSNetworkTypeTestnet3;

    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:store];
    WSBlockLocator *locator = [chain currentLocator];

    DDLogInfo(@"Locator: %@", locator);
    XCTAssertEqualObjects([locator.hashes lastObject], [self.networkParameters genesisBlockId]);
}

- (void)testLocator
{
    self.networkType = WSNetworkTypeTestnet3;

    NSArray *expHashes = @[@"00000000ede57f31cc598dc241d129ccb4d8168ef112afbdc870dc60a85f5dd3",
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
                           @"000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943"];

    WSBlockChain *chain = [self chainWithLocalHeaders];
    WSBlockLocator *locator = [chain currentLocator];
    DDLogInfo(@"Locator: %@", locator);

    NSMutableArray *hashes = [[NSMutableArray alloc] initWithCapacity:locator.hashes.count];
    for (WSHash256 *hash in locator.hashes) {
        [hashes addObject:[hash description]];
    }
    XCTAssertEqualObjects(hashes, expHashes);
}

- (void)testWork
{
    self.networkType = WSNetworkTypeTestnet3;

    NSArray *expWork = @[@"90195689493",
                         @"85900656660",
                         @"81605623827",
                         @"77310590994",
                         @"73015558161",
                         @"68720525328",
                         @"64425492495",
                         @"60130459662",
                         @"55835426829",
                         @"51540393996",
                         @"47245361163",
                         @"42950328330",
                         @"38655295497",
                         @"34360262664",
                         @"30065229831",
                         @"25770196998",
                         @"21475164165",
                         @"17180131332",
                         @"12885098499",
                         @"8590065666",
                         @"4295032833"];

    WSBlockChain *chain = [self chainWithLocalHeaders];
    WSStorableBlock *block = chain.head;
    
    NSMutableArray *work = [[NSMutableArray alloc] initWithCapacity:(1 + chain.currentHeight)];
    while (block) {
        [work addObject:block.workString];
        block = [block previousBlockInChain:chain];
    }

    XCTAssertEqualObjects(work, expWork);
}

- (void)testFilteredBlocks
{
    self.networkType = WSNetworkTypeTestnet3;

    // filtered block #21
    NSString *hex = @"01000000d35d5fa860dc70c8bdaf12f18e16d8b4cc29d141c28d59cc317fe5ed00000000507dae091a9657b6c073863ca71ba6989a2cf4417fb81e940668568a35d34a7119ec494dffff001d00effec30100000001507dae091a9657b6c073863ca71ba6989a2cf4417fb81e940668568a35d34a710101";
    
    WSFilteredBlock *block = WSFilteredBlockFromHex(self.networkParameters, hex);
    WSBlockChain *chain = [self chainWithLocalHeaders];
    [chain addBlockWithHeader:block.header transactions:nil location:NULL connectedOrphans:NULL reorganizeBlock:NULL error:NULL];
    XCTAssertEqual(chain.currentHeight, 21);

    DDLogInfo(@"BlockChain: %@", chain);
}

- (void)testReplace
{
    self.networkType = WSNetworkTypeTestnet3;

    WSBlockHeader *header = WSBlockHeaderFromHex(self.networkParameters, @"01000000a9c570a45d959023551f9a694ace9c12206174f21383f30949ca3b9b00000000eaf93dbbfb3551a1ff8b6bd5ba4cea7508e790c23cd07b9d9e791936a79d5fd4b3eb494dffff001d0385a7dd00");
    WSSignedTransaction *transaction = WSTransactionFromHex(self.networkParameters, @"0100000002c60c5a1d539c43101b0d4d36fce86941d132d126670320a02cfeb55d733de76e01000000fdfe00004830450220514685bdf8388e969bb19bdeff8be23cfbb346f096551ed7a9d919f4031881c5022100e5fd38b24c932fcade093c73216c7227aa5acd7c2619b7e6369de3269cf2c3a001483045022052ef60dc14532da93fa7acb82c897daf4d2ac56ddad779dff9f8519453484be5022100e6741933963ec1c09f41fc06bd48cc109d3647655cbfcbabafb5b2dea88dfcf8014c6952210387e679718c6a67f4f2c25a0b58df70067ec9f90c4297368e24fd5342027bec8521034a9ccd9aca88aa9d20c73289a075392e1cd67a5f33938a0443f530afa3675fcd21035bdd8633818888875bbc4232d384b411dc67f4efe11e6582de52d196adc6d29a53aeffffffff0efe1d2b69d50fc4271ac76671ac3f549617bde1cab71c715212fb062030725401000000fd000100493046022100bddd0d72c54fce23718d4450720e60a90d6c7c50af1c3caeb25dd49228a7233a022100c905f4bb5c624d594dbb364ffbeffc1f9e8ab72dac297b2f8fb1f07632fdf52801493046022100f8ff9b9fd434bf018c21725047b0205c4ab70bcc999c625c8c5573a836d7b525022100a7cfc4f741386c1b22d0e2a994139f52961d86d51332fc03d117bb422abb9123014c6952210387e679718c6a67f4f2c25a0b58df70067ec9f90c4297368e24fd5342027bec8521034a9ccd9aca88aa9d20c73289a075392e1cd67a5f33938a0443f530afa3675fcd2103082587f27afa0481c6af0e75bead2daabdd0ac17395563bd9282ed6ca00025db53aeffffffff0230cd23f7000000001976a91469611d4ddff939f5ef553f020ba3ba0f1d1d76d688ac032700000000000017a91431ecbf82d5dac9ec751e450fc38f098e3d630cb68700000000");
    WSStorableBlock *block;
    
    WSBlockChain *chain = [self chainWithLocalHeaders];
    block = [chain addBlockWithHeader:header transactions:nil location:NULL connectedOrphans:NULL reorganizeBlock:NULL error:NULL];
    XCTAssertNil(block);
    block = [chain addBlockWithHeader:header transactions:[NSOrderedSet orderedSetWithObject:transaction] location:NULL connectedOrphans:NULL reorganizeBlock:NULL error:NULL];
    XCTAssertNotNil(block);
    
    DDLogInfo(@"BlockChain: %@", chain);
}

// transactions reorg needs BSPV_TEST_DUMMY_TXS (sure?)
- (void)testReorganize
{
    self.networkType = WSNetworkTypeTestnet3;
    
    WSHash256 *G = [self.networkParameters genesisBlockId];
    WSHash256 *H1 = WSHash256FromHex(@"1111111111111111111111111111111111111111111111111111111111111111");
    WSHash256 *H2 = WSHash256FromHex(@"2222222222222222222222222222222222222222222222222222222222222222");
    WSHash256 *H3 = WSHash256FromHex(@"3333333333333333333333333333333333333333333333333333333333333333");
    WSHash256 *H4 = WSHash256FromHex(@"4444444444444444444444444444444444444444444444444444444444444444");
    WSHash256 *H5 = WSHash256FromHex(@"5555555555555555555555555555555555555555555555555555555555555555");
    WSHash256 *H6 = WSHash256FromHex(@"6666666666666666666666666666666666666666666666666666666666666666");
    WSHash256 *H7 = WSHash256FromHex(@"7777777777777777777777777777777777777777777777777777777777777777");
    WSHash256 *H8 = WSHash256FromHex(@"8888888888888888888888888888888888888888888888888888888888888888");
    WSHash256 *H9 = WSHash256FromHex(@"9999999999999999999999999999999999999999999999999999999999999999");
    WSHash256 *HA = WSHash256FromHex(@"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
//    WSHash256 *HB = WSHash256FromHex(@"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
//    WSHash256 *HC = WSHash256FromHex(@"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc");
//    WSHash256 *HD = WSHash256FromHex(@"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd");
//    WSHash256 *HE = WSHash256FromHex(@"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee");

    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
//    WSCoreDataManager *manager = [[WSCoreDataManager alloc] initWithPath:[self mockPathForFile:@"BlockChainTests-Reorganize.sqlite"] error:NULL];
//    id<WSBlockStore> store = [[WSCoreDataBlockStore alloc] initWithManager:manager];
    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:store];
    chain.delegate = self;
    
    self.wallet = [[WSHDWallet alloc] initWithParameters:self.networkParameters seed:WSSeedMake(@"one two three", 0.0)];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:WSWalletDidRegisterTransactionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        DDLogInfo(@"Registered transaction: %@", [note.userInfo[WSWalletTransactionKey] txId]);
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:WSWalletDidUpdateTransactionsMetadataNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        DDLogInfo(@"Updates: %@", note.userInfo[WSWalletTransactionsMetadataKey]);
    }];
    
    DDLogInfo(@"Head: %@", chain.head);

    XCTAssertEqualObjects(chain.head.workString, @"4295032833");
    
    NSArray *connectedOrphans;

    //
    // add to genesis block (G=4295032833)
    //
    // G -> H1=10
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H1, G, 10)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H1)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H1);
    XCTAssertEqual(chain.currentHeight, 1);
    XCTAssertEqualObjects(chain.head.workString, @"4295032843");
    DDLogInfo(@"");

    //
    // attach H2 to G
    // work(H2) < work(H1) = (2 < 10), fork
    //
    // G ------> H1=10
    //   \
    //    \--> H2=2
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H2, G, 2)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H2)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H1);
    XCTAssertEqual(chain.currentHeight, 1);
    XCTAssertEqualObjects(chain.head.workString, @"4295032843");
    DDLogInfo(@"");

    //
    // skip duplicated H1 at same height
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H1, G, 1)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H1)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H1);
    XCTAssertEqual(chain.currentHeight, 1);
    XCTAssertEqualObjects(chain.head.workString, @"4295032843");
    DDLogInfo(@"");

    //
    // orphan H5
    //
    // G ------> H1=10
    //   \
    //    \--> H2=2
    //
    //    (H4) --> H5=1
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H5, H4, 1)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H5)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H1);
    XCTAssertEqual(chain.currentHeight, 1);
    XCTAssertEqualObjects(chain.head.workString, @"4295032843");
    DDLogInfo(@"");

    //
    // orphan H4
    //
    // G ------> H1=10
    //   \
    //    \--> H2=2
    //
    //    (H3) --> H4=1 --> H5=1
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H4, H3, 1)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H4)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H1);
    XCTAssertEqual(chain.currentHeight, 1);
    XCTAssertEqualObjects(chain.head.workString, @"4295032843");
    DDLogInfo(@"");

    //
    // attach H3 to H2
    //
    // G ------> H1=10
    //   \
    //    \--> H2=2 --> H3=5
    //
    //    (H3) --> H4=1 --> H5=1
    //
    // reconnect orphans
    //
    // G ------> H1=10
    //   \
    //    \--> H2=2 --> H3=5 --> H4=1 --> H5=1
    //
    // H5 is new fork head
    // work(H4) < work(H1) = (9 < 10), extend fork
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H3, H2, 5)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H3)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H1);
    XCTAssertEqual(chain.currentHeight, 1);
    XCTAssertEqualObjects(chain.head.workString, @"4295032843");
    DDLogInfo(@"");

    //
    // attach H6 to H1
    //
    // G ------> H1=10 --> H6=7
    //   \
    //    \--> H2=2 --> H3=5 --> H4=1 --> H5=1
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H6, H1, 7)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H6)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H6);
    XCTAssertEqual(chain.currentHeight, 2);
    XCTAssertEqualObjects(chain.head.workString, @"4295032850");
    DDLogInfo(@"");

    //
    // attach H7 to H3
    //
    // G ------> H1=10 --> H6=7
    //   \
    //    \--> H2=2 --> H3=5 --> H4=1 --> H5=1
    //                   \
    //                    \---- H7=8
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H7, H3, 8)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H7)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H6);
    XCTAssertEqual(chain.currentHeight, 2);
    XCTAssertEqualObjects(chain.head.workString, @"4295032850");
    DDLogInfo(@"");

    //
    // attach H8 to H5
    //
    // G ------> H1=10 --> H6=7
    //   \
    //    \--> H2=2 --> H3=5 --> H4=1 --> H5=1 --> H8=12
    //                   \
    //                    \---- H7=8
    //
    // work(H8) > work(H6) = (21 > 17), reorganize
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H8, H5, 12)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H8)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H8);
    XCTAssertEqual(chain.currentHeight, 5);
    XCTAssertEqualObjects(chain.head.workString, @"4295032854");
    DDLogInfo(@"");

    //
    // orhpan HA
    //
    //     (H9) --> HA=4
    //
    // G ------> H1=10 --> H6=7
    //   \
    //    \--> H2=2 --> H3=5 --> H4=1 --> H5=1 --> H8=12
    //                   \
    //                    \---- H7=8
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, HA, H9, 4)
                 transactions:WSMakeDummyTransactions(self.networkParameters, HA)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, H8);
    XCTAssertEqual(chain.currentHeight, 5);
    XCTAssertEqualObjects(chain.head.workString, @"4295032854");
    DDLogInfo(@"");

    //
    // attach H9 to H1
    //
    //      (H9) --> HA=4
    //
    //             /--> H9=24
    //            /
    // G ------> H1=10 --> H6=7
    //   \
    //    \--> H2=2 --> H3=5 --> H4=1 --> H5=1 --> H8=12
    //                   \
    //                    \---- H7=8
    //
    // reconnect orphans
    //
    //             /--> H9=24 --> HA=4
    //            /
    // G ------> H1=10 --> H6=7
    //   \
    //    \--> H2=2 --> H3=5 --> H4=1 --> H5=1 --> H8=12
    //                   \
    //                    \---- H7=8
    //
    // work(HA) > work(H8) = (38 > 21), reorganize
    //
    [chain addBlockWithHeader:WSMakeDummyHeader(self.networkParameters, H9, H1, 24)
                 transactions:WSMakeDummyTransactions(self.networkParameters, H9)
                     location:NULL
             connectedOrphans:&connectedOrphans
              reorganizeBlock:NULL
                        error:NULL];
    XCTAssertEqualObjects(chain.head.blockId, HA);
    XCTAssertEqual(chain.currentHeight, 3);
    XCTAssertEqualObjects(chain.head.workString, @"4295032871");

#ifdef BSPV_TEST_DUMMY_TXS
    XCTAssertEqual(self.wallet.allTransactions.count, 9);
#endif

    [self runForSeconds:1.0];

    DDLogInfo(@"Wallet: %@", self.wallet);
}

#pragma mark WSBlockChainDelegate

- (void)blockChain:(WSBlockChain *)blockChain didAddNewBlock:(WSStorableBlock *)block location:(WSBlockChainLocation)location
{
    DDLogInfo(@"Added block (location: %u): %@", location, block);
    
    for (WSSignedTransaction *tx in block.transactions) {
        [self.wallet registerTransaction:tx didGenerateNewAddresses:NULL];
    }
    [self.wallet registerBlock:block matchingFilteredBlock:nil];

    DDLogInfo(@"Wallet transactions (%lu): %@", (unsigned long)self.wallet.allTransactions.count, self.wallet.allTransactions);
}

- (void)blockChain:(WSBlockChain *)blockChain didReplaceHead:(WSStorableBlock *)head
{
    DDLogInfo(@"Replaced head: %@", head);
}

- (void)blockChain:(WSBlockChain *)blockChain didReorganizeAtBase:(WSStorableBlock *)base oldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks
{
    DDLogInfo(@"Reorganize: fork at block: %@", base);
    DDLogInfo(@"Reorganize: new head: %@", blockChain.head);
    DDLogInfo(@"Reorganize: old blocks: %@", oldBlocks);
    DDLogInfo(@"Reorganize: new blocks: %@", newBlocks);

    DDLogInfo(@"BEFORE: Wallet metadata (%lu)", (unsigned long)self.wallet.allTransactions.count);
    for (WSSignedTransaction *tx in self.wallet.allTransactions) {
        WSTransactionMetadata *metadata = [self.wallet metadataForTransactionId:tx.txId];
        DDLogInfo(@"\t%@ -> %@", tx.txId, metadata);
    }

    [self.wallet reorganizeWithOldBlocks:oldBlocks newBlocks:newBlocks didGenerateNewAddresses:NULL];

    DDLogInfo(@"AFTER: Wallet metadata (%lu)", (unsigned long)self.wallet.allTransactions.count);
    for (WSSignedTransaction *tx in self.wallet.allTransactions) {
        WSTransactionMetadata *metadata = [self.wallet metadataForTransactionId:tx.txId];
        DDLogInfo(@"\t%@ -> %@", tx.txId, metadata);
    }
}

#pragma mark Helpers

- (WSBlockChain *)chainWithLocalHeaders
{
    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:store];

    // from height #1
    NSArray *headers = @[@"0100000043497fd7f826957108f4a30fd9cec3aeba79972084e90ead01ea330900000000bac8b0fa927c0ac8234287e33c5f74d38d354820e24756ad709d7038fc5f31f020e7494dffff001d03e4b67200",
                         @"0100000006128e87be8b1b4dea47a7247d5528d2702c96826c7a648497e773b800000000e241352e3bec0a95a6217e10c3abb54adfa05abb12c126695595580fb92e222032e7494dffff001d00d2353400",
                         @"0100000020782a005255b657696ea057d5b98f34defcf75196f64f6eeac8026c0000000041ba5afc532aae03151b8aa87b65e1594f97504a768e010c98c0add79216247186e7494dffff001d058dc2b600",
                         @"0100000010befdc16d281e40ecec65b7c9976ddc8fd9bc9752da5827276e898b000000004c976d5776dda2da30d96ee810cd97d23ba852414990d64c4c720f977e651f2daae7494dffff001d02a9764000",
                         @"01000000dde5b648f594fdd2ec1c4083762dd13b197bb1381e74b1fff90a5d8b00000000b3c6c6c1118c3b6abaa17c5aa74ee279089ad34dc3cec3640522737541cb016818e8494dffff001d02da84c000",
                         @"01000000a1213bd4754a6606444b97b5e8c46e9b7832773ff434bd5f87ac45bc00000000d1e7026986a9cd247b5b85a3f30ecbabb6d61840d0abb81f905c411d5fc145e831e8494dffff001d004138f900",
                         @"010000007b0a09f26fdde2c432167d8349681c7801d0128f4dfae4dc5e68336600000000c1d71f59ce4419c793eb829380a41dc1ad48c19fcb0083b8f67094d5cae263ad81e8494dffff001d004ddad500",
                         @"01000000a62bc0c08afc1d12e6c6a7eb4a464c848190ac0e44123d5fa63a9ee2000000000214335cde9edeb6aa0195f68c08e5e46b07043e24aeff51fd9a3ff992ce6976a0e8494dffff001d02f3392700",
                         @"01000000f9e2142a93185496f7b21314d8b6fa736d0a30fa3a6d339ab3a1ba9c0000000061974472615d348df6de106dbaaa08cf4dec65e39cefc62af6097b967b9bea52fde8494dffff001d00ca48a200",
                         @"010000001e93aa99c8ff9749037d74a2207f299502fa81d56a4ea2ad5330ff50000000002ec2266c3249ce2e079059e0aec01a2d8d8306a468ad3f18f06051f2c3b1645435e9494dffff001d008918cf00",
                         @"010000002e9afd58b91f15c3ec9eb0f01ed9d503134da1918b6bb416a9920e700000000029fb495afdb58f3a26d1c90fafec93aed840e2fa37ad6173ba1e7fadb7121ee57de9494dffff001d02e7f31800",
                         @"0100000027e0ca29a9802c0a2390ecfa90a9bd814fecc54446510e155652dead000000007e8d5344557575c8f018cc62a32e8e0bd80638643b4ec34945ec4662fcab138142ea494dffff001d04acbc3c00",
                         @"01000000001f3ada9b561378e324e80ee68facd5d232f72f773b86328393054700000000eaf3be35e3f0ace8b6abdeb5509d72999eae2329657238b53fa437e319c8e96b99ea494dffff001d027801a800",
                         @"01000000781bc7847e15c3b936a6a6a178e38fa29ee6e4916a8a62e10795c69200000000d44c3443fa8bd88bf32b94b9257f09ce6fb6ec0d5420504d631568f8685200dfa1ea494dffff001d01f781d000",
                         @"01000000133991a938b505ee8f6f347f313c3372d82a9d8b42b08b0dd0fc086400000000a0ef58c239e0197a65aa248c2cf52c437d8c8ea30d1b835e630a87c941f7d4e9adea494dffff001d030ef2e000",
                         @"0100000028d34cdb13e555032e4bec55fcce3d0fef8212803fb1bab851e1259400000000542c71544b9f28bd5a6fec95ecd509ae49d0b04f8718c685d0751f71d38285d0c3ea494dffff001d056b311500",
                         @"010000006b00cf1ce31b33fe1e2c4648a0834dedd972ffb2a2f341f75ad7cbc400000000adebf7afcbf176f765aec16b74d92896f55c3d65e14dd1a8becee0871000291751eb494dffff001d006f85e800",
                         @"0100000043a78ddf30a2d28a42cc66f90d13cb8211ee0fca9dbf8a4cce8c19fe000000004edbd2b89cb6d6fd69b575a62bd4e3103b1e0ce19e31bccf9a093ad8ccd753cf7deb494dffff001d0591a0b300",
                         @"01000000489ac81592595a4004e14331cb096ffef12b1daf709f6378e9c3558d00000000c757bebd6f2c2c071a3cf739a4cf98b27441809790a5cf40652b46df8a98a473b0eb494dffff001d011aedb600",
                         @"01000000a9c570a45d959023551f9a694ace9c12206174f21383f30949ca3b9b00000000eaf93dbbfb3551a1ff8b6bd5ba4cea7508e790c23cd07b9d9e791936a79d5fd4b3eb494dffff001d0385a7dd00"];
    
    NSError *error;
    for (NSString *hex in headers) {
        WSBlockHeader *header = WSBlockHeaderFromHex(self.networkParameters, hex);
//        DDLogInfo(@"Header: %@", header);
        XCTAssertTrue([chain addBlockWithHeader:header transactions:nil location:NULL connectedOrphans:NULL reorganizeBlock:NULL error:&error], @"Unable to add block %@: %@", header.blockId, error);
    }

    return chain;
}

@end

static WSBlockHeader *WSMakeDummyHeader(WSParameters *networkParameters, WSHash256 *blockId, WSHash256 *previousBlockId, NSUInteger work)
{
    BIGNUM bnLargest;
    BIGNUM bnTarget;
    BIGNUM bnWork;
    
    BN_init(&bnLargest);
    BN_init(&bnTarget);
    BN_init(&bnWork);
    
    BN_CTX *ctx = BN_CTX_new();
    BN_set_bit(&bnLargest, 256);
    BN_set_word(&bnWork, (unsigned)work);
    BN_div(&bnTarget, NULL, &bnLargest, &bnWork, ctx);
    BN_sub(&bnTarget, &bnTarget, BN_value_one());
    BN_CTX_free(ctx);
    
    const uint32_t bits = WSBlockGetBits(&bnTarget);
    
    //    DDLogCInfo(@"Largest: %s", BN_bn2dec(&bnLargest));
    //    DDLogCInfo(@"Target: %s", BN_bn2dec(&bnTarget));
    //    DDLogCInfo(@"Work: %s", BN_bn2dec(&bnWork));
    //    DDLogCInfo(@"Bits: %x", bits);
    
    BN_free(&bnLargest);
    BN_free(&bnTarget);
    BN_free(&bnWork);
    
    WSBlockHeader *header = [[WSBlockHeader alloc] initWithParameters:networkParameters
                                                              version:2
                                                      previousBlockId:previousBlockId
                                                           merkleRoot:WSHash256Zero()
                                                            timestamp:WSCurrentTimestamp()
                                                                 bits:bits
                                                                nonce:0];
    
    // hack id for testing
    [header setValue:blockId forKey:@"blockId"];
    
    return header;
}

static NSOrderedSet *WSMakeDummyTransactions(WSParameters *networkParameters, WSHash256 *blockId)
{
    NSMutableOrderedSet *txs = [[NSMutableOrderedSet alloc] initWithCapacity:3];
    WSHash256 *outpointTxId = WSHash256FromHex(@"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
    
    for (unsigned i = 0; i < 1; ++i) {
        NSMutableString *hex = [[blockId.data hexString] mutableCopy];
        [hex replaceCharactersInRange:NSMakeRange(0, 2) withString:[NSString stringWithFormat:@"%u%u", i, i]];
        [hex replaceCharactersInRange:NSMakeRange(2, 6) withString:@"ffffff"];
        WSHash256 *txId = WSHash256FromHex(hex);
        WSScript *script = [WSScript scriptWithAddress:WSAddressFromString(networkParameters, @"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP")];
        
        WSTransactionOutPoint *outpoint = [WSTransactionOutPoint outpointWithParameters:networkParameters txId:outpointTxId index:0];
        WSSignedTransactionInput *input = [[WSSignedTransactionInput alloc] initWithOutpoint:outpoint script:script];
        WSTransactionOutput *output = [[WSTransactionOutput alloc] initWithParameters:networkParameters script:script value:100000];
        
        WSSignedTransaction *tx = [[WSSignedTransaction alloc] initWithSignedInputs:[NSOrderedSet orderedSetWithObject:input] outputs:[NSOrderedSet orderedSetWithObject:output] error:NULL];
        [tx setValue:txId forKey:@"txId"];
        [txs addObject:tx];
    }
    
    return txs;
}
