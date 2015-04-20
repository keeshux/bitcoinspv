//
//  NSString+Base58.m
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

#import "NSString+Base58.h"
#import "NSString+Binary.h"
#import "NSData+Base58.h"
#import "NSData+Binary.h"
#import "WSHash256.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSBitcoinConstants.h"

// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/NSString%2BBase58.m

@implementation NSString (Base58)

#pragma mark Base58

- (NSData *)dataFromBase58
{
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:(self.length * 138 / 100 + 1)];
    unsigned int b;
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM base, x, y;
    
    BN_CTX_start(ctx);
    BN_init(&base);
    BN_init(&x);
    BN_init(&y);
    BN_set_word(&base, 58);
    BN_zero(&x);
    
    for (NSUInteger i = 0; i < self.length; ++i) {
        if ([self characterAtIndex:i] != WSBase58Alphabet[0]) {
            break;
        }
        [data appendBytes:"\0" length:1];
    }
    
    BOOL error = NO;
    for (NSUInteger i = 0; i < self.length; ++i) {
        b = [self characterAtIndex:i];
        
        if ((b >= '1') && (b <= '9')) {
            b -= '1';
        }
        else if ((b >= 'A') && (b <= 'H')) {
            b += 9 - 'A';
        }
        else if ((b >= 'J') && (b <= 'N')) {
            b += 17 - 'J';
        }
        else if ((b >= 'P') && (b <= 'Z')) {
            b += 22 - 'P';
        }
        else if ((b >= 'a') && (b <= 'k')) {
            b += 33 - 'a';
        }
        else if ((b >= 'm') && (b <= 'z')) {
            b += 44 - 'm';
        }
        else {
            error = YES;
            break;
        }
        
        BN_mul(&x, &x, &base, ctx);
        BN_set_word(&y, b);
        BN_add(&x, &x, &y);
    }
    
    if (!error) {
        data.length += BN_num_bytes(&x);
        BN_bn2bin(&x, (unsigned char *)data.mutableBytes + data.length - BN_num_bytes(&x));
    }
    
    OPENSSL_cleanse(&b, sizeof(b));
    BN_clear_free(&y);
    BN_clear_free(&x);
    BN_free(&base);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
    
    if (error) {
        return nil;
    }
    return data;
}

- (NSString *)base58FromHex
{
    return [[self dataFromHex] base58String];
}

- (NSString *)hexFromBase58
{
    return [[self dataFromBase58] hexString];
}

#pragma mark Base58Check

- (NSData *)dataFromBase58Check
{
    NSData *fullData = [self dataFromBase58];
    if (fullData.length < 4) {
        return nil;
    }
    
    NSData *data = [fullData subdataWithRange:NSMakeRange(0, fullData.length - 4)];
    WSHash256 *hash256 = WSHash256Compute(data);

    const uint32_t expectedChecksum = *(uint32_t *)hash256.bytes;
    const uint32_t checksum = *(uint32_t *)((const uint8_t *)fullData.bytes + fullData.length - 4);
    if (checksum != expectedChecksum) {
        DDLogDebug(@"Bad Base58Check checksum (%u != %u)", checksum, expectedChecksum);
        return nil;
    }

    return data;
}

- (NSString *)base58CheckFromHex
{
    return [[self dataFromHex] base58CheckString];
}

- (NSString *)hexFromBase58Check
{
    return [[self dataFromBase58Check] hexString];
}

@end
