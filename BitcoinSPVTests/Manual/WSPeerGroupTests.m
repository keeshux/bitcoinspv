//
//  WSPeerGroupTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 27/06/14.
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

@interface WSPeerGroup ()

- (dispatch_queue_t)queue;
- (NSDictionary *)connectedPeers;

@end

@interface WSPeerGroupTests : XCTestCase

@end

@implementation WSPeerGroupTests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeTestnet3;
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testConnection
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 3;
    [peerGroup startConnections];
    [self runForSeconds:3.0];
    [peerGroup stopConnections];
    [self runForSeconds:3.0];
}

- (void)testMaxConnections
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 5;
    [peerGroup startConnections];
    [self runForSeconds:5.0];
    peerGroup.maxConnections = 1;
    [self runForSeconds:3.0];
    peerGroup.maxConnections = 3;
    [self runForSeconds:3.0];
}

//- (void)testDisconnectionWithError
//{
//    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
//    peerGroup.maxConnections = 5;
//    [peerGroup startConnections];
//    [self runForSeconds:3.0];
//    [peerGroup.pool closeConnections:2 error:WSErrorMake(WSErrorCodeInsufficientFunds, @"TEST: this is a mock error")];
//    [self runForSeconds:3.0];
//    [peerGroup stopConnections];
//    [self runForSeconds:2.0];
//}

- (void)testPersistentConnection
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 8;
    peerGroup.maxConnectionFailures = 20;
    [peerGroup startConnections];
    [self runForever];
}

- (void)testConnectedPeers
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 10;
    [peerGroup startConnections];
    [self runForSeconds:3.0];

    dispatch_sync(peerGroup.queue, ^{
        DDLogInfo(@"Connected peers");
        for (WSPeer *peer in [[peerGroup.connectedPeers allValues] copy]) {
            DDLogInfo(@"\t%@ (height = %u, ping = %.3fs)", peer, peer.lastBlockHeight, peer.connectionTime);
        }
    });
}

//- (void)testFlood
//{
//    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithPool:self.pool queue:self.queue blockStore:self.blockStore];
//
//    for (int i = 0; i < 100; ++i) {
//        const int which = mrand48() % 4;
//
//        switch (which) {
//            case 0: {
//                [peerGroup startConnections];
//                break;
//            }
//            case 1: {
//                [peerGroup stopConnections];
//                break;
//            }
//            case 2: {
//                [peerGroup startBlockChainDownload];
//                break;
//            }
//            case 3: {
//                [peerGroup stopBlockChainDownload];
//                break;
//            }
//        }
//        
//        [self runForSeconds:0.5];
//    }
//    
//    [self runForSeconds:10.0];
//}

@end
