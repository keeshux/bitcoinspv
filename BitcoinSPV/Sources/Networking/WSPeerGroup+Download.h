//
//  WSPeerGroup+Download.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/09/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
//

#import "WSPeerGroup.h"

@class WSConnectionPool;
@class WSPeer;

@interface WSPeerGroup (Download)

- (NSArray *)allConnectedPeers;
- (void)disconnectPeer:(WSPeer *)peer error:(NSError *)error;
- (void)reportMisbehavingPeer:(WSPeer *)peer error:(NSError *)error;
- (void)executeBlockInGroupQueue:(void (^)())block synchronously:(BOOL)synchronously;

@end
