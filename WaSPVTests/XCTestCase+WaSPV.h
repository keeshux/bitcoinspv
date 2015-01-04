//
//  XCTestCase+WaSPV.h
//  WaSPV
//
//  Created by Davide De Rosa on 07/07/14.
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

#import <XCTest/XCTest.h>
#import "DDLog.h"

#import "WSConfig.h"
#import "WSBitcoin.h"
#import "WSMacros.h"
#import "WSErrors.h"
#import "NSString+Base58.h"
#import "NSString+Binary.h"
#import "NSData+Base58.h"
#import "NSData+Binary.h"
#import "NSData+Hash.h"

@protocol WSMessage;
@class WSPeer;

@interface XCTestCase (WaSPV)

- (WSNetworkType)networkType;
- (void)setNetworkType:(WSNetworkType)networkType;
- (id<WSParameters>)networkParameters;

- (NSString *)mockWalletMnemonic;
- (WSSeed *)mockWalletSeed;
- (NSString *)mockPathForFile:(NSString *)file;

- (void)runForever;
- (void)runForSeconds:(NSTimeInterval)seconds;
- (void)stopRunning;

- (void)delayBlock:(void (^)())block seconds:(NSTimeInterval)seconds;
- (id<WSMessage>)assertMessageSequenceForPeer:(WSPeer *)peer expectedClasses:(NSArray *)expectedClasses timeout:(NSTimeInterval)timeout;

@end
