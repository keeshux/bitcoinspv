//
//  WSParameters.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 13/06/14.
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

#import <openssl/bn.h>

#import "WSParameters.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSStorableBlock.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSBlockMacros.h"
#import "WSErrors.h"

@interface WSMutableParameters ()

@property (nonatomic, assign) WSNetworkType networkType;
@property (nonatomic, strong) NSMutableArray *dnsSeeds;
@property (nonatomic, strong) NSArray *checkpoints;
@property (nonatomic, strong) NSDictionary *checkpointsByHeight;

@end

@implementation WSMutableParameters

- (instancetype)initWithNetworkType:(WSNetworkType)networkType
{
    if ((self = [super init])) {
        self.networkType = networkType;
        self.dnsSeeds = [[NSMutableArray alloc] init];
        self.checkpoints = nil;
    }
    return self;
}

- (WSHash256 *)genesisBlockId
{
    return self.genesisBlock.header.blockId;
}

- (void)loadCheckpointsFromHex:(NSString *)hex
{
    WSExceptionCheckIllegal(hex != nil, @"Nil hex");
    
    WSBuffer *buffer = WSBufferFromHex(hex);

    NSMutableArray *checkpoints = [[NSMutableArray alloc] initWithCapacity:100];
    NSMutableDictionary *checkpointsByHeight = [[NSMutableDictionary alloc] initWithCapacity:100];

    NSUInteger offset = 0;
    while (offset < buffer.length) {
        WSStorableBlock *block = [[WSStorableBlock alloc] initWithParameters:self
                                                                      buffer:buffer
                                                                        from:offset
                                                                   available:(buffer.length - offset)
                                                                       error:NULL];
        [checkpoints addObject:block];
        checkpointsByHeight[@(block.height)] = block;

        offset += [block estimatedSize];
    }
    NSAssert(offset == buffer.length, @"Malformed checkpoints file (consumed bytes: %u != %u)", offset, buffer.length);

    [checkpoints enumerateObjectsUsingBlock:^(WSStorableBlock *cp, NSUInteger idx, BOOL *stop) {
        if (idx > 0) {
            WSStorableBlock *previousCp = checkpoints[idx - 1];
            NSAssert(cp.height > previousCp.height, @"Checkpoint is older than last checkpoint");
        }
    }];

    self.checkpoints = checkpoints;
    self.checkpointsByHeight = checkpointsByHeight;
}

- (WSStorableBlock *)checkpointAtHeight:(uint32_t)height
{
    return self.checkpointsByHeight[@(height)];
}

- (WSStorableBlock *)lastCheckpointBeforeTimestamp:(uint32_t)timestamp
{
    if (self.checkpoints.count == 0) {
        return nil;
    }
    
    // NOTE: assumes checkpoints are sorted by timestamp
    WSStorableBlock *lastCheckpoint = nil;
    for (WSStorableBlock *cp in [self.checkpoints reverseObjectEnumerator]) {
        if (cp.header.timestamp <= timestamp) {
            lastCheckpoint = cp;
            break;
        }
    }
    if (!lastCheckpoint) {
        WSFilteredBlock *genesisBlock = self.genesisBlock;
        lastCheckpoint = [[WSStorableBlock alloc] initWithHeader:genesisBlock.header transactions:nil height:0];
    }
    
    return lastCheckpoint;
}

- (void)addDnsSeed:(NSString *)dnsSeed
{
    [self.dnsSeeds addObject:dnsSeed];
}

@end
