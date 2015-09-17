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

- (instancetype)initWithNetworkType:(WSNetworkType)networkType;
- (WSNetworkType)networkType;
- (NSString *)networkTypeString;

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
- (WSFilteredBlock *)genesisBlock;
- (WSHash256 *)genesisBlockId;

- (NSArray *)checkpoints;
- (WSStorableBlock *)checkpointAtHeight:(uint32_t)height;
- (WSStorableBlock *)lastCheckpointBeforeTimestamp:(uint32_t)timestamp;
- (NSArray *)dnsSeeds;

@end

@interface WSMutableParameters : WSParameters

- (void)setMagicNumber:(uint32_t)magicNumber;
- (void)setPublicKeyAddressVersion:(uint8_t)publicKeyAddressVersion;
- (void)setScriptAddressVersion:(uint8_t)scriptAddressVersion;
- (void)setPrivateKeyVersion:(uint8_t)privateKeyVersion;
- (void)setPeerPort:(NSUInteger)peerPort;
- (void)setBip32PublicKeyVersion:(uint32_t)bip32PublicKeyVersion;
- (void)setBip32PrivateKeyVersion:(uint32_t)bip32PrivateKeyVersion;
- (void)setMaxProofOfWork:(uint32_t)maxProofOfWork;
- (void)setRetargetTimespan:(uint32_t)retargetTimespan;
- (void)setMinRetargetTimespan:(uint32_t)minRetargetTimespan;
- (void)setMaxRetargetTimespan:(uint32_t)maxRetargetTimespan;
- (void)setRetargetSpacing:(uint32_t)retargetSpacing;
- (void)setRetargetInterval:(uint32_t)retargetInterval;
- (void)setGenesisBlock:(WSFilteredBlock *)genesisBlock;

- (void)loadCheckpointsFromHex:(NSString *)hex;
- (void)addDnsSeed:(NSString *)dnsSeed;

@end
