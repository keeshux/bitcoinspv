//
//  WSScriptTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 18/06/14.
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
#import "WSPublicKey.h"
#import "WSScript.h"
#import "WSAddress.h"
#import "WSHash160.h"

@interface WSScriptTests : XCTestCase

@end

@implementation WSScriptTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testScriptFromAddress
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    //
    // OP_DUP
    // OP_HASH160
    // <length> "14" = 20
    // <data> "d225dc4e19d0377a60c65a348bcc5cf35beada3a"
    // OP_EQUALVERIFY
    // OP_CHECKSIG
    //
    WSAddress *address = WSAddressFromString(@"1LAAFtCLmq3A3ak57N4jUf5p3cJVDfwFN8");
    DDLogInfo(@"Address      : %@", address);
    DDLogInfo(@"Address (hex): %@", [address hexEncoded]);
    NSString *expScriptHex = @"76a914d225dc4e19d0377a60c65a348bcc5cf35beada3a88ac";

    WSScriptBuilder *scriptBuilder = [[WSScriptBuilder alloc] init];
    [scriptBuilder appendScriptForAddress:address];
    WSScript *script = [scriptBuilder build];
    DDLogInfo(@"Script (human readable): %@", script);
    
    NSData *scriptData = [[script toBuffer] data];
    NSString *scriptHex = [scriptData hexString];
    DDLogInfo(@"Script (hex): %@", scriptHex);
    DDLogInfo(@"Expected    : %@", expScriptHex);
    XCTAssertEqualObjects(scriptHex, expScriptHex);
}

- (void)testAddressFromOutputScript
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    NSString *expScriptHex = @"76a914d225dc4e19d0377a60c65a348bcc5cf35beada3a88ac";

    WSScript *script = WSScriptFromHex(expScriptHex);
    DDLogInfo(@"Script chunks: %@", script.chunks);
    DDLogInfo(@"Script (human readable): %@", script);
    
    NSString *scriptHex = [[script toBuffer] hexString];
    DDLogInfo(@"Script (hex): %@", scriptHex);
    DDLogInfo(@"Expected    : %@", expScriptHex);
    XCTAssertEqualObjects(scriptHex, expScriptHex);
    
    WSAddress *decodedAddress = [script standardAddress];
    WSAddress *expAddress = WSAddressFromString(@"1LAAFtCLmq3A3ak57N4jUf5p3cJVDfwFN8");
    DDLogInfo(@"Address : %@", decodedAddress);
    DDLogInfo(@"Expected: %@", expAddress);
    XCTAssertEqualObjects(decodedAddress, expAddress);
}

- (void)testAddressFromInputScript
{
    WSParametersSetCurrentType(WSParametersTypeMain);
    
    NSString *expScriptHex = @"483045022100abbc8a73fe2054480bda3f3281da2d0c51e2841391abd4c09f4f908a2034c18d02205bc9e4d68eafb918f3e9662338647a4419c0de1a650ab8983f1d216e2a31d8e30141046f55d7adeff6011c7eac294fe540c57830be80e9355c83869c9260a4b8bf4767a66bacbd70b804dc63d5beeb14180292ad7f3b083372b1d02d7a37dd97ff5c9e";
    
    WSScript *script = WSScriptFromHex(expScriptHex);
    DDLogInfo(@"Script chunks: %@", script.chunks);
    DDLogInfo(@"Script (human readable): %@", script);
    
    NSString *scriptHex = [[script toBuffer] hexString];
    DDLogInfo(@"Script (hex): %@", scriptHex);
    DDLogInfo(@"Expected    : %@", expScriptHex);
    XCTAssertEqualObjects(scriptHex, expScriptHex);
    
    WSAddress *decodedAddress = [script standardAddress];
    WSAddress *expAddress = WSAddressFromString(@"18pV61UrtyK9YW8tDa53UkM8DDbFWKiwvc");
    DDLogInfo(@"Address : %@", decodedAddress);
    DDLogInfo(@"Expected: %@", expAddress);
    XCTAssertEqualObjects(decodedAddress, expAddress);
}

