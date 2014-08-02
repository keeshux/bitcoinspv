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
        parameters.forkBlockHeight              = 150000;
        parameters.forkBlockTimestamp           = 1386098130;

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
        
#warning TODO: checkpoints, will soon be loaded from file
        [parameters addCheckpoint:WSCheckpointMake( 10, @"000000001cf5440e7c9ae69f655759b17a32aad141896defd55bb895b7cfc44e", 1345001466, 0x1c4d1756)];
        [parameters addCheckpoint:WSCheckpointMake( 20, @"000000008011f56b8c92ff27fb502df5723171c5374673670ef0eee3696aee6d", 1355980158, 0x1d00ffff)];
        [parameters addCheckpoint:WSCheckpointMake( 30, @"00000000130f90cda6a43048a58788c0a5c75fa3c32d38f788458eb8f6952cee", 1363746033, 0x1c1eca8a)];
        [parameters addCheckpoint:WSCheckpointMake( 40, @"00000000002d0a8b51a9c028918db3068f976e3373d586f08201a4449619731c", 1369042673, 0x1c011c48)];
        [parameters addCheckpoint:WSCheckpointMake( 50, @"0000000000a33112f86f3f7b0aa590cb4949b84c2d9c673e9e303257b3be9000", 1376543922, 0x1c00d907)];
        [parameters addCheckpoint:WSCheckpointMake( 60, @"00000000003367e56e7f08fdd13b85bbb31c5bace2f8ca2b0000904d84960d0c", 1382025703, 0x1c00df4c)];
        [parameters addCheckpoint:WSCheckpointMake( 70, @"0000000007da2f551c3acd00e34cc389a4c6b6b3fad0e4e67907ad4c7ed6ab9f", 1384495076, 0x1c0ffff0)];
        [parameters addCheckpoint:WSCheckpointMake( 80, @"0000000001d1b79a1aec5702aaa39bad593980dfe26799697085206ef9513486", 1388980370, 0x1c03fffc)];
        [parameters addCheckpoint:WSCheckpointMake( 90, @"00000000002bb4563a0ec21dc4136b37dcd1b9d577a75a695c8dd0b861e1307e", 1392304311, 0x1b336ce6)];
        [parameters addCheckpoint:WSCheckpointMake(100, @"0000000000376bb71314321c45de3015fe958543afcbada242a3b1b072498e38", 1393813869, 0x1b602ac0)];
        [parameters addCheckpoint:WSCheckpointMake(110, @"0000000000093e3a0660bb313153bebc7c05adf4565c8c6b0ef0686d42f1b9ac", 1397425127, 0x1b0ffff0)];
        [parameters addCheckpoint:WSCheckpointMake(120, @"000000000003eb193d52322049b8c0886038f0cbd2ee1e6df0aecc37b2626ce4", 1399756709, 0x1b05540d)];
        [parameters addCheckpoint:WSCheckpointMake(130, @"0000000000002b8cb23efac26d7329bcc12b0112a5b84dbcb087d686ca8d48a7", 1402523480, 0x1b0244e6)];

        [parameters addDnsSeed:@"testnet-seed.bitcoin.petertodd.org"];
        [parameters addDnsSeed:@"testnet-seed.bluematt.me"];
        [parameters addDnsSeed:@"testnet-seed.alexykot.me"];
        
        self.parameters = parameters;
    }
    return self;
}

@end
