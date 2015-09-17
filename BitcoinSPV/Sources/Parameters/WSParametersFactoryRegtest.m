//
//  WSParametersFactoryRegtest.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 21/07/14.
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

#import "WSParametersFactoryRegtest.h"
#import "WSHash256.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSPartialMerkleTree.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"

@interface WSParametersFactoryRegtest ()

@property (nonatomic, strong) WSParameters *parameters;

@end

@implementation WSParametersFactoryRegtest

- (instancetype)init
{
    if ((self = [super init])) {
        WSParametersBuilder *builder = [[WSParametersBuilder alloc] initWithNetworkType:WSNetworkTypeRegtest];
        
        builder.magicNumber                 = 0xdab5bffa;
        builder.publicKeyAddressVersion     = 0x6f;
        builder.scriptAddressVersion        = 0xc4;
        builder.privateKeyVersion           = 0xef;
        builder.peerPort                    = 18444;
//        builder.bip32PublicKeyVersion       = 0x0488b21e; // "xpub"
//        builder.bip32PrivateKeyVersion      = 0x0488ade4; // "xprv"
        builder.maxProofOfWork              = 0x1d00ffff;
//        builder.retargetTimespan            = 2 * WSDatesOneWeek;
//        builder.minRetargetTimespan         = builder.retargetTimespan / 4;
//        builder.maxRetargetTimespan         = builder.retargetTimespan * 4;
//        builder.retargetSpacing             = 10 * WSDatesOneMinute;
        builder.retargetInterval            = 10000;
        
        builder.genesisVersion              = 1;
        builder.genesisMerkleRoot           = WSHash256FromHex(@"4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b");
        builder.genesisTimestamp            = 1296688602;
        builder.genesisBits                 = 0x207fffff;
        builder.genesisNonce                = 2;

        // no seeds nor checkpoints for regtest
        
        self.parameters = [builder build];

        NSAssert([self.parameters.genesisBlockId isEqual:WSHash256FromHex(@"0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206")],
                 @"Bad genesis block id (regtest)");
        
    }
    return self;
}

@end
