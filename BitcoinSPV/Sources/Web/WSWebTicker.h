//
//  WSWebTicker.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 01/01/15.
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

#import <Foundation/Foundation.h>

#import "WSPhysicalCurrency.h"

extern NSString *const WSWebTickerProviderBitPay;
extern NSString *const WSWebTickerProviderBitstamp;
extern NSString *const WSWebTickerProviderBlockchain;

@protocol WSWebTicker;

@interface WSWebTickerFactory : NSObject

+ (id<WSWebTicker>)tickerForProvider:(NSString *)provider;

@end

#pragma mark -

@protocol WSWebTicker <NSObject>

- (NSString *)provider;

//
// success returns a {"XXX": "BTC/XXX rate"} dictionary where XXX is a WSPhysicalCurrencyCode*
//
- (void)fetchRatesWithSuccess:(void (^)(NSDictionary *))success failure:(void (^)(NSError *))failure;

@end