- (void)testAddressFromScriptMultiSig
{
    NSArray *expNetworks = @[@(WSParametersTypeMain),
                             @(WSParametersTypeTestnet3)];
    
    NSArray *expAddresses = @[@"3QJmV3qfvL9SuYo34YihAf3sRCW3qSinyC",
                              @"2MzeFhdGMftyDR1jt8Vtz8DV2eDbY8CCRS4"];

    NSArray *expOutputScripts = @[@"a914f815b036d9bbbce5e9f2a00abd1bf3dc91e9551087"];

    NSArray *expInputRedeemScripts = @[@"52410491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f864104865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec687441048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d4621353ae",
                                       @"52210387e679718c6a67f4f2c25a0b58df70067ec9f90c4297368e24fd5342027bec8521034a9ccd9aca88aa9d20c73289a075392e1cd67a5f33938a0443f530afa3675fcd21035bdd8633818888875bbc4232d384b411dc67f4efe11e6582de52d196adc6d29a53ae"];
    
    NSArray *expInputScripts = @[@"ff48304502200187af928e9d155c4b1ac9c1c9118153239aba76774f775d7c1f9c3e106ff33c0221008822b0f658edec22274d0b6ae9de10ebf2da06b1bbdaaba4e50eb078f39e3d78014730440220795f0f4f5941a77ae032ecb9e33753788d7eb5cb0c78d805575d6b00a1d9bfed02203e1f4ad9332d1416ae01e27038e945bc9db59c732728a383a6f1ed2fb99da7a4014cc952410491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f864104865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec687441048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d4621353ae"];

    NSArray *expMs = @[@2,
                       @2];

    NSArray *expNs = @[@3,
                       @3];
    
    NSArray *expSignatures = @[@[@"304502200187af928e9d155c4b1ac9c1c9118153239aba76774f775d7c1f9c3e106ff33c0221008822b0f658edec22274d0b6ae9de10ebf2da06b1bbdaaba4e50eb078f39e3d7801", @"30440220795f0f4f5941a77ae032ecb9e33753788d7eb5cb0c78d805575d6b00a1d9bfed02203e1f4ad9332d1416ae01e27038e945bc9db59c732728a383a6f1ed2fb99da7a401"]];
    
    NSArray *expPublicKeys = @[@[@"0491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f86", @"04865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec6874", @"048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d46213"],
                               @[@"0387e679718c6a67f4f2c25a0b58df70067ec9f90c4297368e24fd5342027bec85", @"034a9ccd9aca88aa9d20c73289a075392e1cd67a5f33938a0443f530afa3675fcd", @"035bdd8633818888875bbc4232d384b411dc67f4efe11e6582de52d196adc6d29a"]];
    
    for (NSUInteger i = 0; i < expAddresses.count; ++i) {
        WSParametersSetCurrentType([expNetworks[i] intValue]);
        
        WSAddress *expAddress = WSAddressFromString(expAddresses[i]);
        const NSUInteger expM = [expMs[i] unsignedIntegerValue];
        const NSUInteger expN = [expNs[i] unsignedIntegerValue];
        
        WSAddress *addressFromOutput = nil;
        WSAddress *addressFromInputRedeem = nil;
        WSAddress *addressFromInput = nil;

        NSMutableArray *checkSignatures = nil;
        if (i < expSignatures.count) {
            checkSignatures = [[NSMutableArray alloc] init];
            for (NSString *hex in expSignatures[i]) {
                [checkSignatures addObject:[hex dataFromHex]];
            }
        }
        NSMutableArray *checkPublicKeys = nil;
        if (i < expPublicKeys.count) {
            checkPublicKeys = [[NSMutableArray alloc] init];
            for (NSString *hex in expPublicKeys[i]) {
                [checkPublicKeys addObject:WSPublicKeyFromHex(hex)];
            }
        }

        if (i < expOutputScripts.count) {
            WSScript *outputScript = WSScriptFromHex(expOutputScripts[i]);
            DDLogInfo(@"Output script: %@", outputScript);

            addressFromOutput = [outputScript standardAddress];
            DDLogInfo(@"From output: %@", addressFromOutput);
            XCTAssertEqualObjects(addressFromOutput, expAddress);
        }
        
        if (i < expInputRedeemScripts.count) {
            WSScript *inputRedeemScript = WSScriptFromHex(expInputRedeemScripts[i]);
            DDLogInfo(@"Input redeem script: %@", inputRedeemScript);

            addressFromInputRedeem = [inputRedeemScript addressFromHash];
            DDLogInfo(@"From input redeem: %@", addressFromInputRedeem);
            XCTAssertEqualObjects(addressFromInputRedeem, expAddress);
            if (addressFromOutput) {
                XCTAssertEqualObjects(addressFromOutput, addressFromInputRedeem);
            }
            
            NSUInteger m, n;
            NSArray *publicKeys;
            const BOOL isMultiSig = [inputRedeemScript isScriptMultiSigReedemWithM:&m N:&n publicKeys:&publicKeys];

            XCTAssertTrue(isMultiSig);
            XCTAssertTrue((m == expM) && (n == expN), @"Not a %u-of-%u multiSig script", expM, expN);
            DDLogInfo(@"MultiSig: %u (%u-of-%u)", isMultiSig, m, n);
            
            if (checkPublicKeys) {
                XCTAssertEqualObjects(publicKeys, checkPublicKeys);
            }
        }

        if (i < expInputScripts.count) {
            WSScript *inputScript = WSScriptFromHex(expInputScripts[i]);
            DDLogInfo(@"Input script: %@", inputScript);

            addressFromInput = [inputScript standardAddress];
            DDLogInfo(@"From input: %@", addressFromInput);
            XCTAssertEqualObjects(addressFromInput, expAddress);
            if (addressFromOutput) {
                XCTAssertEqualObjects(addressFromOutput, addressFromInput);
            }
            
            NSArray *signatures;
            NSArray *publicKeys;
            const BOOL isMultiSig = [inputScript isScriptMultiSigWithSignatures:&signatures publicKeys:&publicKeys redeemScript:NULL];
            const NSUInteger m = signatures.count;
            const NSUInteger n = publicKeys.count;

            if (checkSignatures) {
                XCTAssertEqualObjects(signatures, checkSignatures);
            }
            if (checkPublicKeys) {
                XCTAssertEqualObjects(publicKeys, checkPublicKeys);
            }

            XCTAssertTrue(isMultiSig);
            XCTAssertTrue((m == expM) && (n == expN), @"Not a %u-of-%u multiSig script", expM, expN);
            DDLogInfo(@"MultiSig: %u (%u-of-%u)", isMultiSig, m, n);
        }
    }
}

