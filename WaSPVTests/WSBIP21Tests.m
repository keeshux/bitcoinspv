//
//  WSBIP21Tests.m
//  WaSPV
//
//  Created by Davide De Rosa on 08/12/14.
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
#import "WaSPV.h"

@interface WSBIP21Tests : XCTestCase

@end

@implementation WSBIP21Tests

- (void)setUp {
    [super setUp];

    self.networkType = WSNetworkTypeMain;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testParse
{
    WSBIP21URL *url;
    WSAddress *address = WSAddressFromString(self.networkParameters, @"1LrVBAV2evGWhN5f9o1V2CmVtKcVstHd42");
    NSString *label = @"Luke-Jr";
    NSString *message = @"Donation for project xyz";
    
    url = WSBIP21URLFromString(self.networkParameters, @"bitcoin:1LrVBAV2evGWhN5f9o1V2CmVtKcVstHd42");
    DDLogInfo(@"%@", url);
    XCTAssertEqualObjects(url.address, address);

    url = WSBIP21URLFromString(self.networkParameters, @"bitcoin:1LrVBAV2evGWhN5f9o1V2CmVtKcVstHd42?label=Luke-Jr");
    DDLogInfo(@"%@", url);
    XCTAssertEqualObjects(url.address, address);
    XCTAssertEqualObjects(url.label, label);

    url = WSBIP21URLFromString(self.networkParameters, @"bitcoin:1LrVBAV2evGWhN5f9o1V2CmVtKcVstHd42?amount=20.3& label=Luke-Jr");
    DDLogInfo(@"%@", url);
//    XCTAssertNil(url);

    url = WSBIP21URLFromString(self.networkParameters, @"bitcoin:1LrVBAV2evGWhN5f9o1V2CmVtKcVstHd42?amount=20.3&label=Luke-Jr");
    DDLogInfo(@"%@", url);
    XCTAssertEqualObjects(url.address, address);
    XCTAssertEqualObjects(url.label, label);
    XCTAssertEqual(url.amount, 2030000000LL);
    
    url = WSBIP21URLFromString(self.networkParameters, @"bitcoin:1LrVBAV2evGWhN5f9o1V2CmVtKcVstHd42?amount=50&label=Luke-Jr&message=Donation%20for%20project%20xyz");
    DDLogInfo(@"%@", url);
    XCTAssertEqualObjects(url.address, address);
    XCTAssertEqual(url.amount, 5000000000LL);
    XCTAssertEqualObjects(url.label, label);
    XCTAssertEqualObjects(url.message, message);

    url = WSBIP21URLFromString(self.networkParameters, @"bitcoin:1LrVBAV2evGWhN5f9o1V2CmVtKcVstHd42?req-somethingyoudontunderstand=50&req-somethingelseyoudontget=999");
    DDLogInfo(@"%@", url);
    XCTAssertEqualObjects(url.address, address);
    XCTAssertEqual(url.amount, 0LL);
    XCTAssertNil(url.label);
    XCTAssertNil(url.message);
    XCTAssertEqualObjects(url.others[@"req-somethingyoudontunderstand"], @"50");
    XCTAssertEqualObjects(url.others[@"req-somethingelseyoudontget"], @"999");
}

- (void)testBuild
{
    WSBIP21URL *url;
    NSString *string;
    
    string = @"bitcoin:1LrVBAV2evGWhN5f9o1V2CmVtKcVstHd42?label=Hello%20Coin!&amount=76.2582";
    url = [[[[[WSBIP21URLBuilder builder] address:WSAddressFromString(self.networkParameters, @"1LrVBAV2evGWhN5f9o1V2CmVtKcVstHd42")] amount:7625820000LL] label:@"Hello Coin!"] build];
    DDLogInfo(@"%@", url.string);
    XCTAssertEqualObjects(url.string, string);

    string = @"bitcoin:";
    url = [[WSBIP21URLBuilder builder] build];
    DDLogInfo(@"%@", url.string);
    XCTAssertEqualObjects(url.string, string);
}

@end
