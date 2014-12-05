//
//  WSCoreDataStoreTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 11/07/14.
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
#import "WSCoreDataManager.h"
#import "WSCoreDataBlockStore.h"
#import "WSMemoryBlockStore.h"
#import "WSBlockHeaderEntity.h"
#import "WSFilteredBlock.h"
#import "WSBlockChain.h"
#import "WSStorableBlock.h"
#import "WSConnectionPool.h"
#import "WSPeerGroup.h"
#import "WSCheckpoint.h"

@interface WSCoreDataStoreTests : XCTestCase

@property (nonatomic, strong) WSCoreDataManager *manager;

@end

@implementation WSCoreDataStoreTests

- (void)setUp
{
    [super setUp];

    WSParametersSetCurrentType(WSParametersTypeTestnet3);

    NSString *path = [self mockPathForFile:@"CoreDataStoreTests.sqlite"];
    self.manager = [[WSCoreDataManager alloc] initWithPath:path error:NULL];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testInitialization
{
    [self.manager.context performBlockAndWait:^{
//        DDLogInfo(@"All entities: %@", [self.model entities]);

        NSEntityDescription *entity = [NSEntityDescription entityForName:@"WSBlockHeaderEntity" inManagedObjectContext:self.manager.context];
        XCTAssertNotNil(entity, @"Nil entity description, failed to load model?");
    }];
}

- (void)testGenesis
{
    id<WSBlockStore> store = [[WSCoreDataBlockStore alloc] initWithManager:self.manager];
    [store truncate];

    XCTAssertEqualObjects(store.head.blockId, [WSCurrentParameters genesisBlockId]);
}

- (void)testAddHeaders
{
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

    id<WSBlockStore> store = [[WSCoreDataBlockStore alloc] initWithManager:self.manager];
//    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithGenesisBlock];
    [store truncate];

    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:store];

    for (NSString *hex in headers) {
        WSBlockHeader *header = WSBlockHeaderFromHex(hex);

        NSError *error;
        XCTAssertTrue([chain addBlockWithHeader:header reorganizeBlock:NULL error:&error], @"Unable to add block %@: %@", header.blockId, error);
    }
    XCTAssertEqual(chain.currentHeight, headers.count);

    DDLogInfo(@"Chain: %@", chain);

    NSArray *expBelow5 = @[WSHash256FromHex(@"000000008b5d0af9ffb1741e38b17b193bd12d7683401cecd2fd94f548b6e5dd"),
                           WSHash256FromHex(@"000000008b896e272758da5297bcd98fdc6d97c9b765ecec401e286dc1fdbe10"),
                           WSHash256FromHex(@"000000006c02c8ea6e4ff69651f7fcde348fb9d557a06e6957b65552002a7820"),
                           WSHash256FromHex(@"00000000b873e79784647a6c82962c70d228557d24a747ea4d1b8bbe878e1206"),
                           WSHash256FromHex(@"000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943")];
    
    NSArray *below5 = [store removeBlocksBelowHeight:5];
    DDLogInfo(@"Block ids below 5: %@", below5);
    XCTAssertEqualObjects(below5, expBelow5);
}

