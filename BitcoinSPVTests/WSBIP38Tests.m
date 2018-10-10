//
//  WSBIP38Tests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 07/12/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//
//  https://github.com/keeshux
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

@interface WSBIP38Tests : XCTestCase

@end

@implementation WSBIP38Tests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeMain;
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
    DDLogInfo(@"WIF: %@", [key WIFWithParameters:self.networkParameters]);
    XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], uncompressed);
    
    WSBIP38Key *bip38Key = [key encryptedBIP38KeyWithParameters:self.networkParameters passphrase:passphrase];
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
    DDLogInfo(@"WIF: %@", [key WIFWithParameters:self.networkParameters]);
    XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], uncompressed);
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
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);

        key = [WSKey keyWithWIF:decryptedWIFs[i] parameters:self.networkParameters];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);

//        bip38Key = [key encryptedBIP38KeyWithPassphrase:passphrases[i] ec:NO];
        bip38Key = [key encryptedBIP38KeyWithParameters:self.networkParameters passphrase:passphrases[i]];
        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);

        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);
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
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);

        key = [WSKey keyWithWIF:decryptedWIFs[i] parameters:self.networkParameters];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);

//        bip38Key = [key encryptedBIP38KeyWithParameters:self.networkParameters passphrase:passphrases[i] ec:NO];
        bip38Key = [key encryptedBIP38KeyWithParameters:self.networkParameters passphrase:passphrases[i]];
        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);

        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);
    }
}

- (void)testVectorECUncompressed
{
    NSArray *passphrases = @[@"TestingOneTwoThree",
                             @"Satoshi"];
//    NSArray *passphraseCodes = @[@"passphrasepxFy57B9v8HtUsszJYKReoNDV6VHjUSGt8EVJmux9n1J3Ltf1gRxyDGXqnf9qm",
//                                 @"passphraseoRDGAXTWzbp72eVbtUDdn1rwpgPUGjNZEc6CGBo8i5EC1FPW8wcnLdq4ThKzAS"];
    NSArray *encrypted = @[@"6PfQu77ygVyJLZjfvMLyhLMQbYnu5uguoJJ4kMCLqWwPEdfpwANVS76gTX",
                           @"6PfLGnQs6VZnrNpmVKfjotbnQuaJK4KZoPFrAjx1JMJUa1Ft8gnf5WxfKd"];
    NSArray *addresses = @[@"1PE6TQi6HTVNz5DLwB1LcpMBALubfuN2z2",
                           @"1CqzrtZC6mXSAhoxtFwVjz8LtwLJjDYU3V"];
    NSArray *decryptedWIFs = @[@"5K4caxezwjGCGfnoPTZ8tMcJBLB7Jvyjv4xxeacadhq8nLisLR2",
                               @"5KJ51SgxWaAYR13zd9ReMhJpwrcX47xTJh2D3fGPG9CM8vkv5sH"];
    NSArray *decryptedHexes = @[@"A43A940577F4E97F5C4D39EB14FF083A98187C64EA7C99EF7CE460833959A519",
                                @"C2C8036DF268F498099350718C4A3EF3984D2BE84618C2650F5171DCC5EB660A"];
    
    WSKey *key;
    WSBIP38Key *bip38Key;
    
    for (NSUInteger i = 0; i < passphrases.count; ++i) {
        bip38Key = [[WSBIP38Key alloc] initWithEncrypted:encrypted[i]];
        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);
        
        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);
        XCTAssertEqualObjects([key addressWithParameters:self.networkParameters].encoded, addresses[i]);
        
        key = [WSKey keyWithWIF:decryptedWIFs[i] parameters:self.networkParameters];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);
        XCTAssertEqualObjects([key addressWithParameters:self.networkParameters].encoded, addresses[i]);
        
//        bip38Key = [key encryptedBIP38KeyWithParameters:self.networkParameters passphrase:passphrases[i] ec:YES];
//        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);
//        
//        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
//        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
//        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);
//        XCTAssertEqualObjects([key addressWithParameters:self.networkParameters].encoded, addresses[i]);
    }
}

- (void)testVectorECUncompressedLotSequence
{
    NSArray *passphrases = @[@"MOLON LABE",
                             @"ΜΟΛΩΝ ΛΑΒΕ"];
//    NSArray *passphraseCodes = @[@"passphraseaB8feaLQDENqCgr4gKZpmf4VoaT6qdjJNJiv7fsKvjqavcJxvuR1hy25aTu5sX",
//                                 @"passphrased3z9rQJHSyBkNBwTRPkUGNVEVrUAcfAXDyRU1V28ie6hNFbqDwbFBvsTK7yWVK"];
    NSArray *encrypted = @[@"6PgNBNNzDkKdhkT6uJntUXwwzQV8Rr2tZcbkDcuC9DZRsS6AtHts4Ypo1j",
                           @"6PgGWtx25kUg8QWvwuJAgorN6k9FbE25rv5dMRwu5SKMnfpfVe5mar2ngH"];
    NSArray *addresses = @[@"1Jscj8ALrYu2y9TD8NrpvDBugPedmbj4Yh",
                           @"1Lurmih3KruL4xDB5FmHof38yawNtP9oGf"];
    NSArray *decryptedWIFs = @[@"5JLdxTtcTHcfYcmJsNVy1v2PMDx432JPoYcBTVVRHpPaxUrdtf8",
                               @"5KMKKuUmAkiNbA3DazMQiLfDq47qs8MAEThm4yL8R2PhV1ov33D"];
    NSArray *decryptedHexes = @[@"44EA95AFBF138356A05EA32110DFD627232D0F2991AD221187BE356F19FA8190",
                                @"CA2759AA4ADB0F96C414F36ABEB8DB59342985BE9FA50FAAC228C8E7D90E3006"];
    
    WSKey *key;
    WSBIP38Key *bip38Key;
    
    for (NSUInteger i = 0; i < passphrases.count; ++i) {
        bip38Key = [[WSBIP38Key alloc] initWithEncrypted:encrypted[i]];
        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);
        
        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);
        XCTAssertEqualObjects([key addressWithParameters:self.networkParameters].encoded, addresses[i]);
        
        key = [WSKey keyWithWIF:decryptedWIFs[i] parameters:self.networkParameters];
        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);
        XCTAssertEqualObjects([key addressWithParameters:self.networkParameters].encoded, addresses[i]);
        
//        bip38Key = [key encryptedBIP38KeyWithParameters:self.networkParameters passphrase:passphrases[i] ec:YES];
//        XCTAssertEqualObjects(bip38Key.encrypted, encrypted[i]);
//
//        key = [bip38Key decryptedKeyWithPassphrase:passphrases[i]];
//        XCTAssertEqualObjects(key.data, [decryptedHexes[i] dataFromHex]);
//        XCTAssertEqualObjects([key WIFWithParameters:self.networkParameters], decryptedWIFs[i]);
//        XCTAssertEqualObjects([key addressWithParameters:self.networkParameters].encoded, addresses[i]);
    }
}

@end
