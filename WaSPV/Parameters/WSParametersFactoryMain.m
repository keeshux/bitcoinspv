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
        parameters.forkBlockHeight              = 250000;
        parameters.forkBlockTimestamp           = 1375533383;
        
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
        
#warning TODO: checkpoints, will soon be loaded from file
        [parameters addCheckpoint:WSCheckpointMake( 10, @"000000000f1aef56190aee63d33a373e6487132d522ff4cd98ccfc96566d461e", 1248481816, 0x1d00ffff)];
        [parameters addCheckpoint:WSCheckpointMake( 20, @"0000000045861e169b5a961b7034f8de9e98022e7a39100dde3ae3ea240d7245", 1266191579, 0x1c654657)];
        [parameters addCheckpoint:WSCheckpointMake( 30, @"000000000632e22ce73ed38f46d5b408ff1cff2cc9e10daaf437dfd655153837", 1276298786, 0x1c0eba64)];
        [parameters addCheckpoint:WSCheckpointMake( 40, @"0000000000307c80b87edf9f6a0697e2f01db67e518c8a4d6065d1d859a3a659", 1284861847, 0x1b4766ed)];
        [parameters addCheckpoint:WSCheckpointMake( 50, @"000000000000e383d43cc471c64a9a4a46794026989ef4ff9611d5acb704e47a", 1294031411, 0x1b0404cb)];
        [parameters addCheckpoint:WSCheckpointMake( 60, @"0000000000002c920cf7e4406b969ae9c807b5c4f271f490ca3de1b0770836fc", 1304131980, 0x1b0098fa)];
        [parameters addCheckpoint:WSCheckpointMake( 70, @"00000000000002d214e1af085eda0a780a8446698ab5c0128b6392e189886114", 1313451894, 0x1a094a86)];
        [parameters addCheckpoint:WSCheckpointMake( 80, @"00000000000005911fe26209de7ff510a8306475b75ceffd434b68dc31943b99", 1326047176, 0x1a0d69d7)];
        [parameters addCheckpoint:WSCheckpointMake( 90, @"00000000000000e527fc19df0992d58c12b98ef5a17544696bbba67812ef0e64", 1337883029, 0x1a0a8b5f)];
        [parameters addCheckpoint:WSCheckpointMake(100, @"00000000000003a5e28bef30ad31f1f9be706e91ae9dda54179a95c9f9cd9ad0", 1349226660, 0x1a057e08)];
        [parameters addCheckpoint:WSCheckpointMake(110, @"00000000000000fc85dd77ea5ed6020f9e333589392560b40908d3264bd1f401", 1361148470, 0x1a04985c)];
        [parameters addCheckpoint:WSCheckpointMake(120, @"00000000000000b79f259ad14635739aaf0cc48875874b6aeecc7308267b50fa", 1371418654, 0x1a00de15)];
        [parameters addCheckpoint:WSCheckpointMake(130, @"000000000000000aa77be1c33deac6b8d3b7b0757d02ce72fffddc768235d0e2", 1381070552, 0x1916b0ca)];
        [parameters addCheckpoint:WSCheckpointMake(140, @"0000000000000000ef9ee7529607286669763763e0c46acfdefd8a2306de5ca8", 1390570126, 0x1901f52c)];
        [parameters addCheckpoint:WSCheckpointMake(150, @"0000000000000000472132c4daaf358acaf461ff1c3e96577a74e5ebf91bb170", 1400928750, 0x18692842)];

        [parameters addDnsSeed:@"seed.bitcoin.sipa.be"];
        [parameters addDnsSeed:@"dnsseed.bluematt.me"];
        [parameters addDnsSeed:@"dnsseed.bitcoin.dashjr.org"];
//        [parameters addDnsSeed:@"bitseed.xf2.org"]; // seems faulting
        
        self.parameters = parameters;
    }
    return self;
}

@end
