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
    NSMutableArray *checkpoints = [[NSMutableArray alloc] init];

    [nc addObserverForName:WSPeerGroupDidDownloadBlockNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        WSStorableBlock *block = note.userInfo[WSPeerGroupDownloadBlockKey];
        
        if (block.height % (10 * [WSCurrentParameters retargetInterval]) == 0) {
            DDLogInfo(@"Checkpoint at #%u: %@", block.height, block);
            [checkpoints addObject:block];
        }
    }];
    [nc addObserverForName:WSPeerGroupDidFinishDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [NSKeyedArchiver archiveRootObject:checkpoints toFile:[self filename]];
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
//    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:store fastCatchUpTimestamp:WSTimestampFromISODate(@"2014-12-03")];
    peerGroup.maxConnections = 5;
    peerGroup.headersOnly = YES;
    [peerGroup startBlockChainDownload];
    [peerGroup startConnections];
    
    [self runForever];
}

- (void)privateTestDeserialize
{
    NSArray *checkpoints = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filename]];
    for (WSStorableBlock *block in checkpoints) {
        DDLogInfo(@"%@", block);
    }
}

- (NSString *)filename
{
    return [self mockPathForFile:[NSString stringWithFormat:@"WaSPV-%@.checkpoints", WSParametersGetCurrentTypeString()]];
}

@end
