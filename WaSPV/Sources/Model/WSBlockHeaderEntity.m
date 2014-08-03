//
//  WSBlockHeaderEntity.m
//  WaSPV
//
//  Created by Davide De Rosa on 12/07/14.
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

#import "WSMacros.h"

#import "WSBlockHeaderEntity.h"
#import "WSStorableBlockEntity.h"
#import "WSHash256.h"

@implementation WSBlockHeaderEntity

@dynamic version;
@dynamic blockIdData;
@dynamic previousBlockIdData;
@dynamic merkleRootData;
@dynamic timestamp;
@dynamic bits;
@dynamic nonce;
@dynamic block;

- (void)copyFromBlockHeader:(WSBlockHeader *)header
{
    self.version = @(header.version);
    self.blockIdData = [header.blockId.data copy];
    self.previousBlockIdData = [header.previousBlockId.data copy];
    if (header.merkleRoot) {
        self.merkleRootData = [header.merkleRoot.data copy];
    }
    self.timestamp = @(header.timestamp);
    self.bits = @(header.bits);
    self.nonce = @(header.nonce);
}

- (WSBlockHeader *)toBlockHeader
{
    const uint32_t version = (uint32_t)[self.version unsignedIntegerValue];
    WSHash256 *previousBlockId = WSHash256FromData(self.previousBlockIdData);
    WSHash256 *merkleRoot = nil;
    if (self.merkleRootData) {
        merkleRoot = WSHash256FromData(self.merkleRootData);
    }
    const uint32_t timestamp = (uint32_t)[self.timestamp unsignedIntegerValue];
    const uint32_t bits = (uint32_t)[self.bits unsignedIntegerValue];
    const uint32_t nonce = (uint32_t)[self.nonce unsignedIntegerValue];

    WSBlockHeader *header = [[WSBlockHeader alloc] initWithVersion:version
                                                   previousBlockId:previousBlockId
                                                        merkleRoot:merkleRoot
                                                         timestamp:timestamp
                                                              bits:bits
                                                             nonce:nonce];

    WSHash256 *expectedBlockId = WSHash256FromData(self.blockIdData);

#ifdef WASPV_TEST_NO_HASH_VALIDATIONS
    [header setValue:expectedBlockId forKey:@"blockId"];
#else
    
#warning XXX: header from WSCheckpoint (remove class ASAP) have no blockId, fix manually
    if (!header.blockId) {
        [header setValue:expectedBlockId forKey:@"blockId"];
    }

    NSAssert([header.blockId isEqual:expectedBlockId], @"Corrupted id while deserializing WSBlockHeader (%@ != %@): %@",
             header.blockId, expectedBlockId, [[header toBuffer] hexString]);
#endif
    
    return header;
}

@end
