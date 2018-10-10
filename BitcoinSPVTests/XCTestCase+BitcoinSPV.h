//
//  XCTestCase+BitcoinSPV.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 07/07/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//
//  https://github.com/keeshux
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

#import <XCTest/XCTest.h>

#import "BitcoinSPV.h"
#import "WSLogging.h"

@protocol WSMessage;
@class WSPeer;

@interface XCTestCase (BitcoinSPV)

- (WSNetworkType)networkType;
- (void)setNetworkType:(WSNetworkType)networkType;
- (WSParameters *)networkParameters;

- (NSString *)mockWalletMnemonic;
- (WSSeed *)mockWalletSeed;
- (NSString *)mockPathForFile:(NSString *)file;
- (NSString *)mockNetworkPathForFilename:(NSString *)filename extension:(NSString *)extension;

- (void)runForever;
- (void)runForSeconds:(NSTimeInterval)seconds;
- (void)stopRunning;

- (void)delayBlock:(void (^)())block seconds:(NSTimeInterval)seconds;
- (id<WSMessage>)assertMessageSequenceForPeer:(WSPeer *)peer expectedClasses:(NSArray *)expectedClasses timeout:(NSTimeInterval)timeout;

@end
