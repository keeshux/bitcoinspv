//
//  WSParametersFactoryMain.m
//  WaSPV
//
//  Created by Davide De Rosa on 02/07/14.
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

#import "WSParametersFactoryMain.h"
#import "WSHash256.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSPartialMerkleTree.h"
#import "WSBitcoin.h"
#import "WSMacros.h"

@interface WSParametersFactoryMain ()

@property (nonatomic, strong) WSMutableParameters *parameters;

@end

@implementation WSParametersFactoryMain

- (instancetype)init
{
    if ((self = [super init])) {
        WSMutableParameters *parameters = [[WSMutableParameters alloc] init];

        parameters.magicNumber                  = 0xd9b4bef9;
        parameters.publicKeyAddressVersion      = 0x00;
        parameters.scriptAddressVersion         = 0x05;
        parameters.privateKeyVersion            = 0x80;
        parameters.peerPort                     = 8333;
        parameters.bip32PublicKeyVersion        = 0x0488b21e; // "xpub"
        parameters.bip32PrivateKeyVersion       = 0x0488ade4; // "xprv"
        parameters.maxProofOfWork               = 0x1d00ffff;
        parameters.retargetTimespan             = 2 * WSDatesOneWeek;   // the targeted timespan between difficulty target adjustments
        parameters.minRetargetTimespan          = parameters.retargetTimespan / 4;
        parameters.maxRetargetTimespan          = parameters.retargetTimespan * 4;
        parameters.retargetSpacing              = 10 * WSDatesOneMinute;
        parameters.retargetInterval             = parameters.retargetTimespan / parameters.retargetSpacing; // 2016
        
        WSBlockHeader *genesisHeader = [[WSBlockHeader alloc] initWithVersion:1
                                                              previousBlockId:WSHash256Zero()
                                                                   merkleRoot:WSHash256FromHex(@"4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b")
                                                                    timestamp:1231006505
                                                                         bits:0x1d00ffff
                                                                        nonce:2083236893];

        NSAssert([genesisHeader.blockId isEqual:WSHash256FromHex(@"000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f")], @"Bad genesis block id (main)");
        
        WSPartialMerkleTree *genesisPMT = [[WSPartialMerkleTree alloc] initWithTxCount:1
                                                                                hashes:@[genesisHeader.merkleRoot]
                                                                                 flags:[NSData dataWithBytes:"\x01" length:1]
                                                                                 error:NULL];

        parameters.genesisBlock = [[WSFilteredBlock alloc] initWithHeader:genesisHeader partialMerkleTree:genesisPMT];
        
        [parameters loadCheckpointsWithNetworkName:WSParametersTypeString(self.parametersType)];

        [parameters addDnsSeed:@"seed.bitcoin.sipa.be"];
        [parameters addDnsSeed:@"dnsseed.bluematt.me"];
        [parameters addDnsSeed:@"dnsseed.bitcoin.dashjr.org"];
//        [parameters addDnsSeed:@"bitseed.xf2.org"]; // seems faulting
        
        self.parameters = parameters;
    }
    return self;
}

- (WSParametersType)parametersType
{
    return WSParametersTypeMain;
}

@end
