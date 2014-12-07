//
//  WSKeysTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 03/07/14.
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
#import "WSKey.h"
#import "WSPublicKey.h"

@interface WSKeysTests : XCTestCase

@end

@implementation WSKeysTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testWIF
{
    WSParametersSetCurrentType(WSParametersTypeMain);
    
    NSString *hex = @"B365D41461E4961337A4F407F70B7A61FA8C1BE90175215F1FADF65D0623E116";
    NSString *compressed = @"L3ESHJjRLKEwxydy2smiZMPkTWfXfRThRKKwaDqcdm2jRVwu3si3";
    NSString *uncompressed = @"5KBJ4EzBx8JfHJpLwoPpUin2gzUJpg5EgwuKi4Mz1dFtkiHwdTj";

    NSData *privateData = [hex dataFromHex];
    DDLogInfo(@"Decoded: %@ (%u bytes)", [privateData hexString], privateData.length);
    
    NSData *compressedData = [compressed dataFromBase58Check];
    DDLogInfo(@"Compressed  : %@ (%u bytes)", [compressedData hexString], compressedData.length);

    NSData *uncompressedData = [uncompressed dataFromBase58Check];
    DDLogInfo(@"Uncompressed: %@ (%u bytes)", [uncompressedData hexString], uncompressedData.length);

    WSKey *keyCOM = WSKeyFromWIF(compressed);
    XCTAssertTrue([keyCOM isCompressed]);
    NSData *encodedCOM = [keyCOM encodedData];
    DDLogInfo(@"Key (compressed)  : %@ (%u bytes)", [encodedCOM hexString], encodedCOM.length);
    XCTAssertEqualObjects(keyCOM.data, privateData);

    WSKey *keyUC = WSKeyFromWIF(uncompressed);
    XCTAssertFalse([keyUC isCompressed]);
    NSData *encodedUC = [keyUC encodedData];
    DDLogInfo(@"Key (uncompressed): %@ (%u bytes)", [encodedUC hexString], encodedUC.length);
    XCTAssertEqualObjects(keyUC.data, privateData);

    WSKey *testKeyCompressed = [WSKey keyWithData:privateData compressed:YES];
    WSKey *testKeyUncompressed = [WSKey keyWithData:privateData compressed:NO];
    XCTAssertTrue([testKeyCompressed isCompressed]);
    XCTAssertFalse([testKeyUncompressed isCompressed]);

    XCTAssertEqualObjects(testKeyCompressed.data, keyCOM.data);
    XCTAssertEqualObjects(testKeyCompressed.data, keyUC.data);
    XCTAssertEqualObjects(testKeyCompressed.encodedData, keyCOM.encodedData);

    XCTAssertEqualObjects(testKeyUncompressed.data, keyCOM.data);
    XCTAssertEqualObjects(testKeyUncompressed.data, keyUC.data);
    XCTAssertEqualObjects(testKeyUncompressed.encodedData, keyUC.encodedData);

    XCTAssertNotEqualObjects(testKeyCompressed.encodedData, keyUC.encodedData);
    XCTAssertNotEqualObjects(testKeyUncompressed.encodedData, keyCOM.encodedData);
}

- (void)testPrivateFromWIF
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);

    NSString *wif = @"cQukrUmHpU3Wp4qMr1ziAL6ztr3r8bvdhNJ5mGAq8wnmAMscYZid";
    DDLogInfo(@"Key (WIF): %@", wif);
    DDLogInfo(@"Key (hex): %@", [wif hexFromBase58Check]);
    
    WSKey *key = WSKeyFromWIF(wif);
    DDLogInfo(@"Key (WIF): %@", key);

    XCTAssertEqualObjects([key WIF], wif);
}

- (void)testAddressFromPubKeys
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    NSArray *pubHexes = @[@"02fcba7ecf41bc7e1be4ee122d9d22e3333671eb0a3a87b5cdf099d59874e1940f",
                          @"042a65f36cfbd9f016597e219870bb741b9f5f0a1deaedafea569d6968c2d72b62a4bc8915584ba2bf690d92c737f7cda03a0c1377d9ed90977b044927892294f3"];
    
    NSArray *expAddresses = @[WSAddressFromString(@"1Nro9WkpaKm9axmcfPVp79dAJU1Gx7VmMZ"),
                              WSAddressFromString(@"1QU41PkTSwfDETtcMU8jhWz3dreH4F369")];
    
    NSUInteger i = 0;
    for (NSString *pubHex in pubHexes) {
        WSPublicKey *pubKey = WSPublicKeyFromHex(pubHex);
        
        DDLogInfo(@"Orig   : %@", pubHex);
        DDLogInfo(@"PubData: %@", [[pubKey encodedData] hexString]);
        DDLogInfo(@"Hash160: %@", [pubKey hash160]);
        
        WSAddress *address = [pubKey address];
        DDLogInfo(@"Address: %@", address);
        XCTAssertEqualObjects(address, expAddresses[i], @"Address %d", i);
        
        ++i;
    }
}

//
// from [WSPeerTests testPublishTransaction]
//
- (void)testTxSignedInput
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);

    WSKey *privKey = WSKeyFromWIF(@"cQukrUmHpU3Wp4qMr1ziAL6ztr3r8bvdhNJ5mGAq8wnmAMscYZid");
    NSString *pubHex = @"02ceab68fe2441c3e6f5ffa05c53fe43292cef05462a53021fa359b4bbfdfc27e3";
    
    WSPublicKey *pubKey = WSPublicKeyFromHex(pubHex);
    WSPublicKey *pubKeyFromPriv = [privKey publicKey];
    DDLogInfo(@"Public key               : %@", pubKey);
    DDLogInfo(@"Public key (from private): %@", pubKeyFromPriv);
    XCTAssertEqualObjects(pubKey.encodedData, pubKeyFromPriv.encodedData);

    WSAddress *expAddress = WSAddressFromString(@"mgjkgSBEfR2K4XZM1vM5xxYzFfTExsvYc9");
    WSAddress *address = [pubKey address];
    DDLogInfo(@"Address : %@", address);
    DDLogInfo(@"Expected: %@", expAddress);
    XCTAssertEqualObjects(address, expAddress);

    NSData *signable = [@"0100000001806c5781039c0ff29214e1f224f9ffb90a7de63f8cdcb46461d8fd1eb18bd524010000001976a9140d63d69b304d1594a1ad54c392e8f0155fbfb69988acffffffff02a8150000000000001976a914ca4f8d42241a5ba8d4947ea767b2761c1a74dbff88ac200a2f01000000001976a9145316ce8e4614948c6bd49ee1c48b7bbf90d5fb7488ac0000000001000000" dataFromHex];
    NSData *expSignature = [@"30450221008f2afef578ce0119e7389656254482204a4d67556e8ecf55284c5db57959b610022002afe71fc51fd67480d9d45f82d4839a61773bf09aee6c61126dd97f64dfa0c4" dataFromHex];
    WSHash256 *signableHash = WSHash256Compute(signable);
    XCTAssertTrue([pubKey verifyHash256:signableHash signature:expSignature]);
    XCTAssertTrue([privKey verifyHash256:signableHash signature:expSignature]);

    NSData *signature = [privKey signatureForHash256:signableHash];
    DDLogInfo(@"Signature: %@", [signature hexString]);
    DDLogInfo(@"Expected : %@", [expSignature hexString]);
    XCTAssertEqualObjects(signature, expSignature);
}

@end
