//
//  WSConnectionPoolTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 07/07/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//
//  http://github.com/keeshux
//  http://twitter.com/keeshux
//  http://davidederosa.com
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

#import "GCDAsyncSocket.h"

#import "XCTestCase+BitcoinSPV.h"
#import "WSConnectionPool.h"
#import "WSPeerGroup.h"

// testnet-seed.bitcoin.petertodd.org

@interface WSConnectionPoolTests : XCTestCase <GCDAsyncSocketDelegate>

@property (nonatomic, strong) NSArray *hosts;

@end

@implementation WSConnectionPoolTests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeTestnet3;

    self.hosts = @[@"107.170.104.227",
                   @"95.78.127.77",
                   @"184.107.180.2",
                   @"144.76.46.66"];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testRawFtp
{
    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    [socket connectToHost:@"ftp.de.freebsd.org" onPort:21 error:NULL];
    [socket readDataWithTimeout:5 tag:0];
    [self runForSeconds:2.0];
}

- (void)testRaw
{
    NSString *host = self.hosts[0];
    
    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    [socket connectToHost:host onPort:[self.networkParameters peerPort] error:NULL];
    [self runForSeconds:2.0];
}

- (void)testPool
{
    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:self.networkParameters];
    for (NSString *h in self.hosts) {
        [pool openConnectionToHost:h port:[self.networkParameters peerPort] processor:nil];
    }
    [self runForSeconds:2.0];
    [pool closeAllConnections];
}

- (void)testSinglePeerPool
{
    NSString *anyHost = self.hosts[mrand48() % self.hosts.count];
    
    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:self.networkParameters];
    [pool openConnectionToPeerHost:anyHost parameters:self.networkParameters flags:[self peerFlags]];
    [self runForSeconds:2.0];
    [pool closeAllConnections];
    [self runForSeconds:2.0];
}

- (void)testMultiplePeerPool
{
    WSConnectionPool *pool = [[WSConnectionPool alloc] initWithParameters:self.networkParameters];
    for (NSString *h in self.hosts) {
        [pool openConnectionToPeerHost:h parameters:self.networkParameters flags:[self peerFlags]];
    }
    [self runForSeconds:2.0];
    [pool closeAllConnections];
    [self runForSeconds:2.0];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    DDLogInfo(@"socket:%@ didConnectToHost:%@ port:%u", sock, host, port);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    DDLogInfo(@"socket:%@ didReadData:%@", sock, data);
}

- (WSPeerFlags *)peerFlags
{
    return [[WSPeerFlags alloc] initWithNeedsBloomFiltering:NO];
}

@end
