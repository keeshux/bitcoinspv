//
//  WSWalletSerializationTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 24/06/14.
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
#import "WSKey.h"
#import "WSAddress.h"

#define WALLET_LOOK_AHEAD           10

@interface WSWalletSerializationTests : XCTestCase

@property (nonatomic, strong) NSString *path;

- (void)saveWallet:(WSHDWallet *)wallet;
- (WSHDWallet *)loadWallet;
- (WSHDWallet *)rehashWallet:(WSHDWallet *)wallet;

@end

@implementation WSWalletSerializationTests

- (void)setUp
{
    [super setUp];

    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    self.path = [self mockPathForFile:@"WalletSerializationTests.wallet"];

    NSString *mnemonic = [self mockWalletMnemonic];
    WSSeed *seed = WSSeedMakeNow(mnemonic);
    WSHDWallet *wallet = [[WSHDWallet alloc] initWithSeed:seed lookAhead:WALLET_LOOK_AHEAD];
    [self saveWallet:wallet];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testGenerate
{
    NSArray *expAddresses = @[@"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP",
                              @"mm4Z6thuZxVAYXXVU35KxzirnfFZ7YwszT",
                              @"mo6oWnaMKDE9Bq2w97p3RWCHAqDiFdyYQH",
                              @"myJkpby5M1vZaQFA8oeWafn8uC4xeTkqxo",
                              @"mzAgd2YqsvuwN442rtrwsfT9poi8fQLheN",
                              @"mvm26jv7vPUruu9RAgo4fL5ib5ewirdrgR",
                              @"n2Rne11pvJBtpVX7KkinPcSs5JJdpLPvaz",
                              @"mgRQ4ga3qpfNd8zmNh47AvsCoFGs6VdhNs",
                              @"mtiLfBPihhjXywbS2zuncePvbT1CJbSykH",
                              @"mv8RPQsf4XMh9RBBvCe1GaeCKXQSXAgj8y",
                              @"mgjkgSBEfR2K4XZM1vM5xxYzFfTExsvYc9",
                              @"mo6HhdAEKnLDivSZjWaeBN7AY26bxo78cT",
                              @"mkW2kGUwWQmVLEhmhjXZEPpHqhXreYemh1",
                              @"mzaFzmxd4wGSPrKGPPSJJRtEF9M2fd48EK",
                              @"n2ih2Xu5KBXjbQWr5Ny3R1F6wYtm9CpfkK",
                              @"mj8QJdeGp42s5ZPTmMVNhjZ73x81RaeBSC",
                              @"mneJie5MKSomH65cFAy8RcedTUXbTCUHwm",
                              @"miRebhcEsR9TJEnsCtS98bd41sjucyD1aP",
                              @"mypd5z33oeNqHvkWE6ZVoxCd5aChYNeVk4",
                              @"n4NvC9f4TEMDu6B23DE27fJnxkpddmoEGa"];

    NSMutableArray *addresses = nil;
    
    WSHDWallet *wallet = [self loadWallet];
    [wallet generateAddressesIfNeeded];

    addresses = [[NSMutableArray alloc] init];
    for (WSAddress *address in wallet.allAddresses) {
        [addresses addObject:address.encoded];
    }
    DDLogInfo(@"Addresses (%d): %@", addresses.count, addresses);
    XCTAssertEqualObjects(addresses, expAddresses);

    wallet = [self rehashWallet:wallet];
    
    addresses = [[NSMutableArray alloc] init];
    for (WSAddress *address in wallet.allAddresses) {
        [addresses addObject:address.encoded];
    }
    DDLogInfo(@"Deserialized addresses (%d): %@", addresses.count, addresses);
    XCTAssertEqualObjects(addresses, expAddresses);
}

- (void)testAddressPrivateKey
{
    WSHDWallet *wallet = [self loadWallet];

    WSAddress *expAddress = WSAddressFromString(@"mxxPia3SdVKxbcHSguq44RvSXHzFZkKsJP");
    WSKey *key = nil;
    WSAddress *address = nil;

    DDLogInfo(@"Key: %@", key);

    key = [wallet privateKeyForAddress:expAddress];
    XCTAssertNotNil(key);
    address = [key address];
    DDLogInfo(@"Address (eff): %@", address);
    DDLogInfo(@"Address (exp): %@", expAddress);
    XCTAssertEqualObjects(address, expAddress);
    
    wallet = [self rehashWallet:wallet];

    key = [wallet privateKeyForAddress:expAddress];
    XCTAssertNotNil(key);
    address = [key address];
    DDLogInfo(@"Deserialized address (eff): %@", address);
    DDLogInfo(@"Deserialized address (exp): %@", expAddress);
    XCTAssertEqualObjects(address, expAddress);
}

- (void)saveWallet:(WSHDWallet *)wallet
{
    [wallet saveToPath:self.path];
}

- (WSHDWallet *)loadWallet
{
    return [WSHDWallet loadFromPath:self.path mnemonic:[self mockWalletMnemonic] lookAhead:WALLET_LOOK_AHEAD];
}

- (WSHDWallet *)rehashWallet:(WSHDWallet *)wallet
{
    [self saveWallet:wallet];
    WSHDWallet *reloadedWallet = [self loadWallet];

    XCTAssertNotEqualObjects(reloadedWallet, wallet, @"Deserialized wallet must differ from original");
    return reloadedWallet;
}

@end
