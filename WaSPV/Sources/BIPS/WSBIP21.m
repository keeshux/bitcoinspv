//
//  WSBIP21.m
//  WaSPV
//
//  Created by Davide De Rosa on 08/12/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
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

#import "DDLog.h"

#import "WSBIP21.h"
#import "WSAddress.h"
#import "WSConfig.h"
#import "WSErrors.h"

NSString *const         WSBIP21URLScheme        = @"bitcoin";

static NSString *const  WSBIP21URLRegex         = @"^bitcoin:([A-Za-z0-9-IlO0]*)(\\?.*)?$";

@interface WSBIP21URL ()

@property (nonatomic, copy) NSString *label;
@property (nonatomic, strong) WSAddress *address;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) uint64_t amount;
@property (nonatomic, copy) NSDictionary *others;

- (instancetype)initWithString:(NSString *)string;

@end

@implementation WSBIP21URL

+ (instancetype)URLWithString:(NSString *)string
{
    return [[self alloc] initWithString:string];
}

- (instancetype)initWithString:(NSString *)string
{
    WSExceptionCheckIllegal(string != nil, @"Nil string");

    NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern:WSBIP21URLRegex options:0 error:NULL];
    NSArray *matches = [rx matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    if (matches.count == 0) {
        DDLogWarn(@"Malformed BIP21 URL (%@)", string);
        return nil;
    }
    
    NSTextCheckingResult *result = [matches firstObject];

    NSString *addressString = [string substringWithRange:[result rangeAtIndex:1]];
    WSAddress *address = [[WSAddress alloc] initWithEncoded:addressString];
    if (!address) {
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
            return nil;
        }
        amount = [[amountNumber decimalNumberByMultiplyingByPowerOf10:8] unsignedLongLongValue];
    }

    NSString *label = arguments[@"label"];
    NSString *message = arguments[@"message"];

    if ((self = [super init])) {
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
