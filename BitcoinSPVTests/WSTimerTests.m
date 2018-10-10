//
//  WSTimerTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 25/07/14.
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
#import "WSGCDTimer.h"

@interface WSTimerTests : XCTestCase

@end

@implementation WSTimerTests

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

- (void)testMain
{
    WSGCDTimer *timer = [[WSGCDTimer alloc] initWithQueue:dispatch_get_main_queue() interval:0.5];
    const NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    
    DDLogInfo(@"Starting at %.1f", [NSDate timeIntervalSinceReferenceDate] - startTime);
    [timer startWithBlock:^{
        DDLogInfo(@"Triggered at %.1f", [NSDate timeIntervalSinceReferenceDate] - startTime);
    }];

    [self runForSeconds:3.0];

    DDLogInfo(@"Canceling at %.1f", [NSDate timeIntervalSinceReferenceDate] - startTime);
    [timer cancel];
    
    [self runForSeconds:3.0];
}

@end
