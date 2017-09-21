//
//  WSMacrosPrivate.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 04/07/14.
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

#import <Foundation/Foundation.h>

#pragma mark - Blocks

#import <openssl/bn.h>

#import "WSHash256.h"
#import "WSParameters.h"
#import "NSData+Binary.h"

//
// "Compact" is a way to represent a 256-bit number as 32-bit.
//
// bits = size(8 bits) | word(24 bits)
//
// target = word << (8 * (size - 3))
//

//
// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRMerkleBlock.m
//
static inline void WSBlockSetBits(BIGNUM *target, uint32_t bits)
{
    const uint32_t size = bits >> 24;
    const uint32_t word = bits & 0x007fffff;
    
    if (size > 3) {
        BN_set_word(target, word);
        BN_lshift(target, target, 8 * (size - 3));
    }
    else {
        BN_set_word(target, word >> (8 * (3 - size)));
    }
    
    BN_set_negative(target, (bits & 0x00800000) != 0);
}

//
// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRMerkleBlock.m
//
static inline uint32_t WSBlockGetBits(const BIGNUM *target)
{
    uint32_t size = BN_num_bytes(target);
    uint32_t compact = 0;
    BIGNUM x;
    
    if (size > 3) {
        BN_init(&x);
        BN_rshift(&x, target, 8 * (size - 3));
        compact = (uint32_t)BN_get_word(&x);
    }
    else {
        compact = (uint32_t)(BN_get_word(target) << (8 * (3 - size)));
    }
    
    // if sign is already set, divide the mantissa by 256 and increment the exponent
    if (compact & 0x00800000) {
        compact >>= 8;
        ++size;
    }
    
    return (compact | (size << 24)) | (BN_is_negative(target) ? 0x00800000 : 0);
}

static inline void WSBlockSetHash(BIGNUM *hash, WSHash256 *blockId)
{
    BN_bin2bn(blockId.data.reverse.bytes, (int)blockId.length, hash);
}

static inline NSData *WSBlockDataFromWork(BIGNUM *work)
{
    NSMutableData *data = [[NSMutableData alloc] initWithLength:BN_num_bytes(work)];
    BN_bn2bin(work, data.mutableBytes);
    return data;
}

static inline void WSBlockWorkFromData(BIGNUM *work, NSData *data)
{
    BN_bin2bn(data.bytes, (int)data.length, work);
}

NSData *WSBlockGetDifficultyFromBits(WSParameters *parameters, uint32_t bits);
NSString *WSBlockGetDifficultyStringFromBits(WSParameters *parameters, uint32_t bits);
