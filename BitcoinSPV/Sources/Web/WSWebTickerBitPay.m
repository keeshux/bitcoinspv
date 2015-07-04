//
//  WSWebTickerBitPay.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 04/07/15.
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

#import "WSWebTickerBitPay.h"
#import "WSJSONClient.h"
#import "WSLogging.h"
#import "WSErrors.h"
#import "WSMacrosCore.h"

static NSString *const          WSWebTickerBitPayBaseURL                = @"https://bitpay.com/";

@implementation WSWebTickerBitPay

#pragma mark WSWebTicker

- (NSString *)provider
{
    return WSWebTickerProviderBitPay;
}

- (void)fetchRatesWithSuccess:(void (^)(NSDictionary *))success failure:(void (^)(NSError *))failure
{
    WSExceptionCheckIllegal(success);
    WSExceptionCheckIllegal(failure);
    
    NSURL *baseURL = [NSURL URLWithString:WSWebTickerBitPayBaseURL];
    NSString *path = @"rates";
    
    [[WSJSONClient sharedInstance] asynchronousRequestWithBaseURL:baseURL path:path success:^(NSInteger statusCode, id object) {
        if (statusCode == 200) {
            NSDictionary *result = object;
            
            NSMutableDictionary *conversionRates = [[NSMutableDictionary alloc] initWithCapacity:result.count];
            for (NSDictionary *currencyData in result[@"data"]) {
                NSString *currencyCode = currencyData[@"code"];
                NSString *rateString = currencyData[@"rate"];
                const double rate = [rateString doubleValue];
                
                if (rate > 0.0) {
                    conversionRates[currencyCode] = @(rate);
                }
                else {
                    DDLogWarn(@"Invalid BTC/%@ rate (%@)", currencyCode, rateString);
                }
            }
            success(conversionRates);
        }
        else {
            failure(WSErrorMake(WSErrorCodeWebService, @"Unexpected ticker status code (%d)", statusCode));
        }
    } failure:^(NSInteger statusCode, NSError *error) {
        failure(error);
    }];
}

@end
