//
//  WSBIP32Tests.m
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
#import "WSHDKeyring.h"
#import "WSKey.h"
#import "WSPublicKey.h"

@interface WSBIP32Tests : XCTestCase

@end

@implementation WSBIP32Tests

- (void)setUp
{
    [super setUp];

    WSParametersSetCurrentType(WSParametersTypeMain);
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testVector1
{
    NSData *keyData = [@"000102030405060708090a0b0c0d0e0f" dataFromHex];
    WSHDKeyring *bip32 = [[WSHDKeyring alloc] initWithData:keyData];
    
    NSArray *paths = @[@"m",
                       @"m/0'",
                       @"m/0'/1",
                       @"m/0'/1/2'",
                       @"m/0'/1/2'/2",
                       @"m/0'/1/2'/2/1000000000"];
    
    NSArray *pubKeys = @[@"xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8",
                         @"xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw",
                         @"xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ",
                         @"xpub6D4BDPcP2GT577Vvch3R8wDkScZWzQzMMUm3PWbmWvVJrZwQY4VUNgqFJPMM3No2dFDFGTsxxpG5uJh7n7epu4trkrX7x7DogT5Uv6fcLW5",
                         @"xpub6FHa3pjLCk84BayeJxFW2SP4XRrFd1JYnxeLeU8EqN3vDfZmbqBqaGJAyiLjTAwm6ZLRQUMv1ZACTj37sR62cfN7fe5JnJ7dh8zL4fiyLHV",
                         @"xpub6H1LXWLaKsWFhvm6RVpEL9P4KfRZSW7abD2ttkWP3SSQvnyA8FSVqNTEcYFgJS2UaFcxupHiYkro49S8yGasTvXEYBVPamhGW6cFJodrTHy"];
    
    NSArray *privKeys = @[@"xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi",
                          @"xprv9uHRZZhk6KAJC1avXpDAp4MDc3sQKNxDiPvvkX8Br5ngLNv1TxvUxt4cV1rGL5hj6KCesnDYUhd7oWgT11eZG7XnxHrnYeSvkzY7d2bhkJ7",
                          @"xprv9wTYmMFdV23N2TdNG573QoEsfRrWKQgWeibmLntzniatZvR9BmLnvSxqu53Kw1UmYPxLgboyZQaXwTCg8MSY3H2EU4pWcQDnRnrVA1xe8fs",
                          @"xprv9z4pot5VBttmtdRTWfWQmoH1taj2axGVzFqSb8C9xaxKymcFzXBDptWmT7FwuEzG3ryjH4ktypQSAewRiNMjANTtpgP4mLTj34bhnZX7UiM",
                          @"xprvA2JDeKCSNNZky6uBCviVfJSKyQ1mDYahRjijr5idH2WwLsEd4Hsb2Tyh8RfQMuPh7f7RtyzTtdrbdqqsunu5Mm3wDvUAKRHSC34sJ7in334",
                          @"xprvA41z7zogVVwxVSgdKUHDy1SKmdb533PjDz7J6N6mV6uS3ze1ai8FHa8kmHScGpWmj4WggLyQjgPie1rFSruoUihUZREPSL39UNdE3BBDu76"];
    
    [self testBIP32:bip32 paths:paths pubKeys:pubKeys privKeys:privKeys];
}

- (void)testVector2
{
    NSData *keyData = [@"fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542" dataFromHex];
    WSHDKeyring *bip32 = [[WSHDKeyring alloc] initWithData:keyData];
    
    NSArray *paths = @[@"m",
                       @"m/0",
                       @"m/0/2147483647'",
                       @"m/0/2147483647'/1",
                       @"m/0/2147483647'/1/2147483646'",
                       @"m/0/2147483647'/1/2147483646'/2"];
    
    NSArray *pubKeys = @[@"xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB",
                         @"xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH",
                         @"xpub6ASAVgeehLbnwdqV6UKMHVzgqAG8Gr6riv3Fxxpj8ksbH9ebxaEyBLZ85ySDhKiLDBrQSARLq1uNRts8RuJiHjaDMBU4Zn9h8LZNnBC5y4a",
                         @"xpub6DF8uhdarytz3FWdA8TvFSvvAh8dP3283MY7p2V4SeE2wyWmG5mg5EwVvmdMVCQcoNJxGoWaU9DCWh89LojfZ537wTfunKau47EL2dhHKon",
                         @"xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL",
                         @"xpub6FnCn6nSzZAw5Tw7cgR9bi15UV96gLZhjDstkXXxvCLsUXBGXPdSnLFbdpq8p9HmGsApME5hQTZ3emM2rnY5agb9rXpVGyy3bdW6EEgAtqt"];
    
    NSArray *privKeys = @[@"xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U",
                          @"xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt",
                          @"xprv9wSp6B7kry3Vj9m1zSnLvN3xH8RdsPP1Mh7fAaR7aRLcQMKTR2vidYEeEg2mUCTAwCd6vnxVrcjfy2kRgVsFawNzmjuHc2YmYRmagcEPdU9",
                          @"xprv9zFnWC6h2cLgpmSA46vutJzBcfJ8yaJGg8cX1e5StJh45BBciYTRXSd25UEPVuesF9yog62tGAQtHjXajPPdbRCHuWS6T8XA2ECKADdw4Ef",
                          @"xprvA1RpRA33e1JQ7ifknakTFpgNXPmW2YvmhqLQYMmrj4xJXXWYpDPS3xz7iAxn8L39njGVyuoseXzU6rcxFLJ8HFsTjSyQbLYnMpCqE2VbFWc",
                          @"xprvA2nrNbFZABcdryreWet9Ea4LvTJcGsqrMzxHx98MMrotbir7yrKCEXw7nadnHM8Dq38EGfSh6dqA9QWTyefMLEcBYJUuekgW4BYPJcr9E7j"];
    
    [self testBIP32:bip32 paths:paths pubKeys:pubKeys privKeys:privKeys];
}

- (void)testVector2Recursive
{
    NSData *keyData = [@"fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542" dataFromHex];
    id<WSBIP32Keyring> bip32 = [[WSHDKeyring alloc] initWithData:keyData];
    
    NSArray *nodes = @[@"m",
                       @"0",
                       @"2147483647'",
                       @"1",
                       @"2147483646'",
                       @"2"];
    
    NSArray *pubKeys = @[@"xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB",
                         @"xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH",
                         @"xpub6ASAVgeehLbnwdqV6UKMHVzgqAG8Gr6riv3Fxxpj8ksbH9ebxaEyBLZ85ySDhKiLDBrQSARLq1uNRts8RuJiHjaDMBU4Zn9h8LZNnBC5y4a",
                         @"xpub6DF8uhdarytz3FWdA8TvFSvvAh8dP3283MY7p2V4SeE2wyWmG5mg5EwVvmdMVCQcoNJxGoWaU9DCWh89LojfZ537wTfunKau47EL2dhHKon",
                         @"xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL",
                         @"xpub6FnCn6nSzZAw5Tw7cgR9bi15UV96gLZhjDstkXXxvCLsUXBGXPdSnLFbdpq8p9HmGsApME5hQTZ3emM2rnY5agb9rXpVGyy3bdW6EEgAtqt"];
    
    NSArray *privKeys = @[@"xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U",
                          @"xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt",
                          @"xprv9wSp6B7kry3Vj9m1zSnLvN3xH8RdsPP1Mh7fAaR7aRLcQMKTR2vidYEeEg2mUCTAwCd6vnxVrcjfy2kRgVsFawNzmjuHc2YmYRmagcEPdU9",
                          @"xprv9zFnWC6h2cLgpmSA46vutJzBcfJ8yaJGg8cX1e5StJh45BBciYTRXSd25UEPVuesF9yog62tGAQtHjXajPPdbRCHuWS6T8XA2ECKADdw4Ef",
                          @"xprvA1RpRA33e1JQ7ifknakTFpgNXPmW2YvmhqLQYMmrj4xJXXWYpDPS3xz7iAxn8L39njGVyuoseXzU6rcxFLJ8HFsTjSyQbLYnMpCqE2VbFWc",
                          @"xprvA2nrNbFZABcdryreWet9Ea4LvTJcGsqrMzxHx98MMrotbir7yrKCEXw7nadnHM8Dq38EGfSh6dqA9QWTyefMLEcBYJUuekgW4BYPJcr9E7j"];
    
    NSUInteger i = 0;
    for (NSString *n in nodes) {
        WSBIP32Node *node = [WSBIP32Node nodeWithString:n];
        if (node) {
            bip32 = [bip32 keyringAtNodes:@[node]];
        }
        WSBIP32Key *epubKey = [bip32 extendedPublicKey];
        WSBIP32Key *eprivKey = [bip32 extendedPrivateKey];
        
        NSString *testPub = pubKeys[i];
        NSString *testPriv = privKeys[i];
        
        DDLogInfo(@"%@ (PUB): %@", n, [[epubKey serializedKey] hexFromBase58Check]);
        DDLogInfo(@"%@ (PUB): %@", n, [testPub hexFromBase58Check]);
        DDLogInfo(@"%@ (PRV): %@", n, [[eprivKey serializedKey] hexFromBase58Check]);
        DDLogInfo(@"%@ (PRV): %@", n, [testPriv hexFromBase58Check]);
        DDLogInfo(@"");
        
        XCTAssertEqualObjects([epubKey serializedKey], testPub, @"Depth %d", i);
        XCTAssertEqualObjects([eprivKey serializedKey], testPriv, @"Depth %d", i);
        
        ++i;
    }
}

- (void)testPublicDerivation
{
    NSData *keyData = [@"fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542" dataFromHex];
    id<WSBIP32Keyring> bip32 = [[WSHDKeyring alloc] initWithData:keyData];
    id<WSBIP32PublicKeyring> bip32Public = nil;
    id<WSBIP32Keyring> parent = nil;
    NSMutableArray *keys = [[NSMutableArray alloc] init];
    
    // "m/0"
    [keys addObject:bip32.extendedPublicKey];
    bip32Public = [[bip32 publicKeyring] publicKeyringForAccount:0];
    [keys addObject:[bip32Public extendedPublicKey]];
    
    // "m/0/2147483647'/1"
    parent = [bip32 keyringAtPath:@"m/0/2147483647'"];
    bip32Public = [[parent publicKeyring] publicKeyringForAccount:1];
    [keys addObject:[bip32Public extendedPublicKey]];
    
    // "m/0/2147483647'/1/2147483646'/2"
    parent = [bip32 keyringAtPath:@"m/0/2147483647'/1/2147483646'"];
    bip32Public = [[parent publicKeyring] publicKeyringForAccount:2];
    [keys addObject:[bip32Public extendedPublicKey]];
    
    NSArray *pubKeys = @[@"xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB",
                         @"xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH",
                         @"xpub6DF8uhdarytz3FWdA8TvFSvvAh8dP3283MY7p2V4SeE2wyWmG5mg5EwVvmdMVCQcoNJxGoWaU9DCWh89LojfZ537wTfunKau47EL2dhHKon",
                         @"xpub6FnCn6nSzZAw5Tw7cgR9bi15UV96gLZhjDstkXXxvCLsUXBGXPdSnLFbdpq8p9HmGsApME5hQTZ3emM2rnY5agb9rXpVGyy3bdW6EEgAtqt"];
    
    NSUInteger i = 0;
    for (WSBIP32Key *key in keys) {
        NSString *testPub = pubKeys[i];
        
//        DDLogInfo(@"%@", [key serializedKey]);
//        DDLogInfo(@"%@", testPub);
        DDLogInfo(@"%@", [[key serializedKey] hexFromBase58Check]);
        DDLogInfo(@"%@", [testPub hexFromBase58Check]);
        DDLogInfo(@"");
        
        XCTAssertEqualObjects([key serializedKey], testPub, @"Key %d", i);
        
        ++i;
    }
}

- (void)testBIP32org
{
    NSString *mnemonic = [self mockWalletMnemonic];
    NSData *keyData = [[mnemonic dataUsingEncoding:NSUTF8StringEncoding] SHA256]; // weak hash
    WSHDKeyring *bip32 = [[WSHDKeyring alloc] initWithData:keyData];
    
    DDLogInfo(@"Mnemonic SHA256: %@", [keyData hexString]);
    
    WSBIP32Key *extendedPrivateKey = [bip32 extendedPrivateKey];
    DDLogInfo(@"Master private key");

    NSString *chain = [extendedPrivateKey.chainData hexString];
    NSString *expChain = @"256b4cfa72e1c3fa43d1a5fb61a1535422f3a197d7e1dc96ab797a251047234d";
    DDLogInfo(@"\tChain: %@", chain);
    XCTAssertEqualObjects(chain, expChain);
    
    NSString *privateKey = [[extendedPrivateKey privateKey] WIF];
    NSString *expPrivateKey = @"L29Lv3Mb3hq1VnYd8jnUekA6KUaVDecdFDUMUKDBp9exgmVhsLHU";
    DDLogInfo(@"\tKey: %@", privateKey);
    XCTAssertEqualObjects(privateKey, expPrivateKey);
    
    DDLogInfo(@"");
    
    NSArray *paths = @[@"m",
                       @"m/12",
                       @"m/0'/0",
                       @"m/0'/0/729"];
    
    NSArray *pubKeys = @[@"xpub661MyMwAqRbcEv3PACegJA8S28damt6Kw74m2dJSE6ojAZWABwYGeUvZxPwHuD5monLUwuAjG2PetDSfmdWtbUUtiBwk1YHij4QGLZPhHXL",
                         @"xpub68b6BBTbaDHL3unStuwMjnpjYZfnYQXpDot65r8PHHtWjJqAXayh1tRtezpfGUvHBPgJw3jucP1J4yh7zEf6TnYGWeHkNhh3mhmdD7gjpaZ",
                         @"xpub6BMATgTzRTd7kpu5XD6rVqj2xAQbFg9buTW8rJHDRRvgqBnZ7ZP7ENg4kFfQG9kNTKEGoffLE45oiMjuXJqHMrdVWnbzG2ZgAjoLujcYAik",
                         @"xpub6CF2yVtKdVdwhViRmzcUZbxZgcCgY1L6jkbNpmEDT61YYDrejoqiA1GjS2JZL3GwdEQbHPPccHZwh35Ae4xJjK9d41iTupXVYULJLxFKUwJ"];
    
    NSArray *privKeys = @[@"xprv9s21ZrQH143K2Rxv4B7fw2BhU6o6NRNUZt9AEEtpfmGkHmB1eQE26gc676MmTZxKTEnrccVjzc3M3EvxRmz9Edb9iUnaisZPGyALEpiXjGd",
                          @"xprv9ubjmfvhjqj2qRhyntQMNeszzXqJ8woxraxVHTimixMXrWW1z3fSU67QohDFUAmufVLUrvfgmp1mgRvwz88uR5TPKQnoFPJYaapiKtgxjDG",
                          @"xprv9xMp4Aw6b64pYLpcRBZr8hnJQ8a6rDRkYEaY3usbs6PhxPTQa24rgaMatzueYCxqr7agCXwEdxUe8tpSRVFyGhnxoRaTLN4NMaAmdw3uH63",
                          @"xprv9yFgZzMRo85eV1dxfy5UCU1q8aNC8YcFNXfn2NpbtkUZfRXWCGXTcCxFaiNptyYPBG8fHZEagRZovpUr86ZusbhoKRzz1myPznkogJCDKVU"];
    
    [self testBIP32:bip32 paths:paths pubKeys:pubKeys privKeys:privKeys];
}

- (void)testAddresses
{
    NSString *mnemonic = [self mockWalletMnemonic];
    NSData *keyData = [[mnemonic dataUsingEncoding:NSUTF8StringEncoding] SHA256]; // weak hash
    WSHDKeyring *bip32 = [[WSHDKeyring alloc] initWithData:keyData];
    
    NSArray *expected = @[@"1Jw5NY8HQbhU4REtAFWeHuex9o5ht8USki",
                          @"17k1Sda8JwCMKZZbFMepayFnGKQZpc71dd",
                          @"1LcFSxUpaKzRqjSyqAh5f6VaxGHsk8gAbw",
                          @"13J8955TKzgrLfFR1jnhdEeKu3mtFnikwm",
                          @"12iajn9SD2XY6r8CRgn4wARQTmogUrKndb",
                          @"1B6MVKEANZNLGoKntWvyu1yneaLLENYJTW",
                          @"1GadZqrxovUB8CuPDrxZ9am7t98fE3mNo9",
                          @"1B6vCVnhYQsLdqtSDpdD9ivSi2M4skVtL3",
                          @"1BU3qBgbtojQM2Wu6zBzGRDAsgupUUmeG1",
                          @"1P1VuGVWSraPnn4iCf9FtbGPQCt2JpBF58"];
    
    const uint32_t account = 8937;
    const BOOL internal = YES;
    id<WSBIP32Keyring> chain = [bip32 chainForAccount:account internal:internal];
    id<WSBIP32PublicKeyring> pubChain = [bip32 publicChainForAccount:account internal:internal];
    
    for (uint32_t i = 0; i < 10; ++i) {
        id<WSBIP32Keyring> keyring = [chain keyringForAccount:i];
        WSPublicKey *pubKey = [[keyring extendedPublicKey] publicKey];
        WSAddress *address = [pubKey address];
        DDLogInfo(@"m/%d/1/%d: %@", account, i, address);
        
        id<WSBIP32PublicKeyring> pubKeyring = [pubChain publicKeyringForAccount:i];
        WSPublicKey *publicPubKey = [[pubKeyring extendedPublicKey] publicKey];
        WSAddress *publicAddress = [publicPubKey address];
        DDLogInfo(@"m/%d/1/%d: %@", account, i, publicAddress);
        
        XCTAssertEqualObjects(address, publicAddress, @"i = %d", i);
        XCTAssertEqualObjects(address, WSAddressFromString(expected[i]), @"i = %d", i);
    }
}

- (void)testSequentialTime
{
    NSString *mnemonic = [self mockWalletMnemonic];
    NSData *keyData = [[mnemonic dataUsingEncoding:NSUTF8StringEncoding] SHA256]; // weak hash
    WSHDKeyring *bip32 = [[WSHDKeyring alloc] initWithData:keyData];
    const NSUInteger count = 100;
    NSTimeInterval startTime;
    
    startTime = [NSDate timeIntervalSinceReferenceDate];
    for (NSUInteger i = 0; i < count; ++i) {
        [bip32 privateKeyForAccount:i];
    }
    DDLogInfo(@"%u private keys = %.3fs", count, [NSDate timeIntervalSinceReferenceDate] - startTime);

    startTime = [NSDate timeIntervalSinceReferenceDate];
    for (NSUInteger i = 0; i < count; ++i) {
        [bip32 publicKeyForAccount:i];
    }
    DDLogInfo(@"%u public keys = %.3fs", count, [NSDate timeIntervalSinceReferenceDate] - startTime);

    startTime = [NSDate timeIntervalSinceReferenceDate];
    for (NSUInteger i = 0; i < count; ++i) {
        [[bip32 privateKeyForAccount:i] publicKey];
    }
    DDLogInfo(@"%u public keys (indirect) = %.3fs", count, [NSDate timeIntervalSinceReferenceDate] - startTime);
}

- (void)testBIP32:(id<WSBIP32Keyring>)bip32 paths:(NSArray *)paths pubKeys:(NSArray *)pubKeys privKeys:(NSArray *)privKeys
{
    NSUInteger i = 0;
    for (NSString *p in paths) {
//        if (pi != 2) {
//            continue;
//        }

//        DDLogInfo(@"%@", p);
//        NSArray *nodes = [WSBIP32Node parseNodesFromPath:p];
//        DDLogInfo(@"%@: %@", p, nodes);
        
        id<WSBIP32Keyring> keyring = [bip32 keyringAtPath:p];
        WSBIP32Key *pubKey = [keyring extendedPublicKey];
        WSBIP32Key *privKey = [keyring extendedPrivateKey];
        
        NSString *testPub = pubKeys[i];
        NSString *testPriv = privKeys[i];
        
        DDLogInfo(@"%@ (PUB): %@", p, [[pubKey serializedKey] hexFromBase58Check]);
        DDLogInfo(@"%@ (PUB): %@", p, [testPub hexFromBase58Check]);
        DDLogInfo(@"%@ (PRV): %@", p, [[privKey serializedKey] hexFromBase58Check]);
        DDLogInfo(@"%@ (PRV): %@", p, [testPriv hexFromBase58Check]);
        DDLogInfo(@"");
        
        XCTAssertEqualObjects([pubKey serializedKey], testPub);
        XCTAssertEqualObjects([privKey serializedKey], testPriv);
        
        ++i;
    }
}

@end
