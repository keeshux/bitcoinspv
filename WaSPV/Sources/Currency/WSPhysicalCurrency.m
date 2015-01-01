//
//  WSPhysicalCurrency.m
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

#import "WSPhysicalCurrency.h"
#import "WSBitcoinCurrency.h"
#import "WSErrors.h"

NSString *const WSPhysicalCurrencyCodeUSD       = @"USD";
NSString *const WSPhysicalCurrencyCodeEUR       = @"EUR";

@interface WSPhysicalCurrency ()

@property (nonatomic, copy) NSString *code;
@property (nonatomic, strong) NSDictionary *conversionRates;

+ (NSSet *)knownCurrencyCodes;

@end

@implementation WSPhysicalCurrency

+ (NSSet *)knownCurrencyCodes
{
    static NSSet *codes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        codes = [NSSet setWithObjects:WSPhysicalCurrencyCodeUSD, WSPhysicalCurrencyCodeEUR, nil];
    });
    return codes;
}

- (instancetype)initWithCode:(NSString *)code conversionRates:(NSDictionary *)conversionRates
{
    WSExceptionCheckIllegal(code != nil, @"Nil code");
    WSExceptionCheckIllegal([[[self class] knownCurrencyCodes] containsObject:code], @"Unknown currency code (%@)", code);
    WSExceptionCheckIllegal(conversionRates != nil, @"Nil conversionRates");
    
    if ((self = [super init])) {
        self.code = code;
        self.conversionRates = conversionRates;
    }
    return self;
}

#pragma mark WSCurrency

- (NSDecimalNumber *)conversionRateToCurrency:(id<WSCurrency>)currency
{
    WSExceptionCheckIllegal(currency != nil, @"Nil currency");
    WSExceptionCheckIllegal(self.conversionRates != nil, @"conversionRates not set");
    
    if ([currency.code isEqualToString:self.code]) {
        return [NSDecimalNumber one];
    }
    NSNumber *rateNumber = self.conversionRates[currency.code];
    if (!rateNumber) {
        return nil;
    }
    return [NSDecimalNumber decimalNumberWithDecimal:[rateNumber decimalValue]];
}

- (NSDecimalNumber *)convertValue:(NSDecimalNumber *)value toCurrency:(id<WSCurrency>)currency
{
    WSExceptionCheckIllegal(value != nil, @"Nil value");
    WSExceptionCheckIllegal(currency != nil, @"Nil currency");
    
    if (currency == self) {
        return value;
    }
    
    id<WSCurrency> conversionCurrency = currency;
    NSDecimalNumber *convertedValue = value;
    if ([currency isKindOfClass:[WSBitcoinCurrency class]]) {
        conversionCurrency = [WSBitcoinCurrency referenceCurrency];
    }
    NSDecimalNumber *conversionRate = [self conversionRateToCurrency:conversionCurrency];
    if (!conversionRate) {
        return nil;
    }
    convertedValue = [convertedValue decimalNumberByMultiplyingBy:conversionRate];
    if (conversionCurrency != currency) {
        convertedValue = [conversionCurrency convertValue:convertedValue toCurrency:currency];
    }
    return convertedValue;
}

@end
