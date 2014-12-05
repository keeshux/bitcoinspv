//
//  WSCheckpointsTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 05/12/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XCTestCase+WaSPV.h"

#import "WaSPV.h"

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
        
        if (block.height % (10 * [WSCurrentParameters retargetInterval]) == 0) {
            DDLogInfo(@"Checkpoint at #%u: %@", block.height, block);
            [block appendToMutableBuffer:checkpoints];
        }
    }];
    [nc addObserverForName:WSPeerGroupDidFinishDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [checkpoints.data writeToFile:[self filename] atomically:YES];
    }];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSerializeMain
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    [self privateTestSerialize];
}

- (void)testDeserializeMain
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    [self privateTestDeserialize];
}

- (void)testSerializeTestnet3
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    [self privateTestSerialize];
}

- (void)testDeserializeTestnet3
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    [self privateTestDeserialize];
}

#pragma mark Private

- (void)privateTestSerialize
{
    WSMemoryBlockStore *store = [[WSMemoryBlockStore alloc] initWithGenesisBlock];
    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:store];
//    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:store fastCatchUpTimestamp:1386098130];
//    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:store fastCatchUpTimestamp:WSTimestampFromISODate(@"2014-08-03")];
    peerGroup.maxConnections = 5;
    peerGroup.headersOnly = YES;
    [peerGroup startBlockChainDownload];
    [peerGroup startConnections];
    
    [self runForever];
}

- (void)privateTestDeserialize
{
    NSData *checkpointsData = [NSData dataWithContentsOfFile:[self filename]];
    WSBuffer *checkpoints = [[WSBuffer alloc] initWithData:checkpointsData];

    DDLogInfo(@"Embeddable hex: %@", [checkpoints hexString]);
    DDLogInfo(@"Size: %u", checkpoints.length);

    NSUInteger offset = 0;
    while (offset < checkpoints.length) {
        WSStorableBlock *block = [[WSStorableBlock alloc] initWithBuffer:checkpoints from:offset available:(checkpoints.length - offset) error:NULL];
        DDLogInfo(@"%@", block);
        offset += [block estimatedSize];
    }
    XCTAssertEqual(offset, checkpoints.length);
}

- (NSString *)filename
{
    NSString *filename = [self mockPathForFile:[NSString stringWithFormat:@"WaSPV-%@.checkpoints", WSParametersGetCurrentTypeString()]];
    DDLogInfo(@"File: %@", filename);
    return filename;
}

@end
