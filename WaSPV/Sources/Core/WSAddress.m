//
//  WSAddress.m
//  WaSPV
//
//  Created by Davide De Rosa on 02/07/14.
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

#import "WSAddress.h"
#import "WSHash160.h"
#import "WSScript.h"
#import "WSConfig.h"
#import "WSBitcoin.h"
#import "WSMacros.h"
#import "WSErrors.h"
#import "NSData+Base58.h"
#import "NSString+Base58.h"

@interface WSAddress ()

@property (nonatomic, assign) uint8_t version;
@property (nonatomic, strong) WSHash160 *hash160;
@property (nonatomic, strong) NSString *encoded;

@end

@implementation WSAddress

- (instancetype)initWithVersion:(uint8_t)version hash160:(WSHash160 *)hash160
{
    WSExceptionCheckIllegal(hash160 != nil, @"Nil hash160");
    WSExceptionCheckIllegal((version == [WSCurrentParameters publicKeyAddressVersion]) ||
                            (version == [WSCurrentParameters scriptAddressVersion]),
                             @"Unrecognized address version (%u)", version);

    if ((self = [super init])) {
        self.version = version;
        self.hash160 = hash160;

        NSMutableData *data = [[NSMutableData alloc] initWithCapacity:WSAddressLength];
        [data appendBytes:&_version length:1];
        [data appendData:self.hash160.data];
        self.encoded = [data base58CheckString];
    }
    return self;
}

- (instancetype)initWithEncoded:(NSString *)encoded
{
    WSExceptionCheckIllegal(encoded != nil, @"Nil encoded");
    
    NSData *data = [encoded dataFromBase58Check];
    if (data.length != WSAddressLength) {
        DDLogVerbose(@"Invalid Bitcoin address (length: %u != %u)", data.length, WSAddressLength);
        return nil;
    }
    
    const uint8_t version = *(const uint8_t *)data.bytes;
    if ((version != [WSCurrentParameters publicKeyAddressVersion]) &&
        (version != [WSCurrentParameters scriptAddressVersion])) {
        
        DDLogVerbose(@"Unrecognized Bitcoin address version (%u)", version);
        return nil;
    }
    
    NSData *hash160Data = [data subdataWithRange:NSMakeRange(1, data.length - 1)];
    
    if ((self = [super init])) {
        self.version = version;
        self.hash160 = WSHash160FromData(hash160Data);
        self.encoded = [encoded copy];
    }
    return self;
}

- (NSString *)hexEncoded
{
    return [self.encoded hexFromBase58Check];
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSAddress *address = object;
    return [address.encoded isEqualToString:self.encoded];
}

- (NSUInteger)hash
{
    return [self.encoded hash];
}

- (NSString *)description
{
    return self.encoded;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSAddress *copy = [[self class] allocWithZone:zone];
    copy.version = self.version;
    copy.hash160 = [self.hash160 copyWithZone:zone];
    copy.encoded = [self.encoded copyWithZone:zone];
    return copy;
}

@end
