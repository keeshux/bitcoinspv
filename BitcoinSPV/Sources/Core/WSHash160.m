//
//  WSHash160.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 10/12/14.
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

#import "WSHash160.h"
#import "WSErrors.h"
#import "WSBitcoinConstants.h"
#import "NSData+Binary.h"

@interface WSHash160 ()

@property (nonatomic, strong) NSData *data;

@end

@implementation WSHash160

- (instancetype)initWithData:(NSData *)data
{
    WSExceptionCheckIllegal(data.length == WSHash160Length);
    
    if ((self = [super init])) {
        self.data = data;
    }
    return self;
}

- (const void *)bytes
{
    return self.data.bytes;
}

- (NSUInteger)length
{
    return WSHash160Length;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSHash160 *hash160 = object;
    return [hash160.data isEqualToData:self.data];
}

- (NSUInteger)hash
{
    return [self.data hash];
}

- (NSString *)description
{
    return [[self.data reverse] hexString];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSHash160 *copy = [[self class] allocWithZone:zone];
    copy.data = [self.data copyWithZone:zone];
    return copy;
}

@end
