//
//  WSWalletTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 22/06/14.
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
#import "WSHDWallet.h"
#import "WSSeed.h"
#import "WSBIP32.h"
#import "WSKey.h"
#import "WSPublicKey.h"
#import "WSAddress.h"
#import "WSTransaction.h"

// XXX: hacks internal ivars, check key names in valueForKey:

@interface WSWalletTests : XCTestCase

@property (nonatomic, strong) WSSeed *seed;

@end

@implementation WSWalletTests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeTestnet3;

    self.seed = WSSeedMakeNow([self mockWalletMnemonic]);
}

- (void)tearDown
{
    [super tearDown];
}

//- (void)testKeyrings
//{
//    WSHDWallet *wallet = [[WSHDWallet alloc] initWithSeed:self.seed];
//
//    NSData *keyData = [self.seed derivedKeyData];
//    DDLogInfo(@"Key data: %@", [keyData hexString]);
//
//    id<WSBIP32Keyring> keyring = [wallet valueForKey:@"_keyring"];
//
//    NSString *eprivKey = [[keyring extendedPrivateKey] serializedKey];
//    NSString *expEprivKey = @"tprv8ZgxMBicQKsPez8DeWESxs1YB9fBFJsKVwp8qL5qHjZuesoQCJsPgmACeiJkRDJfya3QHGNVtN1Jk3g8bD8LbFCbQc96vG5mT9WjxfAho7L";
//    DDLogInfo(@"Private key: %@", eprivKey);
//    XCTAssertEqualObjects(eprivKey, expEprivKey);
//
//    NSString *epubKey = [[keyring extendedPublicKey] serializedKey];
//    NSString *expEpubKey = @"tpubD6NzVbkrYhZ4YTA1Y9u3NGfekBB7Qe4E5FQv7r88i1NJVN4AphgysFn4ppMvaYbecqrVzwBMRUVB2DbHAr2gRbntHF58pVVWep1uNUBkTvL";
//    DDLogInfo(@"Public key: %@", epubKey);
//    XCTAssertEqualObjects(epubKey, expEpubKey);
//}

- (void)testChain
{
    WSHDWallet *wallet = [[WSHDWallet alloc] initWithParameters:self.networkParameters seed:self.seed];
    
    NSArray *chains = @[[wallet valueForKey:@"_externalChain"],
                        [wallet valueForKey:@"_internalChain"]];
    WSAddress *target = WSAddressFromString(self.networkParameters, @"mgjkgSBEfR2K4XZM1vM5xxYzFfTExsvYc9");

    BOOL found = NO;
    NSUInteger c = 0;
    for (id<WSBIP32Keyring> chain in chains) {
        for (int i = 0; i < 10; ++i) {
            id<WSBIP32Keyring> kr = [chain keyringForAccount:i];
            WSAddress *address = [kr address];
            DDLogInfo(@"Addresses[%d]: %@", i, address);
            if ([address isEqual:target]) {
                DDLogInfo(@"FOUND at chain %d, index %d", c, i);
                XCTAssertTrue((c == 1) && (i == 0), @"Address found at different chain location");
                found = YES;
                break;
            }
        }
        if (found) {
            break;
        }
        ++c;
    }
}

