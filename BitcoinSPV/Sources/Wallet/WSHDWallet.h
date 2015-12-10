//
//  WSHDWallet.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 22/07/14.
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

#import <Foundation/Foundation.h>

#import "WSWallet.h"

@class WSParameters;
@class WSSeed;

#pragma mark -

@interface WSHDWallet : NSObject <WSSynchronizableWallet>

@property (nonatomic, assign) BOOL shouldAutoSave; // NO
@property (nonatomic, assign) BOOL maySpendUnconfirmed; // NO

- (instancetype)initWithParameters:(WSParameters *)parameters seed:(WSSeed *)seed;
- (instancetype)initWithParameters:(WSParameters *)parameters seed:(WSSeed *)seed chainsPath:(NSString *)chainsPath;
- (instancetype)initWithParameters:(WSParameters *)parameters seed:(WSSeed *)seed chainsPath:(NSString *)chainsPath gapLimit:(NSUInteger)gapLimit;
- (WSParameters *)parameters;
- (WSSeed *)seed;
- (NSUInteger)gapLimit;

- (NSArray *)watchedReceiveAddresses; // WSAddress

//
// WARNING: seed is NOT serialized and MUST be saved elsewhere
//
// NSKeyedUnarchiver deserialization alone won't be able to restore
// the wallet, you should only use the following method and explicity
// provide the seed each time you reload a serialized wallet.
//
+ (instancetype)loadFromPath:(NSString *)path parameters:(WSParameters *)parameters seed:(WSSeed *)seed;

@end
