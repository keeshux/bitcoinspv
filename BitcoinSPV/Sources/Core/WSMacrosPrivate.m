//
//  WSMacrosPrivate.m
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

#import "WSMacrosPrivate.h"

#pragma mark - Blocks

#import "WSBlockHeader.h"
#import "WSBlock.h"
#import "WSPartialMerkleTree.h"
#import "WSFilteredBlock.h"

//
// difficulty = maxTarget / target > 1.0
// maxDifficulty = maxTarget / maxTarget = 1.0
//
static inline void WSBlockGetDifficultyInteger(WSParameters *parameters, BIGNUM *diffInteger, BIGNUM *diffFraction, const BIGNUM *target)
{
    NSCParameterAssert(parameters);
    
    BIGNUM maxTarget;
    
    BN_init(&maxTarget);
    WSBlockSetBits(&maxTarget, [parameters maxProofOfWork]);
    
    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);
    BN_div(diffInteger, diffFraction, &maxTarget, target, ctx);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
    
    BN_free(&maxTarget);
}

NSData *WSBlockGetDifficultyFromBits(WSParameters *parameters, uint32_t bits)
{
    BIGNUM target;
    BIGNUM diffInteger;
    BIGNUM diffFraction;
    
    BN_init(&target);
    BN_init(&diffInteger);
    BN_init(&diffFraction);
    
    WSBlockSetBits(&target, bits);
    WSBlockGetDifficultyInteger(parameters, &diffInteger, &diffFraction, &target);
    NSData *difficulty = WSBlockDataFromWork(&diffInteger);
    
    BN_free(&target);
    BN_free(&diffInteger);
    BN_free(&diffFraction);
    
    return difficulty;
}

NSString *WSBlockGetDifficultyStringFromBits(WSParameters *parameters, uint32_t bits)
{
    BIGNUM target;
    BIGNUM diffInteger;
    //    BIGNUM diffFraction;
    
    BN_init(&target);
    BN_init(&diffInteger);
    //    BN_init(&diffFraction);
    
    WSBlockSetBits(&target, bits);
    //    WSBlockGetDifficultyInteger(&diffInteger, &diffFraction, &target);
    //    NSString *string = [NSString stringWithFormat:@"%s.%s", BN_bn2dec(&diffInteger), BN_bn2dec(&diffFraction)];
    WSBlockGetDifficultyInteger(parameters, &diffInteger, NULL, &target);
    NSString *string = [NSString stringWithUTF8String:BN_bn2dec(&diffInteger)];
    
    BN_free(&target);
    BN_free(&diffInteger);
    //    BN_free(&diffFraction);
    
    return string;
}
