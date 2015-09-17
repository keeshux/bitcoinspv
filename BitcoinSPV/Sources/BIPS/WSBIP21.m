//
//  WSBIP21.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/12/14.
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

#import "WSBIP21.h"
#import "WSAddress.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

NSString *const         WSBIP21URLScheme        = @"bitcoin";

static NSString *const  WSBIP21URLRegex         = @"^bitcoin:([A-Za-z0-9-IlO0]*)(\\?.*)?$";


@interface WSBIP21URLBuilder ()

@property (nonatomic, strong) WSParameters *parameters;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, strong) WSAddress *address;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) uint64_t amount;
@property (nonatomic, copy) NSDictionary *others;

@end

@implementation WSBIP21URLBuilder

+ (instancetype)builder
{
    return [[self alloc] init];
}

- (instancetype)address:(WSAddress *)address
{
    WSExceptionCheckIllegal(address);
    self.address = address;
    return self;
}

- (instancetype)label:(NSString *)label
{
    WSExceptionCheckIllegal(label);
    self.label = label;
    return self;
}

- (instancetype)message:(NSString *)message
{
    WSExceptionCheckIllegal(message);
    self.message = message;
    return self;
}

- (instancetype)amount:(uint64_t)amount
{
    WSExceptionCheckIllegal(amount > 0);
    self.amount = amount;
    return self;
}

- (instancetype)others:(NSDictionary *)others
{
    WSExceptionCheckIllegal(others.count > 0);
    self.others = others;
    return self;
}

- (WSBIP21URL *)build
{
    return [[WSBIP21URL alloc] initWithBuilder:self];
}

@end

#pragma mark -

@interface WSBIP21URL ()

@property (nonatomic, copy) NSString *string;
@property (nonatomic, strong) WSAddress *address;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) uint64_t amount;
@property (nonatomic, copy) NSDictionary *others;

- (instancetype)initWithParameters:(WSParameters *)parameters string:(NSString *)string;

@end

@implementation WSBIP21URL

+ (instancetype)URLWithParameters:(WSParameters *)parameters string:(NSString *)string
{
    return [[self alloc] initWithParameters:parameters string:string];
}

- (instancetype)initWithParameters:(WSParameters *)parameters string:(NSString *)string
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(string);

    NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern:WSBIP21URLRegex options:0 error:NULL];
    NSArray *matches = [rx matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    if (matches.count == 0) {
        DDLogDebug(@"Malformed BIP21 URL (%@)", string);
        return nil;
    }
    
    NSTextCheckingResult *result = [matches firstObject];

    NSString *addressString = [string substringWithRange:[result rangeAtIndex:1]];
    WSAddress *address = [[WSAddress alloc] initWithParameters:parameters encoded:addressString];
    if (!address) {
        DDLogDebug(@"Invalid address '%@' in URL (%@)", addressString, string);
        return nil;
    }

    NSArray *queryComponents = nil;
    if (result.numberOfRanges > 2) {
        NSRange range = [result rangeAtIndex:2];
        if (range.location != NSNotFound) {

            // skip '?'
            ++range.location;
            --range.length;

            NSString *query = [string substringWithRange:range];
            queryComponents = [query componentsSeparatedByString:@"&"];
        }
    }

    NSMutableDictionary *arguments = [[NSMutableDictionary alloc] initWithCapacity:queryComponents.count];
    for (NSString *pair in queryComponents) {
        NSString *decodedPair = [pair stringByRemovingPercentEncoding];

        NSArray *keyValue = [decodedPair componentsSeparatedByString:@"="];
        NSString *key = keyValue[0];
        NSString *value = ((keyValue.count > 1) ? keyValue[1] : nil);

        if (key && value) {
            arguments[key] = value;
        }
    }
    
    NSString *amountString = arguments[@"amount"];
    uint64_t amount = 0LL;
    if (amountString) {
        NSDecimalNumber *amountNumber = [NSDecimalNumber decimalNumberWithString:amountString];
        if (!amountNumber) {
            DDLogDebug(@"Invalid amount '%@' in URL (%@)", amountString, string);
            return nil;
        }
        amount = [[amountNumber decimalNumberByMultiplyingByPowerOf10:8] unsignedLongLongValue];
    }

    NSString *label = arguments[@"label"];
    NSString *message = arguments[@"message"];

    if ((self = [super init])) {
        self.string = string;
        self.label = label;
        self.address = address;
        self.message = message;
        self.amount = amount;
        
        [arguments removeObjectForKey:@"label"];
        [arguments removeObjectForKey:@"message"];
        [arguments removeObjectForKey:@"amount"];
        self.others = arguments;
    }
    return self;
}

- (instancetype)initWithBuilder:(WSBIP21URLBuilder *)builder
{
    if ((self = [super init])) {
        self.address = builder.address;
        self.label = builder.label;
        self.message = builder.message;
        self.amount = builder.amount;
        self.others = builder.others;

        NSMutableString *string = [[NSMutableString alloc] initWithString:WSBIP21URLScheme];
        [string appendString:@":"];
        if (self.address) {
            [string appendString:self.address.encoded];
        }
        
        NSMutableArray *optionals = [[NSMutableArray alloc] initWithCapacity:4];
        if (self.label.length > 0) {
            [optionals addObject:[NSString stringWithFormat:@"label=%@", [self.label stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        }
        if (self.message.length > 0) {
            [optionals addObject:[NSString stringWithFormat:@"message=%@", [self.message stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        }
        if (self.amount > 0) {
            NSDecimalNumber *amountNumber = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%llu", self.amount]];
            amountNumber = [amountNumber decimalNumberByMultiplyingByPowerOf10:-8];

            [optionals addObject:[NSString stringWithFormat:@"amount=%@", [amountNumber description]]];
        }
        if (self.others.count > 0) {
            for (NSString *key in [self.others allKeys]) {
                NSString *value = self.others[key];
                [optionals addObject:[NSString stringWithFormat:@"%@=%@", key, [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
            }
        }
        if (optionals.count > 0) {
            [string appendString:@"?"];
            NSString *query = [optionals componentsJoinedByString:@"&"];
            [string appendString:query];
        }
        self.string = string;
    }
    return self;
}

- (NSString *)description
{
    NSMutableArray *components = [[NSMutableArray alloc] initWithCapacity:4];
    [components addObject:[NSString stringWithFormat:@"address=%@", self.address]];
    if (self.amount > 0) {
        [components addObject:[NSString stringWithFormat:@"amount=%llu", self.amount]];
    }
    if (self.label) {
        [components addObject:[NSString stringWithFormat:@"label=%@", self.label]];
    }
    if (self.message) {
        [components addObject:[NSString stringWithFormat:@"message=%@", self.message]];
    }
    if (self.others.count > 0) {
        [components addObject:[NSString stringWithFormat:@"others=%@", self.others]];
    }
    return [NSString stringWithFormat:@"{%@}", [components componentsJoinedByString:@", "]];
}

@end
