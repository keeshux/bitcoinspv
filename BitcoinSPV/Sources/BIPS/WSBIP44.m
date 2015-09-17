//
//  WSBIP44.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 17/09/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
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

#import "WSBIP44.h"
#import "WSErrors.h"

static NSString *const WSBIP44DefaultPathFormat = @"m/44'/%u'/%u'";

@implementation WSParameters (BIP44)

- (WSBIP44CoinType)coinType
{
    switch (self.networkType) {
        case WSNetworkTypeMain: {
            return WSBIP44CoinTypeMain;
        }
        case WSNetworkTypeTestnet3: {
            return WSBIP44CoinTypeTestnet3;
        }
        default: {
            WSExceptionCheck(NO, @"No BIP44 coin type available for %@ network", [self networkTypeString]);
            return 0;
        }
    }
}

- (NSString *)bip44PathForAccount:(uint32_t)account
{
    return [NSString stringWithFormat:WSBIP44DefaultPathFormat, self.coinType, account];
}

@end
