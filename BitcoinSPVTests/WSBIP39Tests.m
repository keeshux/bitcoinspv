//
//  WSBIP39Tests.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 18/06/14.
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

#import "XCTestCase+BitcoinSPV.h"

@interface WSBIP39Tests : XCTestCase

@property (nonatomic, strong) WSSeedGenerator *bip39;

@end

@implementation WSBIP39Tests

- (void)setUp
{
    [super setUp];

    self.bip39 = [WSSeedGenerator sharedInstance];
}

- (void)tearDown
{
    [self.bip39 unloadWords];

    [super tearDown];
}

- (void)testMnemonicSyntax
{
    NSError *error;

    XCTAssertFalse([self.bip39 dataFromMnemonic:@"one" error:&error], @"Accepted invalid mnemonic");
    XCTAssertFalse([self.bip39 dataFromMnemonic:@"   one  two three " error:&error], @"Accepted invalid mnemonic");
    XCTAssertFalse([self.bip39 dataFromMnemonic:@"one  two   three" error:&error], @"Accepted invalid mnemonic");
    XCTAssertTrue([self.bip39 dataFromMnemonic:@"one two three" error:&error], @"%@", error);
}

- (void)testMnemonic
{
    NSString *mnemonic = [self.bip39 generateRandomMnemonic];

    DDLogInfo(@"Mnemonic: %@", mnemonic);
    NSData *mnemData = [self.bip39 dataFromMnemonic:mnemonic error:NULL];
    XCTAssertNotNil(mnemData, @"Invalid mnemonic");

    DDLogInfo(@"Mnemonic (hex): %@", [mnemData hexString]);
    NSString *decoded = [self.bip39 mnemonicFromData:mnemData error:NULL];

    DDLogInfo(@"Mnemonic: %@", decoded);
    XCTAssertEqualObjects(decoded, mnemonic, @"Decoded seedphrase doesn't match original");
}

- (void)testSeed
{
    WSSeed *seed = [self.bip39 generateRandomSeed];

    DDLogInfo(@"Mnemonic: %@", seed.mnemonic);
    NSData *mnemData = [self.bip39 dataFromMnemonic:seed.mnemonic error:nil];
    XCTAssertNotNil(mnemData, @"Invalid mnemonic");

    DDLogInfo(@"Mnemonic (hex): %@", [mnemData hexString]);
    NSString *decodedMnemonic = [self.bip39 mnemonicFromData:mnemData error:nil];

    DDLogInfo(@"Mnemonic: %@", decodedMnemonic);
    XCTAssertEqualObjects(decodedMnemonic, seed.mnemonic, @"Decoded mnemonic doesn't match original");
}

@end
