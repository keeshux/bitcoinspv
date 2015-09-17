//
//  WSInventory.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 29/06/14.
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

#import "WSInventory.h"
#import "WSHash256.h"
#import "WSBitcoinConstants.h"
#import "WSErrors.h"

@interface WSInventory ()

@property (nonatomic, assign) WSInventoryType inventoryType;
@property (nonatomic, strong) WSHash256 *inventoryHash;

@end

@implementation WSInventory

- (instancetype)initWithType:(WSInventoryType)inventoryType hash:(WSHash256 *)inventoryHash
{
    WSExceptionCheckIllegal(inventoryHash);
    WSExceptionCheckIllegal((inventoryType >= WSInventoryTypeTx) && (inventoryType <= WSInventoryTypeFilteredBlock));

    if ((self = [super init])) {
        self.inventoryType = inventoryType;
        self.inventoryHash = inventoryHash;
    }
    return self;
}

- (NSString *)inventoryTypeString
{
    return  WSInventoryTypeString(self.inventoryType);
}

- (BOOL)isBlockInventory
{
    return ((self.inventoryType == WSInventoryTypeBlock) || (self.inventoryType == WSInventoryTypeFilteredBlock));
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@, %@>", self.inventoryTypeString, self.inventoryHash];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendUint32:self.inventoryType];
    [buffer appendHash256:self.inventoryHash];
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:WSInventoryLength];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if (available < WSInventoryLength) {
        WSErrorSetNotEnoughBytes(error, [self class], available, WSInventoryLength);
        return nil;
    }
    NSUInteger offset = from;

    const WSInventoryType inventoryType = [buffer uint32AtOffset:offset];
    offset += sizeof(uint32_t);

    WSHash256 *inventoryHash = [buffer hash256AtOffset:offset];

    return [self initWithType:inventoryType hash:inventoryHash];
}

@end

#pragma mark -

NSString *WSInventoryTypeString(WSInventoryType inventoryType)
{
    static NSMutableDictionary *names = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        names = [[NSMutableDictionary alloc] init];
        names[@(WSInventoryTypeError)]          = @"error";
        names[@(WSInventoryTypeTx)]             = @"tx";
        names[@(WSInventoryTypeBlock)]          = @"block";
        names[@(WSInventoryTypeFilteredBlock)]  = @"filtered_block";
    });
    
    return (names[@(inventoryType)] ?: @"");
}