- (void)testAddBlockWithTxs
{
    id<WSBlockStore> store = [[WSCoreDataBlockStore alloc] initWithManager:self.manager];
    [store truncate];

    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:store];
    DDLogInfo(@"Chain (begin): %@", chain);

    NSError *error;

    WSCheckpoint *checkpoint = [[WSCheckpoint alloc] initWithHeight:266642
                                                            blockId:WSHash256FromHex(@"000000000000a7b4391d74a020b8d26d6fb843763756a125a1cccb357602d75b")
                                                          timestamp:0
                                                               bits:0x1d00ffff];

    XCTAssertTrue([chain addCheckpoint:checkpoint error:&error]);
    XCTAssertEqualObjects(chain.head.workString, @"4295032833");
    
    WSFilteredBlock *block = WSFilteredBlockFromHex(@"020000005bd7027635cbcca125a156377643b86f6dd2b820a0741d39b4a7000000000000fca15af0cbaae20e8cd6d8c613ca058b291f793da7925db7e30b71db349479353f9cb5536431011b8818102d12000000120763f91fe0bb2d89c0284588556f466123a1fb76cf591d7aa196115a1ed0cafa1fe750aeb68a59570d7be7f0b8f62698d6242b84db50bf6e314d10ca624789dd9a628ae55f7b1f7c652b99259503705b106c7cbe300e0a77054be720caec243668ff80caa26851ea1170462bf96e91e0bbe23da9949e1b0520e20983aca3406167febc07e28ca2163b9243f6878c53ceeeb71d18528f40bbc19c03dfd194e77f523e3d286d0856d951992ca24970abc98cd0b5a61bffe472583ecc60f06c3c033034b6b8b9d215df13bd46fcd8f26a3a12300a8f0213676ecd27ec8a51ecb18eeca10647a8a0c5466f5ac0d65623b7783eb83095379a15d99c7a86867fb951c098f8fbef7589f8bb9b09f290547af41eabb511037023359e8877a37574034c11b3f0acc28f3b97ecd78f3d9d3e96919a90d3067018fe981c10a0bb0148ddef696d74fa51489b4b1a3e03c0a888a71171b8c4936169ece50c71e7444281b305a92a2011c92a479b505340e1cdc48a0854536db8f2937a55a7cf07d2f59f26f6d3ed175b94b22798a73b723109901a30a94ad261c63a928acb8ca17a8019992515c074d1dfa3bd43935a1274b00c4d12fd87ee2ff0608d58d581e4e729af530b021808b863656bf47ece10a6c4f6a5a4173737a5cd113580d2f7e13bcd14201bea62b08a42110fb85b4e0e7116179b482a706edd4a8e975fe9b6df39931cc55ae6221d7cfc745b8d4234279fc7f3dc057f03b0ef29f942e929b9f52f28267f77fd98713c3f05a0de8922d1392ce26f60239865a38a8c94e5e4e7eb90a51245dc7a05ffffffff3f");
    DDLogInfo(@"Filtered block: %@", block);
    XCTAssertEqualObjects(block.header.workString, @"235952213784977");
    WSSignedTransaction *tx = WSTransactionFromHex(@"010000000459cbb78f55fda4d1eeef41180686f011c497469490a68c7d388dff7a152dabb1000000008c493046022100f0dbc62f00bda641833416e34f062234ccf9256daf21aad54ca3cebc87e714540221009e27727760cc2274d7e92d9e23fc781438d641bd934c44547ec8f16af4dd18fa0141042a65f36cfbd9f016597e219870bb741b9f5f0a1deaedafea569d6968c2d72b62a4bc8915584ba2bf690d92c737f7cda03a0c1377d9ed90977b044927892294f3ffffffffa8c4e4e1641eb32a2f897b2ec369fbfca77eb7bde119e9f67c49219f40de3137000000008b48304502210086089db5a7445103540ac25b071199828c2fcf4a596df68315788ca7da15563402207c1bef9a5dcb84a7670983688d292a615f217517fb3956d601d999384dfb89200141045d6a5319757ea49302cf7bc94499e0aace02cf336a7efc3b335909e473fe51a88d83aa027cee19ab6e8a1413ea5f5647a9b6dbfb50c23c1c16e4d7074bf9fb13fffffffff4fa614da159c2d0ab3f693e969a06f59a790814a0bcd5e8256346a0863308ed010000008a47304402204574cf17abe22196da2707ef28adf08d91ee43c70faa4ff80617df004f3a50e802207ff0fb1984ac78f6ad0f382f16d9d6a18d5afe4d62eeed854739b8c1ffaf62ef0141043811ceb31510fe4a317b7eb8ae78aa3a523725dcc46ba80101f41363fa189c26663e5abcb33feb11b2c1b12cffe72e14d93c536d3b75ff1d07b0514e121839f4ffffffff4f5e62ed298d294977cf290776c858fa19eeded8a555c85be31878f5c84ff552000000008a4730440220365b2950ea43338641151956a3af17e013d2b71251aa67cb43bf36cadfdfebb802205a815577a6cb347dbd803edc3141ac1e4e6f08d03634e6c6a683bbc19fb13fd30141046172813a3084d6cc3f838f10ae7583b685164a01dec67f1a9091fe5aa75c7d33fdcfd35842847aa4e85c891520507569aabb4cb5f91caf18ffcc10e809a810bcffffffff0229166400000000001976a9146ba6db5d885b4fcc24307d378664a8db3f9ace4488ace0730385000000001976a91488834d722528175119b77724652b9711cd7818c488ac00000000");
    DDLogInfo(@"Transaction: %@", tx);

    XCTAssertTrue([chain addBlockWithHeader:block.header transactions:[NSOrderedSet orderedSetWithObject:tx] reorganizeBlock:NULL error:&error], @"Unable to add block %@: %@", block.header.blockId, error);
    XCTAssertEqual(chain.currentHeight, 266643);
    XCTAssertEqualObjects(chain.head.workString, @"235956508817810");

    DDLogInfo(@"Chain (end): %@", chain);
    [store save];
}

