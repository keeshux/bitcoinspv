//
//  WSWebTickerMonitor.m
//  WaSPV
//
//  Created by Davide De Rosa on 01/01/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
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

#import "WSWebTickerMonitor.h"
#import "WSWebTicker.h"
#import "WSErrors.h"
#import "WSMacros.h"

NSString *const WSWebTickerMonitorDidUpdateConversionRatesNotification = @"WSWebTickerMonitorDidUpdateConversionRatesNotification";

@interface WSWebTickerMonitor ()

@property (nonatomic, strong) NSTimer *fetchTimer;
@property (nonatomic, copy) NSSet *tickers;
@property (nonatomic, strong) NSMutableSet *pendingTickers;
@property (nonatomic, strong) NSMutableDictionary *conversionRates;

- (void)fetchNewRates;

@end

@implementation WSWebTickerMonitor

+ (instancetype)sharedInstance
{
    static WSWebTickerMonitor *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if ((self = [super init])) {
    }
    return self;
}

- (void)startWithProviders:(NSSet *)providers updateInterval:(NSTimeInterval)updateInterval
{
    WSExceptionCheckIllegal(providers.count > 0, @"Empty providers");
    WSExceptionCheckIllegal(updateInterval >= 10.0, @"updateInterval must be at least 10 seconds");
    
    NSMutableSet *tickers = [[NSMutableSet alloc] initWithCapacity:providers.count];
    for (NSString *provider in providers) {
        id<WSWebTicker> ticker = [WSWebTickerFactory tickerForProvider:provider];
        [tickers addObject:ticker];
    }

    self.tickers = tickers;
    self.pendingTickers = [[NSMutableSet alloc] initWithCapacity:self.tickers.count];
    self.conversionRates = [[NSMutableDictionary alloc] init];
    self.fetchTimer = [NSTimer timerWithTimeInterval:updateInterval target:self selector:@selector(fetchNewRates) userInfo:nil repeats:YES];
    
    [self fetchNewRates];
    [[NSRunLoop currentRunLoop] addTimer:self.fetchTimer forMode:NSRunLoopCommonModes];
}

- (void)stop
{
    [self.fetchTimer invalidate];
    self.fetchTimer = nil;
}

- (BOOL)isStarted
{
    return (self.fetchTimer != nil);
}

- (void)fetchNewRates
{
    for (id<WSWebTicker> ticker in self.tickers) {
        DDLogDebug(@"Fetching ticker: %@", ticker.provider);

        if ([self.pendingTickers containsObject:ticker]) {
            DDLogDebug(@"Skipping pending ticker: %@", ticker.provider);
            continue;
        }
        
        [self.pendingTickers addObject:ticker];

        [ticker fetchRatesWithSuccess:^(NSDictionary *rates) {
            [self.pendingTickers removeObject:ticker];

            for (NSString *currencyCode in [rates allKeys]) {
                NSMutableDictionary *ratesByProvider = self.conversionRates[currencyCode];
                if (!ratesByProvider) {
                    ratesByProvider = [[NSMutableDictionary alloc] init];
                    self.conversionRates[currencyCode] = ratesByProvider;
                }
                ratesByProvider[ticker.provider] = rates[currencyCode];
            }

            DDLogVerbose(@"Conversion rates: %@", self.conversionRates);

            [[NSNotificationCenter defaultCenter] postNotificationName:WSWebTickerMonitorDidUpdateConversionRatesNotification object:nil];
        } failure:^(NSError *error) {
            [self.pendingTickers removeObject:ticker];
        }];
    }
}

- (NSArray *)availableCurrencyCodes
{
    return [self.conversionRates allKeys];
}

- (double)averageConversionRateToCurrencyCode:(NSString *)currencyCode
{
    WSExceptionCheckIllegal(currencyCode != nil, @"Nil currencyCode");
    
    NSDictionary *ratesByProvider = self.conversionRates[currencyCode];
    double rate = 0.0;
    for (NSString *provider in [ratesByProvider allKeys]) {
        rate += [ratesByProvider[provider] doubleValue];
    }
    return rate / ratesByProvider.count;
}

@end