- (void)testGeneration
{
    WSHDWallet *wallet = [[WSHDWallet alloc] initWithParameters:self.networkParameters seed:self.seed gapLimit:25];

    NSArray *expReceives = @[@"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP",
                             @"mm4Z6thuZxVAYXXVU35KxzirnfFZ7YwszT",
                             @"mo6oWnaMKDE9Bq2w97p3RWCHAqDiFdyYQH"];

    NSArray *expChanges = @[@"mgjkgSBEfR2K4XZM1vM5xxYzFfTExsvYc9",
                            @"mo6HhdAEKnLDivSZjWaeBN7AY26bxo78cT",
                            @"mkW2kGUwWQmVLEhmhjXZEPpHqhXreYemh1"];
    
    DDLogInfo(@"Receive addresses: %@", wallet.allReceiveAddresses);
    DDLogInfo(@"Change addresses: %@", wallet.allChangeAddresses);
    DDLogInfo(@"Current receive address: %@", wallet.receiveAddress);
    DDLogInfo(@"Current change address: %@", wallet.changeAddress);

    for (int i = 0; i < expReceives.count; ++i) {
        WSAddress *receive = wallet.allReceiveAddresses[i];
        WSAddress *expReceive = WSAddressFromString(self.networkParameters, expReceives[i]);
        DDLogInfo(@"Receive address: %@", receive);
        XCTAssertEqualObjects(receive, expReceive);

        WSAddress *change = wallet.allChangeAddresses[i];
        WSAddress *expChange = WSAddressFromString(self.networkParameters, expChanges[i]);
        DDLogInfo(@"Change address : %@", change);
        XCTAssertEqualObjects(change, expChange);

        WSKey *receivePrivKey = [wallet privateKeyForAddress:receive];
        WSKey *changePrivKey = [wallet privateKeyForAddress:change];
        WSPublicKey *receivePubKey = [wallet publicKeyForAddress:receive];
        WSPublicKey *changePubKey = [wallet publicKeyForAddress:change];

        DDLogInfo(@"Private key (receive): %@", receivePrivKey);
        DDLogInfo(@"Private key (change): %@", changePrivKey);
        DDLogInfo(@"Public key (receive): %@", receivePubKey);
        DDLogInfo(@"Public key (change): %@", changePubKey);
    }
}

- (void)testGenerationUsedAddresses
{
    WSHDWallet *wallet = [[WSHDWallet alloc] initWithParameters:self.networkParameters seed:self.seed gapLimit:2];
    DDLogInfo(@"");

    NSMutableSet *usedAddresses = [wallet valueForKey:@"_usedAddresses"];
    
    XCTAssertFalse([wallet generateAddressesIfNeeded]);
    DDLogInfo(@"");

    [usedAddresses addObject:WSAddressFromString(self.networkParameters, @"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP")];
    XCTAssertFalse([wallet generateAddressesIfNeeded]);
    DDLogInfo(@"");

    [usedAddresses addObject:WSAddressFromString(self.networkParameters, @"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP")];
    [usedAddresses addObject:WSAddressFromString(self.networkParameters, @"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP")];
    [usedAddresses addObject:WSAddressFromString(self.networkParameters, @"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP")];
    [usedAddresses addObject:WSAddressFromString(self.networkParameters, @"mo6HhdAEKnLDivSZjWaeBN7AY26bxo78cT")];
    XCTAssertFalse([wallet generateAddressesIfNeeded]);
    DDLogInfo(@"");
    
    [usedAddresses addObject:WSAddressFromString(self.networkParameters, @"mm4Z6thuZxVAYXXVU35KxzirnfFZ7YwszT")];
    [usedAddresses addObject:WSAddressFromString(self.networkParameters, @"mo6oWnaMKDE9Bq2w97p3RWCHAqDiFdyYQH")];
    [usedAddresses addObject:WSAddressFromString(self.networkParameters, @"myJkpby5M1vZaQFA8oeWafn8uC4xeTkqxo")];
    XCTAssertTrue([wallet generateAddressesIfNeeded]);
    DDLogInfo(@"");
    
    [usedAddresses addObject:WSAddressFromString(self.networkParameters, @"mvm26jv7vPUruu9RAgo4fL5ib5ewirdrgR")];
    XCTAssertTrue([wallet generateAddressesIfNeeded]);
    DDLogInfo(@"");
}

