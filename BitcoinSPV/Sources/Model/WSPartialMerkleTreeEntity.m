//
//  WSPartialMerkleTreeEntity.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 12/07/14.
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

#import "WSPartialMerkleTreeEntity.h"
#import "WSStorableBlockEntity.h"
#import "WSHash256.h"
#import "WSMacrosCore.h"
#import "WSBitcoinConstants.h"

@implementation WSPartialMerkleTreeEntity

@dynamic txCount;
@dynamic hashesData;
@dynamic flags;
@dynamic block;

- (void)copyFromPartialMerkleTree:(WSPartialMerkleTree *)partialMerkleTree
{
    self.txCount = @(partialMerkleTree.txCount);

    NSArray *hashes = partialMerkleTree.hashes;
    NSMutableData *hashesData = [[NSMutableData alloc] initWithCapacity:(hashes.count * WSHash256Length)];
    for (WSHash256 *hash in hashes) {
        [hashesData appendData:hash.data];
    }
    self.hashesData = hashesData;

    self.flags = [partialMerkleTree.flags copy];
}

- (WSPartialMerkleTree *)toPartialMerkleTree
{
    const uint32_t txCount = (uint32_t)[self.txCount unsignedIntegerValue];

    NSAssert((self.hashesData.length % WSHash256Length == 0),
             @"Corrupted hashesData, not multiple of %lu",
             (unsigned long)WSHash256Length);

    const NSUInteger hashesCount = self.hashesData.length / WSHash256Length;
    NSMutableArray *hashes = [[NSMutableArray alloc] initWithCapacity:hashesCount];
    for (NSUInteger i = 0; i < hashesCount; ++i) {
        NSData *hashData = [self.hashesData subdataWithRange:NSMakeRange(i * WSHash256Length, WSHash256Length)];
        [hashes addObject:WSHash256FromData(hashData)];
    }
    
    return [[WSPartialMerkleTree alloc] initWithTxCount:txCount hashes:hashes flags:self.flags error:NULL];
}

@end
