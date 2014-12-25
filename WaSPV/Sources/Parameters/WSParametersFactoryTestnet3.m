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

//
// https://en.bitcoin.it/wiki/Testnet
//
// Key differences from main network:
//
// Minimum difficulty of 1.0 on testnet is equal to difficulty of 0.5 on mainnet.
// This means that the mainnet-equivalent of any testnet difficulty is half the testnet difficulty.
// In addition, if no block has been found in 20 minutes, the difficulty automatically resets back
// to the minimum for a single block, after which it returns to its previous value.
//
// The IsStandard() check is disabled so that non-standard transactions can be experimented with.
//

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
//        parameters.retargetTimespan             = 2 * WSDatesOneWeek;
//        parameters.minRetargetTimespan          = parameters.retargetTimespan / 4;
//        parameters.maxRetargetTimespan          = parameters.retargetTimespan * 4;
        parameters.retargetSpacing              = 20 * WSDatesOneMinute;
//        parameters.retargetInterval             = parameters.retargetTimespan / parameters.retargetSpacing; // 2016
        parameters.retargetInterval             = 2016;

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
        [parameters loadCheckpointsFromHex:@"01000000487f6bcc6f25427d5547cc2a83f196311bbdaf69eef318969fc45913000000003704109964ecdd4945c22822c99923afb98e5cb03e04f81b83aa5d0a3670914bfa172b5056174d1c0073bb7d00c04e00000701755495464b3002000000889e7db0e0dbbde6951fbfaf3407c3d6feafbff8e426779fb091d14600000000548ec9dc20323b597b940d5b16720711166d3c115029235a4abe1cfffb5e36477e9dd250ffff001d532ff06b00809d0000070fe77684f3ec280200000073cf900411ea13984e5cf0bc9a8bac4640d22ab1d248d60e5784923d00000000d9559c183e2354f357f3a2e99e06fae33cb9ab07e2365813ed61058b96ab3504f11c49518aca1e1c0aba90510040ec00000715ff2905e401780200000063bf07e954697b4c2b43c5f596e1c163849ac0586218e3f40f131002000000004c40e5a6827e8062d31b90f69a9bafe89f5bebb4f65672b7d8e50a5892491588f1ee9951481c011c8135491500003b010007206d7ea49fe01b020000001939e922692d67e9da0c512082b3caaebaf04fac89499b07f310af000000000022c4fd8dd050b04bac685e24a0d0d6d21101ad605bc9effed2a654016e903836b2640c5207d9001cda8a7fb700c08901000743dafaa1ce816a02000000df4ec6ed71e5e7e5d85ce93e0a6cbab9ae11e602f264221fc463210000000000b7fa74ddbd347c8098f6e201f50c710d2c66b9450a070dbc9e70ac1f03396e04e70960524cdf001c32371f7c0080d8010007f189048869c59202000000ba1e00d6a2108713066876984957fe6e089657e7bde7dbd729c4612f00000000771259ebf63621781fceed9670201b87897afa88521585802b990f72300d1632e4b78552f0ff0f1c5a2b413a00402702000802515e6e86ab61040200000073c7bcf3fea4b38a53832eaef761591e25514d6b8bcbe8e40e62b60c00000000c6c240c950a610125c23a1a633fc532dc4ffd3c3efef6782a55c3f7a7cb6e6a89228ca52fcff031ca05b2a6a0000760200080334412ffb6a17280200000089caf4252568558099767daf413f38678c3c10a0a6384ec19fe0290000000000a32a1793ad96dbbd7a3ecac4ea32498a894182234a70c12fc2b86344c79fb78fb7e0fc52e66c331b69d04be600c0c40200080425c62140fdb70702000000ee689e4dcdc3c7dac591b98e1e4dc83aae03ff9fb9d469d704a64c0100000000bfffaded2a67821eb5729b362d613747e898d08d6c83b5704646c26c13146f4c6de91353c02a601b3a817f870080130300080453e926d09ebe8702000000a8f9d80911fbdc7f0e6f81cdfa9125275c78d03618810cda423a34000000000013a3d15779e60d221ceb89841c81f0e09e3211969fb136a4c5f22626746231f9e7034b53f0ff0f1bd2af1ba9004062030008055d1bee04d99987020000006224e3c5c739d0ff81a0f6e0c387d9dcd1b10196dd87f1b6d0360e00000000008184ab79e5224c41d2ae40f1d2b60158575eb6101136ab8ca142a9915516b7b5a5976e530d54051be5eb3f140000b103000809067fdc4b846366020000008e86ba6b5cffc6038ef41b73604eb8e5bc6b797a0e5880aa8c1f01000000000042e1631220a3b7036289224a082e868b770e696f69c998c03d354a6c03f0334d58cf9853e644021b53279c7300c0ff0300080c78d772dab5c34f0200000060b7ca3e5187040bf5e6504997f639e2a6c3cf984e87eb05cd8f2e0d0000000042933b32ca96d8d065be03715a3b09ffcfb897d611f87826669acb6963ba64b1e11e2d54ffff001dbadae28a00804e0400085c0d9ac47f5dcc8902000000a5895a55e1291fc575f21f107adfb24f4adfba8a75deb716ed32000000000000c6cd6732a04c51f08b2af9ed3277ddf83f5cb97cf6e90b30dda26f1aa2f575245f5c44545e60331a024203fb00409d0400086cbd857d49334fe6"];

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
