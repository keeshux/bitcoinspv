//
//  WSBIP38Tests.m
//  WaSPV
//
//  Created by Davide De Rosa on 07/12/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//

#import "XCTestCase+WaSPV.h"
#import "WSBIP38.h"

@interface WSBIP38Tests : XCTestCase

@end

@implementation WSBIP38Tests

- (void)setUp
{
    [super setUp];

    WSParametersSetCurrentType(WSParametersTypeMain);
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testEncryption
{
    NSString *encrypted = @"6PRRPwBTHvkytPHLwYEXUznJWzpUQi5NHpnsvwM51KRJipLPdKJSd6pmjd";
    NSString *passphrase = @"asd";
    NSString *hex = @"CC08F703368BF1C96A3705362BA3B294C9CF362D240EA6C9C960EA9718D62646";
//    NSString *compressed = @"L44KzeCmVXJ2PtpYzekui9h5NnoYWNjVtYWUUYkBBL1ro9S7c5P3";
    NSString *uncompressed = @"5KN9P852UJjptroa5TE7xYRVBNhuT96YvNBkqP9RWXbBNsrpxzN";
    
    WSKey *key = [WSKey keyWithData:[hex dataFromHex] compressed:NO];
    DDLogInfo(@"Hex (eff): %@", [key.data hexString]);
    DDLogInfo(@"Hex (exp): %@", [hex lowercaseString]);
    XCTAssertEqualObjects(key.data, [hex dataFromHex]);
    DDLogInfo(@"WIF: %@", [key WIF]);
    XCTAssertEqualObjects([key WIF], uncompressed);
    
    WSBIP38Key *bip38Key = [key encryptedBIP38KeyWithPassphrase:passphrase];
    DDLogInfo(@"BIP38: %@", bip38Key);
    XCTAssertEqualObjects(bip38Key.encrypted, encrypted);
}

- (void)testDecryption
{
    NSString *encrypted = @"6PRRPwBTHvkytPHLwYEXUznJWzpUQi5NHpnsvwM51KRJipLPdKJSd6pmjd";
    NSString *passphrase = @"asd";
    NSString *hex = @"CC08F703368BF1C96A3705362BA3B294C9CF362D240EA6C9C960EA9718D62646";
//    NSString *compressed = @"L44KzeCmVXJ2PtpYzekui9h5NnoYWNjVtYWUUYkBBL1ro9S7c5P3";
    NSString *uncompressed = @"5KN9P852UJjptroa5TE7xYRVBNhuT96YvNBkqP9RWXbBNsrpxzN";

    WSBIP38Key *bip38Key = [[WSBIP38Key alloc] initWithEncrypted:encrypted];
    DDLogInfo(@"BIP38: %@", bip38Key);
    XCTAssertEqualObjects(bip38Key.encrypted, encrypted);

    WSKey *key = [bip38Key decryptedKeyWithPassphrase:passphrase];
    DDLogInfo(@"Hex (eff): %@", [key.data hexString]);
    DDLogInfo(@"Hex (exp): %@", [hex lowercaseString]);
    XCTAssertEqualObjects(key.data, [hex dataFromHex]);
    DDLogInfo(@"WIF: %@", [key WIF]);
    XCTAssertEqualObjects([key WIF], uncompressed);
}

- (void)testVectorNonECUncompressed
{
    NSArray *passphrases = @[@"TestingOneTwoThree",
                             @"Satoshi"];
    NSArray *encrypted = @[@"6PRVWUbkzzsbcVac2qwfssoUJAN1Xhrg6bNk8J7Nzm5H7kxEbn2Nh2ZoGg",
                           @"6PRNFFkZc2NZ6dJqFfhRoFNMR9Lnyj7dYGrzdgXXVMXcxoKTePPX1dWByq"];
    NSArray *decryptedWIFs = @[@"5KN7MzqK5wt2TP1fQCYyHBtDrXdJuXbUzm4A9rKAteGu3Qi5CVR",
                               @"5HtasZ6ofTHP6HCwTqTkLDuLQisYPah7aUnSKfC7h4hMUVw2gi5"];
    NSArray *decryptedHexes = @[@"CBF4B9F70470856BB4F40F80B87EDB90865997FFEE6DF315AB166D713AF433A5",
                                @"09C2686880095B1A4C249EE3AC4EEA8A014F11E6F986D0B5025AC1F39AFBD9AE"];

    WSKey *key;
    WSBIP38Key *bip38Key;

    for (NSUInteger i = 0; i < passphrases.count; ++i) {
        bip38Key = [[WSBIP38Key alloc] initWithEncrypted:encrypted[i]];
        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);

        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(key.WIF, decryptedWIFs[i]);
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);

        key = [WSKey keyWithWIF:decryptedWIFs[i]];
        XCTAssertEqualObjects(key.WIF, decryptedWIFs[i]);
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);

        bip38Key = [key encryptedBIP38KeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);

        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects(key.WIF, decryptedWIFs[i]);
    }
}

- (void)testVectorNonECCompressed
{
    NSArray *passphrases = @[@"TestingOneTwoThree",
                             @"Satoshi"];
    NSArray *encrypted = @[@"6PYNKZ1EAgYgmQfmNVamxyXVWHzK5s6DGhwP4J5o44cvXdoY7sRzhtpUeo",
                           @"6PYLtMnXvfG3oJde97zRyLYFZCYizPU5T3LwgdYJz1fRhh16bU7u6PPmY7"];
    NSArray *decryptedWIFs = @[@"L44B5gGEpqEDRS9vVPz7QT35jcBG2r3CZwSwQ4fCewXAhAhqGVpP",
                               @"KwYgW8gcxj1JWJXhPSu4Fqwzfhp5Yfi42mdYmMa4XqK7NJxXUSK7"];
    NSArray *decryptedHexes = @[@"CBF4B9F70470856BB4F40F80B87EDB90865997FFEE6DF315AB166D713AF433A5",
                                @"09C2686880095B1A4C249EE3AC4EEA8A014F11E6F986D0B5025AC1F39AFBD9AE"];

    WSKey *key;
    WSBIP38Key *bip38Key;
    
    for (NSUInteger i = 0; i < passphrases.count; ++i) {
        bip38Key = [[WSBIP38Key alloc] initWithEncrypted:encrypted[i]];
        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);
        
        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(key.WIF, decryptedWIFs[i]);
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);

        key = [WSKey keyWithWIF:decryptedWIFs[i]];
        XCTAssertEqualObjects(key.WIF, decryptedWIFs[i]);
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);

        bip38Key = [key encryptedBIP38KeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);

        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects(key.WIF, decryptedWIFs[i]);
    }
}

@end
