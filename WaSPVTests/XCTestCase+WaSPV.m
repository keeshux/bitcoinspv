//
//  XCTestCase+WaSPV.m
//  WaSPV
//
//  Created by Davide De Rosa on 07/07/14.
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
#import "WSMessage.h"
#import "WSPeer.h"

// XXX: I know, but CFRunLoopStop is useless and category properties are overkill
static volatile BOOL running;
static id<WSParameters> networkParameters;

@implementation XCTestCase (WaSPV)

- (WSNetworkType)networkType
{
    return [networkParameters networkType];
}

- (void)setNetworkType:(WSNetworkType)networkType
{
    networkParameters = WSParametersForNetworkType(networkType);
}

- (id<WSParameters>)networkParameters
{
    NSAssert(networkParameters, @"Forgot to set networkType?");
    
    return networkParameters;
}

- (NSString *)mockWalletMnemonic
{
    return @"news snake whip verb camera renew siege never eager physical type wet";
}

- (WSSeed *)mockWalletSeed
{
    return WSSeedMakeFromISODate([self mockWalletMnemonic], @"2014-05-01");
}

- (NSString *)mockPathForFile:(NSString *)file
{
    NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *testDirectory = [caches stringByAppendingPathComponent:@"WaSPVTests"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:testDirectory]) {
        [fm createDirectoryAtPath:testDirectory withIntermediateDirectories:NO attributes:nil error:NULL];
    }
    return [testDirectory stringByAppendingPathComponent:file];
}

- (void)runForever
{
    running = YES;
    while (running) {
        [self runForSeconds:1.0];
    }
}

- (void)runForSeconds:(NSTimeInterval)seconds
{
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

- (void)stopRunning
{
    running = NO;
//    CFRunLoopStop(CFRunLoopGetMain());
}

- (void)delayBlock:(void (^)())block seconds:(NSTimeInterval)seconds
{
    dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC);
    dispatch_after(when, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        block();
    });
}

- (id<WSMessage>)assertMessageSequenceForPeer:(WSPeer *)peer expectedClasses:(NSArray *)expectedClasses timeout:(NSTimeInterval)timeout
{
    id<WSMessage> lastMessage = nil;
    
    NSUInteger i = 1;
    for (Class clazz in expectedClasses) {
        DDLogInfo(@"Waiting for message #%u...", i);
        lastMessage = [peer dequeueMessageSynchronouslyWithTimeout:timeout];
//        DDLogInfo(@"Received message #%u: %@", i, lastMessage);
        XCTAssertTrue([lastMessage isKindOfClass:clazz], @"Expecting %@, received: %@", clazz, [lastMessage class]);
        
        ++i;
    }

    return lastMessage;
}

@end
