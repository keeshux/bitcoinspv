//
//  WSWebTickerMonitor.m
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

#import "WSWebTickerMonitor.h"
#import "WSWebTicker.h"
#import "WSLogging.h"
#import "WSErrors.h"
#import "WSMacrosCore.h"

NSString *const WSWebTickerMonitorDidUpdateConversionRatesNotification = @"WSWebTickerMonitorDidUpdateConversionRatesNotification";

@interface WSWebTickerMonitor ()

@property (nonatomic, strong) NSTimer *fetchTimer;
@property (nonatomic, strong) NSArray *tickers;
@property (nonatomic, assign) NSTimeInterval tickerInterval;
@property (nonatomic, assign) NSUInteger nextTickerIndex;
@property (nonatomic, strong) NSMutableSet *pendingTickers;
@property (nonatomic, strong) NSMutableDictionary *conversionRates;

- (void)fetchAllRates;
- (void)fetchNextRates;
- (void)fetchNextRatesAndCycle;

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
    WSExceptionCheckIllegal(providers.count > 0);
    WSExceptionCheckIllegal(updateInterval / providers.count >= 10.0);
    
    NSMutableArray *tickers = [[NSMutableArray alloc] initWithCapacity:providers.count];
    for (NSString *provider in providers) {
        id<WSWebTicker> ticker = [WSWebTickerFactory tickerForProvider:provider];
        [tickers addObject:ticker];
    }

    self.tickers = tickers;
    self.tickerInterval = updateInterval / self.tickers.count;
    self.nextTickerIndex = 0;
    self.pendingTickers = [[NSMutableSet alloc] initWithCapacity:self.tickers.count];
    self.conversionRates = [[NSMutableDictionary alloc] init];

    [self fetchAllRates];
    self.fetchTimer = [NSTimer scheduledTimerWithTimeInterval:self.tickerInterval target:self selector:@selector(fetchNextRatesAndCycle) userInfo:nil repeats:NO];
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

- (void)fetchAllRates
{
    for (NSUInteger i = 0; i < self.tickers.count; ++i) {
        [self fetchNextRates];
    }
}

- (void)fetchNextRates
{
    id<WSWebTicker> ticker = self.tickers[self.nextTickerIndex];
    DDLogVerbose(@"Fetching ticker: %@", ticker.provider);
    self.nextTickerIndex = (self.nextTickerIndex + 1) % self.tickers.count;

    if ([self.pendingTickers containsObject:ticker]) {
        DDLogVerbose(@"Skipping pending ticker: %@", ticker.provider);
        return;
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

- (void)fetchNextRatesAndCycle
{
    [self fetchNextRates];
    self.fetchTimer = [NSTimer scheduledTimerWithTimeInterval:self.tickerInterval target:self selector:@selector(fetchNextRatesAndCycle) userInfo:nil repeats:NO];
}

- (NSArray *)availableCurrencyCodes
{
    return [self.conversionRates allKeys];
}

- (BOOL)isAvailableCurrencyCode:(NSString *)currencyCode
{
    WSExceptionCheckIllegal(currencyCode);

    return (self.conversionRates[currencyCode] != nil);
}

- (NSNumber *)averageConversionRateToCurrencyCode:(NSString *)currencyCode
{
    WSExceptionCheckIllegal(currencyCode);
    
    NSDictionary *ratesByProvider = self.conversionRates[currencyCode];
    if (!ratesByProvider) {
        return nil;
    }
    double rate = 0.0;
    for (NSString *provider in [ratesByProvider allKeys]) {
        rate += [ratesByProvider[provider] doubleValue];
    }
    return @(rate / ratesByProvider.count);
}

@end
