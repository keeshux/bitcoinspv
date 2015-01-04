//
//  WSParameters.h
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

#import <Foundation/Foundation.h>

#import "WSNetworkType.h"

@class WSHash256;
@class WSFilteredBlock;
@class WSStorableBlock;

#pragma mark -

@protocol WSParameters <NSObject>

- (WSNetworkType)networkType;
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
- (NSArray *)dnsSeeds;
- (NSArray *)checkpoints;
- (WSStorableBlock *)checkpointAtHeight:(uint32_t)height;
- (WSStorableBlock *)lastCheckpointBeforeTimestamp:(uint32_t)timestamp;

@end

#pragma mark -

@interface WSMutableParameters : NSObject <WSParameters>

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
@property (nonatomic, strong) WSFilteredBlock *genesisBlock;

- (instancetype)initWithNetworkType:(WSNetworkType)networkType;
- (void)loadCheckpointsFromHex:(NSString *)hex;
- (void)addDnsSeed:(NSString *)dnsSeed;

@end