- (void)testRelevantTransactions
{
    NSArray *expTxHexes = @[@"010000000128ec939baca2e967bfc3dd369052bd2d3b4fa9780118c09f9330938f4e817c6d010000006a47304402205f1ae7190898dbd00a5dd370b7d4687c293253fd4ca95103dad05c74f0257bb902201790499e2c6791f085faaaadaadc23231ee0af7cb91552bf5a6e3a39ddd7ae2f0121039ffdb8035755890034d46b4496eef168a36a9532fbf1945677c755003477e98effffffff02002d3101000000001976a914bf49c258def640bb8a4860384f277379e3be92c288ac2095f55e030000001976a9140e8a296534275c2794e3debe3376ddff2613e9ae88ac00000000",
                            @"01000000016574bb2f3beb7bef2dcbcf189c4400928f5f3ffe1a7ee4f88d050644d401126b000000006a47304402207365a6c5162f1f3a8d0c67f291d9a0de3521284b7b7361dbe1dc59b71ea3b79802203a1a87255184fef1b73a8faf549ccaa53ce847e0fae5a2d484255a51113a0274012103a10880b8093620696dbf0e8a5948ff94bbdc555b2bf75600a3c1456d795dea0fffffffff0240e20100000000001976a914412d0dd3a9b009d30b9210005041e5025f4f819588acb0232f01000000001976a9140d63d69b304d1594a1ad54c392e8f0155fbfb69988ac00000000",
                            @"0100000001806c5781039c0ff29214e1f224f9ffb90a7de63f8cdcb46461d8fd1eb18bd524010000006b4830450221008f2afef578ce0119e7389656254482204a4d67556e8ecf55284c5db57959b610022002afe71fc51fd67480d9d45f82d4839a61773bf09aee6c61126dd97f64dfa0c4012102ceab68fe2441c3e6f5ffa05c53fe43292cef05462a53021fa359b4bbfdfc27e3ffffffff02a8150000000000001976a914ca4f8d42241a5ba8d4947ea767b2761c1a74dbff88ac200a2f01000000001976a9145316ce8e4614948c6bd49ee1c48b7bbf90d5fb7488ac00000000",
                            @"0100000001bbddbca3c4155c407498d7b9213da3f2ca8bdc55b2a7c21a0753b1aa1e15848b010000006b483045022100a5a48d98adec77ff6897107be31d9a1761cf17bfad0c886465200ec3bfa7f8e90220087c6736184088e02dc73c8cad833f5de7d82e66b7ad10e034c82f964a3011c50121031f11127e8e21da4ec5a825b0b674b24c502e6f153573e52c4480863f418ebf4cffffffff0378ff6400000000001976a914bf49c258def640bb8a4860384f277379e3be92c288ac78ff6400000000001976a9143cd29461eb29bdb48c90651896b4ab00f00da11488ac78ff6400000000001976a914532fb190ec8296cb55afe6e422b443fea4650d4788ac00000000"];

    NSArray *expTxIds = @[@"6b1201d44406058df8e47e1afe3f5f8f9200449c18cfcb2def7beb3b2fbb7465",
                          @"24d58bb11efdd86164b4dc8c3fe67d0ab9fff924f2e11492f20f9c0381576c80",
                          @"8b84151eaab153071ac2a7b255dc8bcaf2a33d21b9d79874405c15c4a3bcddbb",
                          @"a905b3814244e7710ce5ec696193c4b87111a788a8c0033e1a4b9b4851fa746d"];

    WSHDWallet *wallet = [[WSHDWallet alloc] initWithParameters:self.networkParameters seed:self.seed];
    
    NSMutableArray *txs = [[NSMutableArray alloc] initWithCapacity:expTxHexes.count];
    NSUInteger i = 0;
    for (NSString *expTxHex in expTxHexes) {
        WSSignedTransaction *tx = WSTransactionFromHex(self.networkParameters, expTxHex);
        [txs addObject:tx];

        DDLogInfo(@"Tx #%u: %@", txs.count, tx);

        NSString *txHex = [[tx toBuffer] hexString];
        XCTAssertEqualObjects(txHex, expTxHex);
        WSHash256 *txId = tx.txId;
        XCTAssertEqualObjects(txId, WSHash256FromHex(expTxIds[i]));
        
        XCTAssertTrue([wallet isRelevantTransaction:tx]);
        
        ++i;
    }
}

@end
