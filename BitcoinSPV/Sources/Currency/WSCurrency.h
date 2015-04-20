//
//  WSCurrency.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 01/01/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    WSCurrencySymbolPositionPrepend, // default
    WSCurrencySymbolPositionAppend
} WSCurrencySymbolPosition;

@protocol WSCurrency <NSObject>

- (NSString *)code;
- (WSCurrencySymbolPosition)symbolPosition;
- (NSDecimalNumber *)conversionRateToCurrency:(id<WSCurrency>)currency;
- (NSDecimalNumber *)convertValue:(NSDecimalNumber *)value toCurrency:(id<WSCurrency>)currency;

@end
