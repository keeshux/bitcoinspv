//
//  WSAddressTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 20/06/14.
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

#import <XCTest/XCTest.h>

#import "WSPublicKey.h"
#import "NSData+Base58.h"

@interface WSAddressTests : XCTestCase

@end

@implementation WSAddressTests

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

- (void)testHex
{
    NSString *hex = @"03981313cfc4a2e7d5838937b8808d2d71fa4338592ac4f2ca9a27f16e8850550a";
    DDLogInfo(@"Hex: %@", hex);

    NSData *data = [hex dataFromHex];
    DDLogInfo(@"Data: %@", data);

    NSString *decodedHex = [data hexString];
    DDLogInfo(@"Hex: %@", hex);
    XCTAssertEqualObjects(hex, decodedHex);

    WSPublicKey *pubKey = [WSPublicKey publicKeyWithData:data];
    DDLogInfo(@"Public key: %@", pubKey);
    XCTAssertEqualObjects(data, pubKey.encodedData);
}

- (void)testAddressValidity
{
    NSString *address = @"1B6MVKEANZNLGoKntWvyu1yneaLLENYJTW";
    XCTAssertNotNil(WSAddressFromString(address), @"Invalid address");
    
    NSString *revAddress = [[address dataFromBase58Check] base58CheckString];
    XCTAssertEqualObjects(revAddress, address, @"Non-revertible address");
}

- (void)testAddressFromHex
{
    NSString *hexAddress = @"003564a74f9ddb4372301c49154605573d7d1a88fe";
    NSString *address = [hexAddress base58CheckFromHex];
    DDLogInfo(@"address: %@", address);

    NSString *expAddress = @"15sKPhXzhXbTRDHby15b45AeodmCWXzj8G";
    XCTAssertEqualObjects(address, expAddress);
}

@end
