//
//  NSData+Hash.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 13/06/14.
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

#import <CommonCrypto/CommonDigest.h>
#import <openssl/ripemd.h>

#import "NSData+Hash.h"

@implementation NSData (Hash)

- (NSData *)SHA1
{
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(self.bytes, (CC_LONG)self.length, hash.mutableBytes);
    return hash;
}

- (NSData *)SHA256
{
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(self.bytes, (CC_LONG)self.length, hash.mutableBytes);
    return hash;
}

- (NSData *)RMD160
{
    NSMutableData *hash = [NSMutableData dataWithLength:RIPEMD160_DIGEST_LENGTH];
    RIPEMD160(self.bytes, self.length, hash.mutableBytes);
    return hash;
}

- (NSData *)hash160
{
//    return [[self SHA256] RMD160];

    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(self.bytes, (CC_LONG)self.length, hash.mutableBytes);
    RIPEMD160(hash.bytes, hash.length, hash.mutableBytes);
    hash.length = RIPEMD160_DIGEST_LENGTH;
    return hash;
}

- (NSData *)hash256
{
//    return [[self SHA256] SHA256];

    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(self.bytes, (CC_LONG)self.length, hash.mutableBytes);
    CC_SHA256(hash.bytes, (CC_LONG)hash.length, hash.mutableBytes);
    return hash;
}

@end
