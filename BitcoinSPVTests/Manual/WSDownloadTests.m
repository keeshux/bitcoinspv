//
//  WSDownloadTests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/09/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
//

#import "XCTestCase+BitcoinSPV.h"

@interface WSDownloadTests : XCTestCase

@property (nonatomic, strong) WSConnectionPool *pool;
@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation WSDownloadTests

- (void)setUp
{
    [super setUp];
    
    self.networkType = WSNetworkTypeTestnet3;
    
    self.pool = [[WSConnectionPool alloc] initWithParameters:self.networkParameters];
    self.queue = dispatch_queue_create("Test", DISPATCH_QUEUE_SERIAL);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testChoice
{
    NSString *testPath = [self mockPathForFile:@"DownloadTests-Test3.sqlite"];
    WSCoreDataManager *manager = [[WSCoreDataManager alloc] initWithPath:testPath error:NULL];

    WSMemoryBlockStore *store = [[WSMemoryBlockStore alloc] initWithParameters:self.networkParameters];
//    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store fastCatchUpTimestamp:WSTimestampFromISODate(@"2012-04-18")];
    WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store headersOnly:YES];
    downloader.coreDataManager = manager;

    WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:self.networkParameters pool:self.pool queue:self.queue];
    peerGroup.maxConnections = 3;
    peerGroup.maxConnectionFailures = 20;
    [peerGroup startConnections];
    [peerGroup startDownloadWithDownloader:downloader];
    [self runForSeconds:5.0];
    [peerGroup stopDownload];
//    [peerGroup stopConnectionsWithCompletionBlock:NULL];
    [self runForever];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
