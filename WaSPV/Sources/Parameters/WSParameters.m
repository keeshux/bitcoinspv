//
//  WSParameters.m
//  WaSPV
//
//  Created by Davide De Rosa on 13/06/14.
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

@property (nonatomic, strong) NSMutableArray *dnsSeeds;
@property (nonatomic, strong) NSArray *checkpoints;

@end

@implementation WSMutableParameters

- (instancetype)init
{
    if ((self = [super init])) {
        self.dnsSeeds = [[NSMutableArray alloc] init];
        self.checkpoints = nil;
    }
    return self;
}

- (WSHash256 *)genesisBlockId
{
    return self.genesisBlock.header.blockId;
}

- (void)loadCheckpointsWithNetworkName:(NSString *)networkName
{
    WSExceptionCheckIllegal(networkName != nil, @"Nil networkName");
    
    NSBundle *bundle = WSClientBundle([self class]);
    NSString *filename = [NSString stringWithFormat:WSParametersCheckpointsNameFormat, networkName];
    NSString *path = [bundle pathForResource:filename ofType:WSParametersCheckpointsFileType];

    self.checkpoints = [NSKeyedUnarchiver unarchiveObjectWithFile:path];

    [self.checkpoints enumerateObjectsUsingBlock:^(WSStorableBlock *cp, NSUInteger idx, BOOL *stop) {
        if (idx > 0) {
            WSStorableBlock *previousCp = self.checkpoints[idx - 1];
            NSAssert(cp.height > previousCp.height, @"Checkpoint is older than last checkpoint");
        }
    }];
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
        lastCheckpoint = [[WSStorableBlock alloc] initWithHeader:genesisBlock.header transactions:nil];
    }
    
    return lastCheckpoint;
}

- (void)addDnsSeed:(NSString *)dnsSeed
{
    [self.dnsSeeds addObject:dnsSeed];
}

@end
