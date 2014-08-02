//
//  WSBIP37Tests.m
//  WaSPV
//
//  Created by Davide De Rosa on 27/06/14.
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
#import "WSBloomFilter.h"

@interface WSBIP37Tests : XCTestCase

@end

@implementation WSBIP37Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFilterExact
{
    WSBIP37FilterParameters *parameters = [[WSBIP37FilterParameters alloc] init];
    WSMutableBloomFilter *filter = [[WSMutableBloomFilter alloc] initWithParameters:parameters capacity:10];
    
    NSArray *insertStrings = @[@"abcdef", @"0023834f", @"84938c", @"00fbd97c", @"9d7e90"];
    for (NSString *string in insertStrings) {
        [self subInsertFilter:filter hexString:string];
    }

    NSArray *testStrings = @[@"abcdee", @"0023834b", @"84938c", @"0fb0d97c", @"9d7e90"];
    for (NSString *string in testStrings) {
        [self subTestFilter:filter hexString:string];
    }
}

- (void)testFilterApproximate
{
    WSBIP37FilterParameters *parameters = [[WSBIP37FilterParameters alloc] init];
    parameters.falsePositiveRate = 0.0005;
    WSMutableBloomFilter *filter = [[WSMutableBloomFilter alloc] initWithParameters:parameters capacity:100];
    
    NSArray *insertStrings = @[@"abcdef", @"0023834f", @"84938c", @"00fbd97c", @"9d7e90"];
    for (NSString *string in insertStrings) {
        [self subInsertFilter:filter hexString:string];
    }
    
    NSArray *testStrings = @[@"abcdee", @"0023834b", @"84938c", @"0fb0d97c", @"9d7e90"];
    for (NSString *string in testStrings) {
        [self subTestFilter:filter hexString:string];
    }
}

- (void)testFilterFromBreadwallet
{
    WSBIP37FilterParameters *parameters = [[WSBIP37FilterParameters alloc] init];
    parameters.falsePositiveRate = 0.01;
    parameters.tweak = 0x0;
    parameters.flags = WSBIP37FlagsUpdateAll;
    WSMutableBloomFilter *f = [[WSMutableBloomFilter alloc] initWithParameters:parameters capacity:3];

    [f insertData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".dataFromHex];
    
    XCTAssertTrue([f containsData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".dataFromHex],
                  @"[BRBloomFilter containsData:]");
    
    // one bit difference
    XCTAssertFalse([f containsData:@"19108ad8ed9bb6274d3980bab5a85c048f0950c8".dataFromHex],
                   @"[BRBloomFilter containsData:]");
    
    [f insertData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".dataFromHex];
    
    XCTAssertTrue([f containsData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".dataFromHex],
                  @"[BRBloomFilter containsData:]");
    
    [f insertData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".dataFromHex];
    
    XCTAssertTrue([f containsData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".dataFromHex],
                  @"[BRBloomFilter containsData:]");
    
    // check against satoshi client output
    XCTAssertEqualObjects(@"03614e9b050000000000000001".dataFromHex, f.toBuffer.data, @"[BRBloomFilter data:]");
}

- (void)subInsertFilter:(WSMutableBloomFilter *)filter hexString:(NSString *)hexString
{
    NSData *data = [hexString dataFromHex];
    [filter insertData:data];
    DDLogInfo(@"Inserted: %@", hexString);
}

- (void)subTestFilter:(WSMutableBloomFilter *)filter hexString:(NSString *)hexString
{
    NSData *data = [hexString dataFromHex];

    DDLogInfo(@"Hex: %@", hexString);
    DDLogInfo(@"Contains(%@): %d", hexString, [filter containsData:data]);
}

@end
