//
//  NSData+Base58.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 02/07/14.
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

#import <openssl/bn.h>

#import "NSData+Base58.h"
#import "WSHash256.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"

// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/NSString%2BBase58.m

@implementation NSData (Base58)

- (NSString *)base58String
{
    const NSUInteger length = self.length * 138 / 100 + 2;
    NSUInteger i = length;
    char cBase58[i];
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM base, x, r;
    
    BN_CTX_start(ctx);
    BN_init(&base);
    BN_init(&x);
    BN_init(&r);
    BN_set_word(&base, 58);
    BN_bin2bn(self.bytes, (int)self.length, &x);
    
    --i;
    cBase58[i] = '\0';
    
    while (!BN_is_zero(&x)) {
        BN_div(&x, &r, &x, &base, ctx);
        --i;
        cBase58[i] = WSBase58Alphabet[BN_get_word(&r)];
    }
    
    for (NSUInteger j = 0; j < self.length; ++j) {
        if (*((const uint8_t *)self.bytes + j) != 0) {
            break;
        }
        --i;
        cBase58[i] = WSBase58Alphabet[0];
    }
    
    BN_clear_free(&r);
    BN_clear_free(&x);
    BN_free(&base);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
    
    NSString *base58 = [NSString stringWithCString:&cBase58[i] encoding:NSUTF8StringEncoding];
    OPENSSL_cleanse(cBase58, length);
    return base58;
}

- (NSString *)base58CheckString
{
    NSMutableData *data = [self mutableCopy];
    WSHash256 *hash256 = WSHash256Compute(data);
    [data appendBytes:hash256.bytes length:4];
    return [data base58String];
}

@end
