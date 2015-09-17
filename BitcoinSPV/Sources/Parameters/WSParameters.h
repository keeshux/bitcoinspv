//
//  WSParameters.h
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

#import <Foundation/Foundation.h>

#import "WSNetworkType.h"

@class WSHash256;
@class WSFilteredBlock;
@class WSStorableBlock;

#pragma mark -

@interface WSParameters : NSObject

- (WSNetworkType)networkType;
- (WSFilteredBlock *)genesisBlock;
- (uint32_t)magicNumber;
- (uint8_t)publicKeyAddressVersion;
- (uint8_t)scriptAddressVersion;
- (uint8_t)privateKeyVersion;
- (NSUInteger)peerPort;
- (uint32_t)bip32PublicKeyVersion;
- (uint32_t)bip32PrivateKeyVersion;
- (uint32_t)maxProofOfWork;
- (uint32_t)retargetTimespan;
- (uint32_t)minRetargetTimespan;
- (uint32_t)maxRetargetTimespan;
- (uint32_t)retargetSpacing;
- (uint32_t)retargetInterval;
- (NSArray *)dnsSeeds;
- (NSArray *)checkpoints;

// shortcuts
- (NSString *)networkTypeString;
- (WSHash256 *)genesisBlockId;
- (WSStorableBlock *)checkpointAtHeight:(uint32_t)height;
- (WSStorableBlock *)lastCheckpointBeforeTimestamp:(uint32_t)timestamp;

@end

@interface WSParametersBuilder : NSObject

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
@property (nonatomic, strong) NSArray *dnsSeeds;
@property (nonatomic, strong) NSString *checkpointsHex;

@property (nonatomic, assign) uint32_t genesisVersion;
@property (nonatomic, strong) WSHash256 *genesisMerkleRoot;
@property (nonatomic, assign) uint32_t genesisTimestamp;
@property (nonatomic, assign) uint32_t genesisBits;
@property (nonatomic, assign) uint32_t genesisNonce;

- (instancetype)initWithNetworkType:(WSNetworkType)networkType;
- (WSParameters *)build;

@end