- (void)testPrint
{
    id<WSBlockStore> store = [[WSCoreDataBlockStore alloc] initWithManager:self.manager];
    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:store];

    DDLogInfo(@"Chain: %@", chain);
}

//- (void)testAddFilteredBlock
//{
//    // WARNING
//    [self.store truncate];
//
//    NSString *hex = @"020000005bd7027635cbcca125a156377643b86f6dd2b820a0741d39b4a7000000000000fca15af0cbaae20e8cd6d8c613ca058b291f793da7925db7e30b71db349479353f9cb5536431011b8818102d12000000120763f91fe0bb2d89c0284588556f466123a1fb76cf591d7aa196115a1ed0cafa1fe750aeb68a59570d7be7f0b8f62698d6242b84db50bf6e314d10ca624789dd9a628ae55f7b1f7c652b99259503705b106c7cbe300e0a77054be720caec243668ff80caa26851ea1170462bf96e91e0bbe23da9949e1b0520e20983aca3406167febc07e28ca2163b9243f6878c53ceeeb71d18528f40bbc19c03dfd194e77f523e3d286d0856d951992ca24970abc98cd0b5a61bffe472583ecc60f06c3c033034b6b8b9d215df13bd46fcd8f26a3a12300a8f0213676ecd27ec8a51ecb18eeca10647a8a0c5466f5ac0d65623b7783eb83095379a15d99c7a86867fb951c098f8fbef7589f8bb9b09f290547af41eabb511037023359e8877a37574034c11b3f0acc28f3b97ecd78f3d9d3e96919a90d3067018fe981c10a0bb0148ddef696d74fa51489b4b1a3e03c0a888a71171b8c4936169ece50c71e7444281b305a92a2011c92a479b505340e1cdc48a0854536db8f2937a55a7cf07d2f59f26f6d3ed175b94b22798a73b723109901a30a94ad261c63a928acb8ca17a8019992515c074d1dfa3bd43935a1274b00c4d12fd87ee2ff0608d58d581e4e729af530b021808b863656bf47ece10a6c4f6a5a4173737a5cd113580d2f7e13bcd14201bea62b08a42110fb85b4e0e7116179b482a706edd4a8e975fe9b6df39931cc55ae6221d7cfc745b8d4234279fc7f3dc057f03b0ef29f942e929b9f52f28267f77fd98713c3f05a0de8922d1392ce26f60239865a38a8c94e5e4e7eb90a51245dc7a05ffffffff3f";
//    
//    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:self.store];
//    id<WSFilteredBlock> block = WSFilteredBlockFromHex(hex);
//    
//    // XXX: hack to connect
//    [(WSMutableFilteredBlock *)block.header setValue:self.store.head.blockId forKey:@"previousBlockId"];
//    
//    [chain addFilteredBlock:block error:NULL];
//    [self.store save];
//    
//    DDLogInfo(@"Chain: %@", chain);
//}
//
//- (void)testPrintFilteredBlock
//{
//    WSBlockChain *chain = [[WSBlockChain alloc] initWithStore:self.store];
//
//    DDLogInfo(@"Chain: %@", chain);
//}

@end
