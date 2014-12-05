//
//  WSParametersFactoryTestnet3.m
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

#import "WSParametersFactoryTestnet3.h"
#import "WSHash256.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSPartialMerkleTree.h"
#import "WSBitcoin.h"
#import "WSMacros.h"

@interface WSParametersFactoryTestnet3 ()

@property (nonatomic, strong) WSMutableParameters *parameters;

@end

@implementation WSParametersFactoryTestnet3

- (instancetype)init
{
    if ((self = [super init])) {
        WSMutableParameters *parameters = [[WSMutableParameters alloc] init];

        parameters.magicNumber                  = 0x0709110b;
        parameters.publicKeyAddressVersion      = 0x6f;
        parameters.scriptAddressVersion         = 0xc4;
        parameters.privateKeyVersion            = 0xef;
        parameters.peerPort                     = 18333;
        parameters.bip32PublicKeyVersion        = 0x043587cf; // "tpub"
        parameters.bip32PrivateKeyVersion       = 0x04358394; // "tprv"
        parameters.maxProofOfWork               = 0x1d00ffff;
        parameters.retargetTimespan             = 2 * WSDatesOneWeek;
        parameters.minRetargetTimespan          = parameters.retargetTimespan / 4;
        parameters.maxRetargetTimespan          = parameters.retargetTimespan * 4;
        parameters.retargetSpacing              = 10 * WSDatesOneMinute;
        parameters.retargetInterval             = parameters.retargetTimespan / parameters.retargetSpacing; // 2016

        WSBlockHeader *genesisHeader = [[WSBlockHeader alloc] initWithVersion:1
                                                              previousBlockId:WSHash256Zero()
                                                                   merkleRoot:WSHash256FromHex(@"4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b")
                                                                    timestamp:1296688602
                                                                         bits:0x1d00ffff
                                                                        nonce:414098458];

        NSAssert([genesisHeader.blockId isEqual:WSHash256FromHex(@"000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943")], @"Bad genesis block id (testnet3)");
        
        // The testnet genesis block uses the mainnet genesis block's merkle root. The hash is wrong using its own root.
        WSPartialMerkleTree *genesisPMT = [[WSPartialMerkleTree alloc] initWithTxCount:1
                                                                                hashes:@[genesisHeader.merkleRoot]
                                                                                 flags:[NSData dataWithBytes:"\x01" length:1]
                                                                                 error:NULL];

        parameters.genesisBlock = [[WSFilteredBlock alloc] initWithHeader:genesisHeader partialMerkleTree:genesisPMT];
        
        [parameters loadCheckpointsWithNetworkName:WSParametersTypeString(self.parametersType)];

        [parameters addDnsSeed:@"testnet-seed.bitcoin.petertodd.org"];
        [parameters addDnsSeed:@"testnet-seed.bluematt.me"];
        [parameters addDnsSeed:@"testnet-seed.alexykot.me"];
        
        self.parameters = parameters;
    }
    return self;
}

- (WSParametersType)parametersType
{
    return WSParametersTypeTestnet3;
}

@end
