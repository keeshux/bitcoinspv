//
//  WSTransactionMetadata.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 27/07/14.
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

#import "WSTransactionMetadata.h"
#import "WSStorableBlock.h"
#import "WSBlockHeader.h"
#import "WSHash256.h"
#import "WSBitcoinConstants.h"
#import "WSConfig.h"
#import "WSErrors.h"

@interface WSTransactionMetadata ()

@property (nonatomic, strong) WSHash256 *parentBlockId;
@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) uint32_t timestamp;

@end

@implementation WSTransactionMetadata

- (instancetype)initWithParentBlock:(WSStorableBlock *)block
{
    WSExceptionCheckIllegal(block);
    WSExceptionCheckIllegal(block.height != WSBlockUnknownHeight);
    
    if ((self = [super init])) {
        self.parentBlockId = block.blockId;
        self.height = block.height;
        self.timestamp = block.header.timestamp;
    }
    return self;
}

- (instancetype)initWithNoParentBlock
{
    if ((self = [super init])) {
        self.parentBlockId = nil;
        self.height = WSBlockUnknownHeight;
        self.timestamp = WSBlockUnknownTimestamp;
    }
    return self;
}

- (NSUInteger)confirmationsAtNetworkHeight:(NSUInteger)networkHeight
{
    if (self.height == WSBlockUnknownHeight) {
        return 0;
    }
#warning XXX: wrong confirmations if transaction in fork block
//    WSExceptionCheckIllegal(networkHeight >= self.height, @"Parent block can never be higher than networkHeight");
    return networkHeight - self.height + 1;
}

- (NSString *)description
{
    if (!self.parentBlockId) {
        return @"<unconfirmed>";
    }
    return [NSString stringWithFormat:@"<#%u, %@>", self.height, self.parentBlockId];
}

@end
