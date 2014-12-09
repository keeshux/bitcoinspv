//
//  WSWebUtilsTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 07/12/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//
//  Created by Davide De Rosa on 20/07/14.
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

@interface WSWebUtilsTests : XCTestCase

@end

@implementation WSWebUtilsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSweep
{
    WSKey *key = WSKeyFromWIF(@"cU5m4wLDcMPHVWqYRdRYzJDDZc6VKPFhLy5Fwcvb439e8N3EQipo"); // muqqZmhjF7u2nNmYTi7KoDpQh8TLvqBSTd
//    WSAddress *address = WSAddressFromString(@"muyDoehpBExCbRRXLtDUpw5DaTb33UZeyG");
    WSAddress *address = WSAddressFromString(@"2N66DDrmjDCMM3yMSYtAQyAqRtasSkFhbmX");
    
    [[WSWebUtils sharedInstance] buildSweepTransactionsFromKey:key toAddress:address fee:0 maxTxSize:1000 callback:^(WSSignedTransaction *transaction) {
        DDLogInfo(@"Transaction: %@", transaction);
    } completion:^(NSUInteger numberOfTransactions) {
        DDLogInfo(@"Total transactions: %u", numberOfTransactions);
    } failure:^(NSError *error) {
        DDLogError(@"Error building transactions: %@", error);
    }];
    
    [self runForSeconds:5.0];
}

- (void)testSweepBIP38
{
    WSBIP38Key *bip38Key = WSBIP38KeyFromString(@"6PYLdaRqCvj77isRyypqsX2kZyPvM6ESG2LXbm7bXwNYfDbd1Q5KuYqvtZ"); // cU5m4wLDcMPHVWqYRdRYzJDDZc6VKPFhLy5Fwcvb439e8N3EQipo
    WSAddress *address = WSAddressFromString(@"2N66DDrmjDCMM3yMSYtAQyAqRtasSkFhbmX");
    NSString *passphrase = @"foobar";
    
    [[WSWebUtils sharedInstance] buildSweepTransactionsFromBIP38Key:bip38Key passphrase:passphrase toAddress:address fee:0 maxTxSize:1000 callback:^(WSSignedTransaction *transaction) {
        DDLogInfo(@"Transaction: %@", transaction);
    } completion:^(NSUInteger numberOfTransactions) {
        DDLogInfo(@"Total transactions: %u", numberOfTransactions);
    } failure:^(NSError *error) {
        DDLogError(@"Error building transactions: %@", error);
    }];
    
    [self runForSeconds:5.0];
}

@end
