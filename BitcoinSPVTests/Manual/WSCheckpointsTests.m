//
//  WSCheckpointsTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 05/12/14.
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

#import "XCTestCase+BitcoinSPV.h"

@interface WSCheckpointsTests : XCTestCase

@end

@implementation WSCheckpointsTests

- (void)setUp
{
    [super setUp];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    WSMutableBuffer *checkpoints = [[WSMutableBuffer alloc] initWithCapacity:(128 * 1024)];

    [nc addObserverForName:WSPeerGroupDidDownloadBlockNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        WSStorableBlock *block = note.userInfo[WSPeerGroupDownloadBlockKey];
        
        if (block.height % (10 * [self.networkParameters retargetInterval]) == 0) {
            DDLogInfo(@"Checkpoint at #%u: %@", block.height, block);
            [block appendToMutableBuffer:checkpoints];
        }
    }];
    [nc addObserverForName:WSPeerGroupDidFinishDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self privateTestFinishSerializeCheckpoints:checkpoints];
    }];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSerializeMain
{
    self.networkType = WSNetworkTypeMain;

    [self privateTestSerialize];
}

- (void)testDeserializeMain
{
    self.networkType = WSNetworkTypeMain;

    [self privateTestDeserialize];
}

- (void)testSerializeTestnet3
{
    self.networkType = WSNetworkTypeTestnet3;
    
    [self privateTestSerialize];
}

- (void)testDeserializeTestnet3
{
    self.networkType = WSNetworkTypeTestnet3;
    
    [self privateTestDeserialize];
}

#pragma mark Private

- (void)privateTestSerialize
{
    WSMemoryBlockStore *store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store headersOnly:YES];
//    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store fastCatchUpTimestamp:1386098130];
//    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store fastCatchUpTimestamp:WSTimestampFromISODate(@"2014-08-03")];

    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters];
    peerGroup.maxConnections = 5;
    [peerGroup startDownloadWithDownloader:downloader];
    [peerGroup startConnections];
    
    [self runForever];
}

- (void)privateTestFinishSerializeCheckpoints:(WSBuffer *)checkpoints
{
    [checkpoints.data writeToFile:[self filename] atomically:YES];

    DDLogInfo(@"Embeddable hex: %@", [checkpoints hexString]);
}

- (void)privateTestDeserialize
{
    NSData *checkpointsData = [NSData dataWithContentsOfFile:[self filename]];
    WSBuffer *checkpoints = [[WSBuffer alloc] initWithData:checkpointsData];

    DDLogInfo(@"Embeddable hex: %@", [checkpoints hexString]);
    DDLogInfo(@"Size: %u", checkpoints.length);

    NSUInteger offset = 0;
    while (offset < checkpoints.length) {
        WSStorableBlock *block = [[WSStorableBlock alloc] initWithParameters:self.networkParameters buffer:checkpoints from:offset available:(checkpoints.length - offset) error:NULL];
        DDLogInfo(@"%@", block);
        offset += [block estimatedSize];
    }
    XCTAssertEqual(offset, checkpoints.length);
}

- (NSString *)filename
{
    NSString *filename = [self mockPathForFile:[NSString stringWithFormat:@"BitcoinSPV-%@.checkpoints", WSNetworkTypeString([self.networkParameters networkType])]];
    DDLogInfo(@"File: %@", filename);
    return filename;
}

@end
