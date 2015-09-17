//
//  WSParametersFactoryTestnet3.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 02/07/14.
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

#import "WSParametersFactoryTestnet3.h"
#import "WSHash256.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSPartialMerkleTree.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"

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

@property (nonatomic, strong) WSParameters *parameters;

@end

@implementation WSParametersFactoryTestnet3

- (instancetype)init
{
    if ((self = [super init])) {
        WSParametersBuilder *builder = [[WSParametersBuilder alloc] initWithNetworkType:WSNetworkTypeTestnet3];

        builder.magicNumber                 = 0x0709110b;
        builder.publicKeyAddressVersion     = 0x6f;
        builder.scriptAddressVersion        = 0xc4;
        builder.privateKeyVersion           = 0xef;
        builder.peerPort                    = 18333;
        builder.bip32PublicKeyVersion       = 0x043587cf; // "tpub"
        builder.bip32PrivateKeyVersion      = 0x04358394; // "tprv"
        builder.maxProofOfWork              = 0x1d00ffff;
//        builder.retargetTimespan            = 2 * WSDatesOneWeek;
//        builder.minRetargetTimespan         = builder.retargetTimespan / 4;
//        builder.maxRetargetTimespan         = builder.retargetTimespan * 4;
        builder.retargetSpacing             = 20 * WSDatesOneMinute;
//        builder.retargetInterval            = builder.retargetTimespan / builder.retargetSpacing; // 2016
        builder.retargetInterval            = 2016;

        builder.genesisVersion              = 1;
        builder.genesisMerkleRoot           = WSHash256FromHex(@"4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b");
        builder.genesisTimestamp            = 1296688602;
        builder.genesisBits                 = 0x1d00ffff;
        builder.genesisNonce                = 414098458;

        builder.dnsSeeds = @[@"testnet-seed.bitcoin.petertodd.org",
                             @"testnet-seed.bluematt.me"];
//                             @"testnet-seed.alexykot.me"]; // seems offline as of 02/07/2015

        builder.checkpointsHex = @"01000000487f6bcc6f25427d5547cc2a83f196311bbdaf69eef318969fc45913000000003704109964ecdd4945c22822c99923afb98e5cb03e04f81b83aa5d0a3670914bfa172b5056174d1c0073bb7d00c04e00000701755495464b3002000000889e7db0e0dbbde6951fbfaf3407c3d6feafbff8e426779fb091d14600000000548ec9dc20323b597b940d5b16720711166d3c115029235a4abe1cfffb5e36477e9dd250ffff001d532ff06b00809d0000070fe77684f3ec280200000073cf900411ea13984e5cf0bc9a8bac4640d22ab1d248d60e5784923d00000000d9559c183e2354f357f3a2e99e06fae33cb9ab07e2365813ed61058b96ab3504f11c49518aca1e1c0aba90510040ec00000715ff2905e401780200000063bf07e954697b4c2b43c5f596e1c163849ac0586218e3f40f131002000000004c40e5a6827e8062d31b90f69a9bafe89f5bebb4f65672b7d8e50a5892491588f1ee9951481c011c8135491500003b010007206d7ea49fe01b020000001939e922692d67e9da0c512082b3caaebaf04fac89499b07f310af000000000022c4fd8dd050b04bac685e24a0d0d6d21101ad605bc9effed2a654016e903836b2640c5207d9001cda8a7fb700c08901000743dafaa1ce816a02000000df4ec6ed71e5e7e5d85ce93e0a6cbab9ae11e602f264221fc463210000000000b7fa74ddbd347c8098f6e201f50c710d2c66b9450a070dbc9e70ac1f03396e04e70960524cdf001c32371f7c0080d8010007f189048869c59202000000ba1e00d6a2108713066876984957fe6e089657e7bde7dbd729c4612f00000000771259ebf63621781fceed9670201b87897afa88521585802b990f72300d1632e4b78552f0ff0f1c5a2b413a00402702000802515e6e86ab61040200000073c7bcf3fea4b38a53832eaef761591e25514d6b8bcbe8e40e62b60c00000000c6c240c950a610125c23a1a633fc532dc4ffd3c3efef6782a55c3f7a7cb6e6a89228ca52fcff031ca05b2a6a0000760200080334412ffb6a17280200000089caf4252568558099767daf413f38678c3c10a0a6384ec19fe0290000000000a32a1793ad96dbbd7a3ecac4ea32498a894182234a70c12fc2b86344c79fb78fb7e0fc52e66c331b69d04be600c0c40200080425c62140fdb70702000000ee689e4dcdc3c7dac591b98e1e4dc83aae03ff9fb9d469d704a64c0100000000bfffaded2a67821eb5729b362d613747e898d08d6c83b5704646c26c13146f4c6de91353c02a601b3a817f870080130300080453e926d09ebe8702000000a8f9d80911fbdc7f0e6f81cdfa9125275c78d03618810cda423a34000000000013a3d15779e60d221ceb89841c81f0e09e3211969fb136a4c5f22626746231f9e7034b53f0ff0f1bd2af1ba9004062030008055d1bee04d99987020000006224e3c5c739d0ff81a0f6e0c387d9dcd1b10196dd87f1b6d0360e00000000008184ab79e5224c41d2ae40f1d2b60158575eb6101136ab8ca142a9915516b7b5a5976e530d54051be5eb3f140000b103000809067fdc4b846366020000008e86ba6b5cffc6038ef41b73604eb8e5bc6b797a0e5880aa8c1f01000000000042e1631220a3b7036289224a082e868b770e696f69c998c03d354a6c03f0334d58cf9853e644021b53279c7300c0ff0300080c78d772dab5c34f0200000060b7ca3e5187040bf5e6504997f639e2a6c3cf984e87eb05cd8f2e0d0000000042933b32ca96d8d065be03715a3b09ffcfb897d611f87826669acb6963ba64b1e11e2d54ffff001dbadae28a00804e0400085c0d9ac47f5dcc8902000000a5895a55e1291fc575f21f107adfb24f4adfba8a75deb716ed32000000000000c6cd6732a04c51f08b2af9ed3277ddf83f5cb97cf6e90b30dda26f1aa2f575245f5c44545e60331a024203fb00409d0400086cbd857d49334fe602000000f38d8b2571e7b2f57406ac7ac058c3386c32ed0b79a0dfef5a01000000000000bd4b8ab104897616274b19f9669df9eb675a67425edb5ceac2aaddba3a8d2a960e42d854d8a2031a1e6ecad40000ec040009028d06e4c309e0726503000000b7ecd7722556c2a68a48e717f3bdfefe7defcb11651534e634f704000000000083ad3bcdd52d58c7d5d6315c88872cb5bce1a8cf6bbe2580ff7b98c777b85f4814812c55f0ff0f1b917804a100c03a05000903cac6991cb15b603f030000005d821834688d20f0381ca5effba14d548740a58c54a4db25051294160000000016fdb9db95d9026b626a1bd6a1cd7eb2f41e1f0a389df7887841131e01ebd27fb35f3c55f0ff0f1c56427a9100808905000903dbb60ce49f7d55fa03000000f29c963cff790fa15917611b4da5cab58ba2fb12b96bd3f0c4da3b030000000075d1d4feef9d5dc911086962091e75bae28c93c55a3a14bd1822dbe0064d115ee9834355ffff001ce2dcd9660040d805000903e27e00a2933b47d6030000007ccf123dcf34b0c5627969c6eebfe4934fbd65244bf93109cd5282000000000065eecfb9cb61b373d7e8da19fa27ebab09c3a367369506763f173a5e40f8b64062dd57556c34021c218f078c000027060009040daadc59a609eb52030000004811a16e1b4d9231dd0ba02e94fa7052383f8f16746d1ac9b97ea608000000009648f1dc7c2be6161fcb02e4f434a05ba14b59cb531d7e67ec4a3be374f2d458be845e55fcff031c674cf31000c075060009040e7125fc92368907030000008d5a47aefb5bc3362e87968f82ce1dff725aa5212df192766607010000000000569f1a445df2dba27f1c2ba14a043297f6221f3f30439dbd9a96cc52510fef97abce6255ffff001b8048cb460080c406000904110ac422305c249403000000e57bb05b54519b03566659229bdfcc52cb90a485b4a0e0c0b6a5010000000000fee1337e0e78f6145711ef745d2cd2acf8cf1f9ba43540892c7517adb591585ca5ed7855f8ec001be9b44417004013070009042827d6e38a7300ad0300000062df3fcb7cd9ed0cbbf94603e16c55b12289a9a20e5cb7dde382000000000000bbec5ebcf31165275e0ca674a53a3b18c299d8f5c8d8f3c626a0dbc3b9ef3eae76ba8455c0b5461a6053f508000062070009044623d5c2ec15c6fd0300000069ea2a30f71b993f5692ed2d7feb266d8780d7a327743e79e6af010000000000619d9580aef06044392706715e917766e71d5a594b0299d08949209f563d4c4f8a25a65586ab001b831c312900c0b007000904639f9eb1096877b903000000a74a2630fc61a593405d71e817b8f1fe67e68bf0fb4e95fc21400900000000009b98a4ba527739754d3503cb5e176e0dededd7e7773629a3a911d417f556a26a4d1abf559c2e031b756deb820080ff070009049469b514092e914a030000001864f40d45977f38864ec14b918651d185c7dbef67ac30dc5b83200000000000a8995d02bb37ec4e0640dae114d57fbe246825a787cffa1f2c35ad32eba35bf010a6e65500aa301b43e9166e00404e0800090553422a059a72d269";
        
        self.parameters = [builder build];

        NSAssert([self.parameters.genesisBlockId isEqual:WSHash256FromHex(@"000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943")],
                 @"Bad genesis block id (testnet3)");
    }
    return self;
}

@end
