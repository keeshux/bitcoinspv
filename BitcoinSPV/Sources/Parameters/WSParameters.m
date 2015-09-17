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
#import "WSPartialMerkleTree.h"
#import "WSStorableBlock.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSParameters ()

@property (nonatomic, assign) WSNetworkType networkType;
@property (nonatomic, strong) WSFilteredBlock *genesisBlock;
@property (nonatomic, assign) uint32_t magicNumber;
@property (nonatomic, assign) uint8_t publicKeyAddressVersion;
@property (nonatomic, assign) uint8_t scriptAddressVersion;
@property (nonatomic, assign) uint8_t privateKeyVersion;
@property (nonatomic, assign) NSUInteger peerPort;
@property (nonatomic, assign) uint32_t bip32PublicKeyVersion;
@property (nonatomic, assign) uint32_t bip32PrivateKeyVersion;
@property (nonatomic, assign) uint32_t maxProofOfWork;
@property (nonatomic, assign) uint32_t retargetTimespan;
@property (nonatomic, assign) uint32_t retargetSpacing;
@property (nonatomic, assign) uint32_t minRetargetTimespan;
@property (nonatomic, assign) uint32_t maxRetargetTimespan;
@property (nonatomic, assign) uint32_t retargetInterval;
@property (nonatomic, strong) NSArray *checkpoints;
@property (nonatomic, strong) NSDictionary *checkpointsByHeight;
@property (nonatomic, strong) NSArray *dnsSeeds;

@property (nonatomic, assign) uint32_t genesisVersion;
@property (nonatomic, strong) WSHash256 *genesisPreviousBlockId;
@property (nonatomic, strong) WSHash256 *genesisMerkleRoot;
@property (nonatomic, assign) uint32_t genesisTimestamp;
@property (nonatomic, assign) uint32_t genesisBits;
@property (nonatomic, assign) uint32_t genesisNonce;

- (void)loadCheckpointsFromHex:(NSString *)hex;

@end

@implementation WSParameters

- (NSString *)networkTypeString
{
    return WSNetworkTypeString(self.networkType);
}

- (WSHash256 *)genesisBlockId
{
    return self.genesisBlock.header.blockId;
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

- (void)loadCheckpointsFromHex:(NSString *)hex
{
    WSExceptionCheckIllegal(hex);
    
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
    NSAssert(offset == buffer.length, @"Malformed checkpoints file (consumed bytes: %lu != %lu)",
             (unsigned long)offset, (unsigned long)buffer.length);
    
    [checkpoints enumerateObjectsUsingBlock:^(WSStorableBlock *cp, NSUInteger idx, BOOL *stop) {
        if (idx > 0) {
            __unused WSStorableBlock *previousCp = checkpoints[idx - 1];
            NSAssert(cp.height > previousCp.height, @"Checkpoint is older than last checkpoint");
        }
    }];
    
    self.checkpoints = checkpoints;
    self.checkpointsByHeight = checkpointsByHeight;
}

@end

#pragma mark -

@interface WSParametersBuilder ()

@property (nonatomic, assign) WSNetworkType networkType;

@end

@implementation WSParametersBuilder

- (instancetype)initWithNetworkType:(WSNetworkType)networkType
{
    if ((self = [super init])) {
        self.networkType = networkType;
    }
    return self;
}

- (WSParameters *)build
{
    WSParameters *parameters = [[WSParameters alloc] init];
    parameters.networkType = self.networkType;
    parameters.magicNumber = self.magicNumber;
    parameters.publicKeyAddressVersion = self.publicKeyAddressVersion;
    parameters.scriptAddressVersion = self.scriptAddressVersion;
    parameters.privateKeyVersion = self.privateKeyVersion;
    parameters.peerPort = self.peerPort;
    parameters.bip32PublicKeyVersion = self.bip32PublicKeyVersion;
    parameters.bip32PrivateKeyVersion = self.bip32PrivateKeyVersion;
    parameters.maxProofOfWork = self.maxProofOfWork;
    parameters.retargetTimespan = self.retargetTimespan;
    parameters.retargetSpacing = self.retargetSpacing;
    parameters.minRetargetTimespan = self.minRetargetTimespan;
    parameters.maxRetargetTimespan = self.maxRetargetTimespan;
    parameters.retargetInterval = self.retargetInterval;
    parameters.dnsSeeds = self.dnsSeeds;
    if (self.checkpointsHex) {
        [parameters loadCheckpointsFromHex:self.checkpointsHex];
    }

    WSBlockHeader *genesisHeader = [[WSBlockHeader alloc] initWithParameters:parameters
                                                                     version:self.genesisVersion
                                                             previousBlockId:WSHash256Zero()
                                                                  merkleRoot:self.genesisMerkleRoot
                                                                   timestamp:self.genesisTimestamp
                                                                        bits:self.genesisBits
                                                                       nonce:self.genesisNonce];
    
    WSPartialMerkleTree *genesisPMT = [[WSPartialMerkleTree alloc] initWithTxCount:1
                                                                            hashes:@[genesisHeader.merkleRoot]
                                                                             flags:[NSData dataWithBytes:"\x01" length:1]
                                                                             error:NULL];

    parameters.genesisBlock = [[WSFilteredBlock alloc] initWithHeader:genesisHeader partialMerkleTree:genesisPMT];

    return parameters;
}

@end
