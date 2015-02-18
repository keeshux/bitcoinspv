//
//  WSPeerGroupTests.m
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
#import "WSPeerGroup.h"
#import "WSPeer.h"
#import "WSConnectionPool.h"
#import "WSMemoryBlockStore.h"

@interface WSPeerGroup ()

- (WSConnectionPool *)pool;
- (dispatch_queue_t)queue;
- (NSArray *)connectedPeers;
- (WSPeer *)downloadPeer;
- (WSPeer *)bestPeer;

@end

@interface WSPeerGroupTests : XCTestCase

@property (nonatomic, strong) id<WSBlockStore> blockStore;
@property (nonatomic, strong) WSConnectionPool *pool;

@end

@implementation WSPeerGroupTests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeTestnet3;
    
    self.blockStore = [[WSMemoryBlockStore alloc] initWithParameters:WSParametersForNetworkType(WSNetworkTypeTestnet3)];
    self.pool = [[WSConnectionPool alloc] init];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testConnection
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.blockStore pool:self.pool];
    peerGroup.maxConnections = 3;
    [peerGroup startConnections];
    [self runForSeconds:3.0];
    [peerGroup stopConnections];
    [self runForSeconds:3.0];
}

- (void)testMaxConnections
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.blockStore pool:self.pool];
    peerGroup.maxConnections = 5;
    [peerGroup startConnections];
    [self runForSeconds:5.0];
    peerGroup.maxConnections = 1;
    [self runForSeconds:3.0];
    peerGroup.maxConnections = 3;
    [self runForSeconds:3.0];
}

- (void)testDisconnectionWithError
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.blockStore pool:self.pool];
    peerGroup.maxConnections = 5;
    [peerGroup startConnections];
    [self runForSeconds:3.0];
    [peerGroup.pool closeConnections:2 error:WSErrorMake(WSErrorCodeInsufficientFunds, @"TEST: this is a mock error")];
    [self runForSeconds:3.0];
    [peerGroup stopConnections];
    [self runForSeconds:2.0];
}

- (void)testPersistentConnection
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.blockStore pool:self.pool];
    peerGroup.maxConnections = 3;
    peerGroup.maxConnectionFailures = 20;
    [peerGroup startConnections];
    [self runForever];
}

- (void)testDownloadPeerSelection
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.blockStore pool:self.pool];
    peerGroup.maxConnections = 10;
    [peerGroup startConnections];
    [self runForSeconds:3.0];

    dispatch_sync(peerGroup.queue, ^{
        DDLogInfo(@"Connected peers");
        for (WSPeer *peer in [peerGroup.connectedPeers copy]) {
            DDLogInfo(@"\t%@ (height = %u, ping = %.3fs)", peer, peer.lastBlockHeight, peer.connectionTime);
        }
        WSPeer *downloadPeer = peerGroup.downloadPeer;
        DDLogInfo(@"Download peer: %@", downloadPeer);
        XCTAssertEqualObjects(downloadPeer, [peerGroup bestPeer], @"Download peer is not best peer");
    });
}

- (void)testFlood
{
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:self.blockStore pool:self.pool];

    for (int i = 0; i < 100; ++i) {
        const int which = mrand48() % 4;

        switch (which) {
            case 0: {
                [peerGroup startConnections];
                break;
            }
            case 1: {
                [peerGroup stopConnections];
                break;
            }
            case 2: {
                [peerGroup startBlockChainDownload];
                break;
            }
            case 3: {
                [peerGroup stopBlockChainDownload];
                break;
            }
        }
        
        [self runForSeconds:0.5];
    }
    
    [self runForSeconds:10.0];
}

@end