- (void)testSignaturesFromMultisig
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    // tx = 7f53001bf79f5a874c018cce58471fd51a9444b564bbbb37032bda7f2beb9439
    NSString *expScriptHex = @"004830450220514685bdf8388e969bb19bdeff8be23cfbb346f096551ed7a9d919f4031881c5022100e5fd38b24c932fcade093c73216c7227aa5acd7c2619b7e6369de3269cf2c3a001483045022052ef60dc14532da93fa7acb82c897daf4d2ac56ddad779dff9f8519453484be5022100e6741933963ec1c09f41fc06bd48cc109d3647655cbfcbabafb5b2dea88dfcf8014c6952210387e679718c6a67f4f2c25a0b58df70067ec9f90c4297368e24fd5342027bec8521034a9ccd9aca88aa9d20c73289a075392e1cd67a5f33938a0443f530afa3675fcd21035bdd8633818888875bbc4232d384b411dc67f4efe11e6582de52d196adc6d29a53ae";
    NSArray *expSignatures = @[@"30450220514685bdf8388e969bb19bdeff8be23cfbb346f096551ed7a9d919f4031881c5022100e5fd38b24c932fcade093c73216c7227aa5acd7c2619b7e6369de3269cf2c3a001",
                               @"3045022052ef60dc14532da93fa7acb82c897daf4d2ac56ddad779dff9f8519453484be5022100e6741933963ec1c09f41fc06bd48cc109d3647655cbfcbabafb5b2dea88dfcf801"];

    WSScript *script = WSScriptFromHex(expScriptHex);
    DDLogInfo(@"Script chunks: %@", script.chunks);

    NSArray *signatures;
    XCTAssertTrue([script isScriptMultiSigWithSignatures:&signatures publicKeys:NULL redeemScript:NULL]);
    XCTAssertEqual(signatures.count, expSignatures.count);

    NSUInteger i = 0;
    for (NSData *sigData in signatures) {
        NSString *sig = [sigData hexString];
        NSString *expSig = expSignatures[i];

        DDLogInfo(@"Signature: %@", sig);
        DDLogInfo(@"Expected : %@", expSig);
        XCTAssertEqualObjects(sig, expSig);
        ++i;
    }
}

