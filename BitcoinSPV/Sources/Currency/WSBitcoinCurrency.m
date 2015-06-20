//
//  WSBitcoinCurrency.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 28/12/14.
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

#import "WSBitcoinCurrency.h"
#import "WSErrors.h"

NSString *const WSBitcoinCurrencyCodeBTC            = @"BTC";
NSString *const WSBitcoinCurrencyCodeMilliBTC       = @"mBTC";
NSString *const WSBitcoinCurrencyCodeBits           = @"bits";
NSString *const WSBitcoinCurrencyCodeSatoshi        = @"SAT";

@interface WSBitcoinCurrency ()

@property (nonatomic, copy) NSString *code;
@property (nonatomic, assign) short powerOf10;

- (instancetype)initWithCode:(NSString *)code powerOf10:(short)powerOf10;

@end

@implementation WSBitcoinCurrency

+ (instancetype)currencyForCode:(NSString *)code
{
    WSExceptionCheckIllegal(code);

    static NSDictionary *currencies;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        currencies = @{WSBitcoinCurrencyCodeBTC: [[self alloc] initWithCode:WSBitcoinCurrencyCodeBTC powerOf10:8],
                       WSBitcoinCurrencyCodeMilliBTC: [[self alloc] initWithCode:WSBitcoinCurrencyCodeMilliBTC powerOf10:5],
                       WSBitcoinCurrencyCodeBits: [[self alloc] initWithCode:WSBitcoinCurrencyCodeBits powerOf10:2],
                       WSBitcoinCurrencyCodeSatoshi: [[self alloc] initWithCode:WSBitcoinCurrencyCodeSatoshi powerOf10:0]};
    });
    return currencies[code];
}

+ (instancetype)referenceCurrency
{
    return [self currencyForCode:WSBitcoinCurrencyCodeBTC];
}

- (instancetype)initWithCode:(NSString *)code powerOf10:(short)powerOf10
{
    WSExceptionCheckIllegal(code);
    WSExceptionCheckIllegal(powerOf10 >= 0);
    
    if ((self = [super init])) {
        self.code = code;
        self.powerOf10 = powerOf10;
    }
    return self;
}

- (BOOL)isReference
{
    return (self == [[self class] referenceCurrency]);
}

- (NSDecimalNumber *)valueFromSatoshi:(uint64_t)satoshi
{
    const NSDecimal satoshiDecimal = [[NSNumber numberWithUnsignedLongLong:satoshi] decimalValue];
    NSDecimalNumber *satoshiNumber = [NSDecimalNumber decimalNumberWithDecimal:satoshiDecimal];
    return [self valueFromSatoshiNumber:satoshiNumber];
}

- (NSDecimalNumber *)valueFromSatoshiNumber:(NSDecimalNumber *)satoshiNumber
{
    WSExceptionCheckIllegal(satoshiNumber);

    return [satoshiNumber decimalNumberByMultiplyingByPowerOf10:-self.powerOf10];
}

- (uint64_t)satoshiFromValue:(NSDecimalNumber *)value
{
    WSExceptionCheckIllegal(value);

    return [[self satoshiNumberFromValue:value] unsignedLongLongValue];
}

- (NSDecimalNumber *)satoshiNumberFromValue:(NSDecimalNumber *)value
{
    WSExceptionCheckIllegal(value);

    return [value decimalNumberByMultiplyingByPowerOf10:self.powerOf10];
}

#pragma mark WSCurrency

- (WSCurrencySymbolPosition)symbolPosition
{
    return WSCurrencySymbolPositionAppend;
}

- (NSDecimalNumber *)conversionRateToCurrency:(id<WSCurrency>)currency
{
    WSExceptionCheckIllegal(currency);

    if ([currency isKindOfClass:[self class]]) {
        return [NSDecimalNumber one];
    }
    return [currency conversionRateToCurrency:self];
}

- (NSDecimalNumber *)convertValue:(NSDecimalNumber *)value toCurrency:(id<WSCurrency>)currency
{
    WSExceptionCheckIllegal(value);
    WSExceptionCheckIllegal(currency);
    
    if (currency == self) {
        return value;
    }

    NSDecimalNumber *convertedValue = value;
    if ([currency isKindOfClass:[WSBitcoinCurrency class]]) {
        WSBitcoinCurrency *bitcoinCurrency = (WSBitcoinCurrency *)currency;
        convertedValue = [convertedValue decimalNumberByMultiplyingByPowerOf10:self.powerOf10];
        convertedValue = [convertedValue decimalNumberByMultiplyingByPowerOf10:-bitcoinCurrency.powerOf10];
    }
    else {
        WSBitcoinCurrency *referenceCurrency = [[self class] referenceCurrency];
        NSDecimalNumber *conversionRate = [referenceCurrency conversionRateToCurrency:currency];
        if (!conversionRate) {
            convertedValue = nil;
        }
        else {
            if (self != referenceCurrency) {
                convertedValue = [self convertValue:convertedValue toCurrency:referenceCurrency];
            }
            convertedValue = [convertedValue decimalNumberByDividingBy:conversionRate];
        }
    }
    return convertedValue;
}

@end
