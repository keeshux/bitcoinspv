//
//  WSParametersFactoryRegtest.m
//  WaSPV
//
//  Created by Davide De Rosa on 21/07/14.
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

#import "WSParametersFactoryRegtest.h"
#import "WSHash256.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSPartialMerkleTree.h"
#import "WSBitcoin.h"
#import "WSMacros.h"

@interface WSParametersFactoryRegtest ()

@property (nonatomic, strong) WSMutableParameters *parameters;

@end

@implementation WSParametersFactoryRegtest

- (instancetype)init
{
    if ((self = [super init])) {
        WSMutableParameters *parameters = [[WSMutableParameters alloc] init];
        
        parameters.magicNumber                  = 0xdab5bffa;
        parameters.publicKeyAddressVersion      = 0x6f;
        parameters.scriptAddressVersion         = 0xc4;
        parameters.privateKeyVersion            = 0xef;
        parameters.peerPort                     = 18444;
#warning TODO: what are bip32 magics on regtest?
//        parameters.bip32PublicKeyVersion        = 0x0488b21e; // "xpub"
//        parameters.bip32PrivateKeyVersion       = 0x0488ade4; // "xprv"
        parameters.maxProofOfWork               = 0x1d00ffff;
//        parameters.retargetTimespan             = 2 * WSDatesOneWeek;
//        parameters.minRetargetTimespan          = parameters.retargetTimespan / 4;
//        parameters.maxRetargetTimespan          = parameters.retargetTimespan * 4;
//        parameters.retargetSpacing              = 10 * WSDatesOneMinute;
        parameters.retargetInterval             = 10000;
        
        WSBlockHeader *genesisHeader = [[WSBlockHeader alloc] initWithVersion:1
                                                              previousBlockId:WSHash256Zero()
                                                                   merkleRoot:WSHash256FromHex(@"4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b")
                                                                    timestamp:1296688602
                                                                         bits:0x207fffff
                                                                        nonce:2];
        
        NSAssert([genesisHeader.blockId isEqual:WSHash256FromHex(@"0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206")], @"Bad genesis block id (regtest)");
        
        WSPartialMerkleTree *genesisPMT = [[WSPartialMerkleTree alloc] initWithTxCount:1
                                                                                hashes:@[genesisHeader.merkleRoot]
                                                                                 flags:[NSData dataWithBytes:"\x01" length:1]
                                                                                 error:NULL];
        
        parameters.genesisBlock = [[WSFilteredBlock alloc] initWithHeader:genesisHeader partialMerkleTree:genesisPMT];

        // no seeds for regtest
        
        self.parameters = parameters;
    }
    return self;
}

- (WSParametersType)parametersType
{
    return WSParametersTypeRegtest;
}

@end
