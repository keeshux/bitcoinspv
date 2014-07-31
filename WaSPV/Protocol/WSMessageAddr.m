//
//  WSMessageAddr.m
//  WaSPV
//
//  Created by Davide De Rosa on 29/06/14.
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

#import "WSMessageAddr.h"
#import "WSNetworkAddress.h"

@interface WSMessageAddr ()

@property (nonatomic, strong) NSArray *addresses;
@property (nonatomic, strong) NSArray *timestamps;

- (instancetype)initWithAddresses:(NSArray *)addresses timestamps:(NSArray *)timestamps;

@end

@implementation WSMessageAddr

+ (instancetype)messageWithAddresses:(NSArray *)addresses timestamps:(NSArray *)timestamps
{
    return [[self alloc] initWithAddresses:addresses timestamps:timestamps];
}

- (instancetype)initWithAddresses:(NSArray *)addresses timestamps:(NSArray *)timestamps
{
    WSExceptionCheckIllegal((addresses.count > 0) && (timestamps.count > 0), @"Empty addresses or timestamps");
    WSExceptionCheckIllegal(addresses.count == timestamps.count, @"Addresses count and timestamps count do not match");

    if ((self = [super init])) {
        self.addresses = addresses;
        self.timestamps = timestamps;
    }
    return self;
}

#pragma mark WSMessage

- (NSString *)messageType
{
    return WSMessageType_ADDR;
}

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    return [self.addresses descriptionWithLocale:nil indent:indent];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendVarInt:self.addresses.count];

    NSUInteger i = 0;
    for (WSNetworkAddress *address in self.addresses) {
        const uint32_t timestamp = [self.timestamps[i] unsignedIntegerValue];
        [buffer appendUint32:timestamp];
        [buffer appendNetworkAddress:address];
        ++i;
    }
}

- (WSBuffer *)toBuffer
{
    // var_int + addresses.count * (timestamp + address)
    const NSUInteger addressesCount = self.addresses.count;
    const NSUInteger capacity = WSMessageVarIntSize(addressesCount) + addressesCount * (4 + WSNetworkAddressLength);
    
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:capacity];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithBuffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithOriginalPayload:buffer])) {
        NSUInteger offset = from;
        NSUInteger varIntLength;

        const NSUInteger count = (NSUInteger)[buffer varIntAtOffset:offset length:&varIntLength];
        if (count > WSMessageAddrMaxCount) {
            WSErrorSet(error, WSErrorCodeMalformed, @"Too many addresses (%u > %u)", count, WSMessageAddrMaxCount);
            return nil;
        }
        offset += varIntLength;
        
        const NSUInteger expectedLength = varIntLength + count * (sizeof(uint32_t) + WSNetworkAddressLength);
        if (available < expectedLength) {
            WSErrorSetNotEnoughMessageBytes(error, self.messageType, available, expectedLength);
            return nil;
        }

        NSMutableArray *addresses = [[NSMutableArray alloc] initWithCapacity:count];
        NSMutableArray *timestamps = [[NSMutableArray alloc] initWithCapacity:count];
        for (NSUInteger i = 0; i < count; ++i) {
            const uint32_t timestamp = [buffer uint32AtOffset:offset];
            offset += sizeof(uint32_t);

            WSNetworkAddress *address = [buffer networkAddressAtOffset:offset];
            offset += WSNetworkAddressLength;

            [addresses addObject:address];
            [timestamps addObject:@(timestamp)];
        }
        self.addresses = addresses;
        self.timestamps = timestamps;
    }
    return self;
}

@end