- (void)testComponentsFromMultiSig
{
    NSString *expScriptHex = @"0048304502200187af928e9d155c4b1ac9c1c9118153239aba76774f775d7c1f9c3e106ff33c0221008822b0f658edec22274d0b6ae9de10ebf2da06b1bbdaaba4e50eb078f39e3d78014730440220795f0f4f5941a77ae032ecb9e33753788d7eb5cb0c78d805575d6b00a1d9bfed02203e1f4ad9332d1416ae01e27038e945bc9db59c732728a383a6f1ed2fb99da7a4014cc952410491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f864104865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec687441048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d4621353ae";

    NSArray *expSignatures = @[@"304502200187af928e9d155c4b1ac9c1c9118153239aba76774f775d7c1f9c3e106ff33c0221008822b0f658edec22274d0b6ae9de10ebf2da06b1bbdaaba4e50eb078f39e3d7801",
                               @"30440220795f0f4f5941a77ae032ecb9e33753788d7eb5cb0c78d805575d6b00a1d9bfed02203e1f4ad9332d1416ae01e27038e945bc9db59c732728a383a6f1ed2fb99da7a401"];

    NSArray *expPubKeys = @[@"0491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f86",
                            @"04865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec6874",
                            @"048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d46213"];

    WSScript *script = WSScriptFromHex(expScriptHex);
    NSArray *signatures;
    NSArray *pubKeys;
    WSScript *redeemScript;
    XCTAssertTrue([script isScriptMultiSigWithSignatures:&signatures publicKeys:&pubKeys redeemScript:&redeemScript]);
    XCTAssertEqual(signatures.count, expSignatures.count);
    XCTAssertEqual(pubKeys.count, expPubKeys.count);

    DDLogInfo(@"Signatures: %@", signatures);
    DDLogInfo(@"Public keys: %@", pubKeys);
    DDLogInfo(@"Redeem script: %@", redeemScript);

    for (NSData *s in signatures) {
        XCTAssertEqualObjects(s, [expSignatures[[signatures indexOfObject:s]] dataFromHex]);
    }
    for (WSPublicKey *pk in pubKeys) {
        XCTAssertEqualObjects(pk, WSPublicKeyFromHex(expPubKeys[[pubKeys indexOfObject:pk]]));
    }
}

- (void)testPubKeysFromMultiSigRedeem
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    //
    // https://gist.github.com/gavinandresen/3966071
    //
    NSString *expScriptHex = @"52410491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f864104865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec687441048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d4621353ae";
    NSArray *expPubKeys = @[@"0491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f86",
                            @"04865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec6874",
                            @"048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d46213"];

    WSScript *script = WSScriptFromHex(expScriptHex);
    DDLogInfo(@"Script chunks: %@", script.chunks);
    
    NSUInteger m, n;
    NSArray *pubKeys;
    XCTAssertTrue([script isScriptMultiSigReedemWithM:&m N:&n publicKeys:&pubKeys]);
    XCTAssertNotNil(pubKeys);
    XCTAssertTrue((m == 2) && (n == 3), @"Not a 2-of-3 multiSig script");

    XCTAssertEqual(pubKeys.count, expPubKeys.count);
    
    NSUInteger i = 0;
    for (WSPublicKey *pubKey in pubKeys) {
        NSString *pubHex = [[pubKey encodedData] hexString];
        NSString *expPubHex = expPubKeys[i];
        
        DDLogInfo(@"Public key: %@", pubHex);
        DDLogInfo(@"Expected  : %@", expPubHex);
        XCTAssertEqualObjects(pubHex, expPubHex);
        ++i;
    }
}

- (void)testCoinbaseScripts
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    NSArray *expHexes = @[@"039311040453b59c390300000022000000",
                          @"03941104194b6e434d696e65724b5134c9115c1d3a93d01653b59d20038a0000000034020000"];
    NSArray *expLengths = @[@(17),
                            @(38)];
    NSArray *expHeights = @[@(266643),
                            @(266644)];

    NSUInteger i = 0;
    for (NSString *expHex in expHexes) {
        WSBuffer *scriptBuffer = WSBufferFromHex(expHex);
        WSCoinbaseScript *script = [WSCoinbaseScript scriptWithCoinbaseData:scriptBuffer.data];

        const NSUInteger scriptLength = [script estimatedSize];
        const NSUInteger expScriptLength = [expLengths[i] unsignedIntegerValue];
        DDLogInfo(@"Length  : %u", scriptLength);
        DDLogInfo(@"Expected: %u", expScriptLength);
        XCTAssertEqual(scriptLength, expScriptLength);

        DDLogInfo(@"Script: %@", script);
        
        const uint32_t height = script.blockHeight;
        const uint32_t expHeight = [expHeights[i] unsignedIntegerValue];
        DDLogInfo(@"Height  : %u", height);
        DDLogInfo(@"Expected: %u", expHeight);
        XCTAssertEqual(height, expHeight);
        
        ++i;
    }
}

