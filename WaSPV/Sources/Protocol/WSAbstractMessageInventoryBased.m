//
//  WSAbstractMessageInventoryBased.m
//  WaSPV
//
//  Created by Davide De Rosa on 06/07/14.
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

#import "WSAbstractMessageInventoryBased.h"
#import "WSBitcoin.h"
#import "WSErrors.h"

@interface WSAbstractMessageInventoryBased ()

@property (nonatomic, strong) NSArray *inventories;

- (instancetype)initWithInventories:(NSArray *)inventories;

@end

@implementation WSAbstractMessageInventoryBased

+ (instancetype)messageWithInventories:(NSArray *)inventories
{
    return [[self alloc] initWithInventories:inventories];
}

- (instancetype)initWithInventories:(NSArray *)inventories
{
    WSExceptionCheckIllegal(inventories.count > 0, @"Empty inventories");
    WSExceptionCheckIllegal(inventories.count <= WSMessageMaxInventories, @"Too many inventories (%u > %u)", inventories.count, WSMessageMaxInventories);
    
    if ((self = [super init])) {
        self.inventories = inventories;
    }
    return self;
}

#pragma mark WSMessage

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    return [self.inventories descriptionWithLocale:nil indent:indent];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendVarInt:self.inventories.count];
    for (WSInventory *inventory in self.inventories) {
        [buffer appendInventory:inventory];
    }
}

- (WSBuffer *)toBuffer
{
    // var_int + inventories.count * inventory
    const NSUInteger capacity = 8 + self.inventories.count * WSInventoryLength;
    
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:capacity];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(id<WSParameters>)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithParameters:parameters originalPayload:buffer])) {
        NSUInteger offset = from;
        NSUInteger varIntLength;
        
        const NSUInteger count = (NSUInteger)[buffer varIntAtOffset:offset length:&varIntLength];
        if (count > WSMessageMaxInventories) {
            WSErrorSet(error, WSErrorCodeMalformed, @"Too many inventories in '%@' message (%u > %u)", self.messageType, count, WSMessageMaxInventories);
            return nil;
        }
        offset += varIntLength;
        
        const NSUInteger expectedLength = varIntLength + count * WSInventoryLength;
        if (available < expectedLength) {
            WSErrorSetNotEnoughMessageBytes(error, self.messageType, available, expectedLength);
            return nil;
        }
        
        NSMutableArray *inventories = [[NSMutableArray alloc] initWithCapacity:count];
        for (NSUInteger i = 0; i < count; ++i) {
            [inventories addObject:[buffer inventoryAtOffset:offset]];
            offset += WSInventoryLength;
        }
        self.inventories = inventories;
    }
    return self;
}

@end