- (void)testRetainPUSHDATA1
{
    NSString *hex = @"00493046022100cd7a20a6f066c5ca38d03fc881540764d7ad7e3610d883eb5c6af51a87564a0e022100b7b765b72d767f505bb97f704be24fe238b122e2c223b69808740ec5c67f410f01493046022100d2d2787996963e4cfa0b872034f2ed3b5e6493af4b41b25ad94b5ccec5860457022100bcfcdeda5fa09b9767d132da6d50858165c81184a70c786278118f923697cc2e014c47522102b17618332fc6429bf7ec3668666729b60d1d0c29dc7da96fd7343d5de75ccc0121027bc8492461d5f01e4191c55c690e2feabbaa2a5c74365535dba099ff514e503752ae";
//    NSString *bug = @"00493046022100cd7a20a6f066c5ca38d03fc881540764d7ad7e3610d883eb5c6af51a87564a0e022100b7b765b72d767f505bb97f704be24fe238b122e2c223b69808740ec5c67f410f01493046022100d2d2787996963e4cfa0b872034f2ed3b5e6493af4b41b25ad94b5ccec5860457022100bcfcdeda5fa09b9767d132da6d50858165c81184a70c786278118f923697cc2e0147522102b17618332fc6429bf7ec3668666729b60d1d0c29dc7da96fd7343d5de75ccc0121027bc8492461d5f01e4191c55c690e2feabbaa2a5c74365535dba099ff514e503752ae";
    WSScript *script = WSScriptFromHex(hex);
    
    DDLogInfo(@"Script: %@", script);
    DDLogInfo(@"Script (hex): %@", [[script toBuffer] hexString]);
    XCTAssertTrue([script.chunks[3] opcode] == WSScriptOpcode_PUSHDATA1);
}

- (void)testCopy
{
    NSArray *expSHexes = @[@"76a914d225dc4e19d0377a60c65a348bcc5cf35beada3a88ac",
                           @"004830450220514685bdf8388e969bb19bdeff8be23cfbb346f096551ed7a9d919f4031881c5022100e5fd38b24c932fcade093c73216c7227aa5acd7c2619b7e6369de3269cf2c3a001483045022052ef60dc14532da93fa7acb82c897daf4d2ac56ddad779dff9f8519453484be5022100e6741933963ec1c09f41fc06bd48cc109d3647655cbfcbabafb5b2dea88dfcf8014c6952210387e679718c6a67f4f2c25a0b58df70067ec9f90c4297368e24fd5342027bec8521034a9ccd9aca88aa9d20c73289a075392e1cd67a5f33938a0443f530afa3675fcd21035bdd8633818888875bbc4232d384b411dc67f4efe11e6582de52d196adc6d29a53ae",
                           @"52410491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f864104865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec687441048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d4621353ae",
                           @"52210387e679718c6a67f4f2c25a0b58df70067ec9f90c4297368e24fd5342027bec8521034a9ccd9aca88aa9d20c73289a075392e1cd67a5f33938a0443f530afa3675fcd21035bdd8633818888875bbc4232d384b411dc67f4efe11e6582de52d196adc6d29a53ae"];
    
    NSArray *expCBHexes = @[@"039311040453b59c390300000022000000",
                            @"03941104194b6e434d696e65724b5134c9115c1d3a93d01653b59d20038a0000000034020000"];

    for (NSString *hex in expSHexes) {
        WSScript *script = WSScriptFromHex(hex);
        
        XCTAssertEqualObjects([[script toBuffer] hexString], hex);
        
        WSScript *scriptCopy = [script copy];

        XCTAssertNotEqual(script, scriptCopy);
        XCTAssertEqualObjects(script, scriptCopy);
        XCTAssertEqualObjects([[scriptCopy toBuffer] hexString], hex);
    }

    for (NSString *hex in expCBHexes) {
        WSScript *script = WSCoinbaseScriptFromHex(hex);
        
        XCTAssertEqualObjects([[script toBuffer] hexString], hex);

        WSScript *scriptCopy = [script copy];
        
        XCTAssertNotEqual(script, scriptCopy);
        XCTAssertEqualObjects(script, scriptCopy);
        XCTAssertEqualObjects([[scriptCopy toBuffer] hexString], hex);
    }
}

@end
