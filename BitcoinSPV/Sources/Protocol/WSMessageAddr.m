//
//  WSMessageAddr.m
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

#import "WSMessageAddr.h"
#import "WSNetworkAddress.h"
#import "WSBuffer.h"
#import "WSBitcoinConstants.h"
#import "WSErrors.h"

@interface WSMessageAddr ()

@property (nonatomic, strong) NSArray *addresses;

- (instancetype)initWithParameters:(WSParameters *)parameters addresses:(NSArray *)addresses;

@end

@implementation WSMessageAddr

+ (instancetype)messageWithParameters:(WSParameters *)parameters addresses:(NSArray *)addresses
{
    return [[self alloc] initWithParameters:parameters addresses:addresses];
}

- (instancetype)initWithParameters:(WSParameters *)parameters addresses:(NSArray *)addresses
{
    WSExceptionCheckIllegal(addresses.count > 0);

    if ((self = [super initWithParameters:parameters])) {
        self.addresses = addresses;
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

    for (WSNetworkAddress *address in self.addresses) {
        [buffer appendNetworkAddress:address];
    }
}

- (WSBuffer *)toBuffer
{
    // var_int + addresses.count * (timestamp + address)
    const NSUInteger addressesCount = self.addresses.count;
    const NSUInteger capacity = WSBufferVarIntSize(addressesCount) + addressesCount * (4 + WSNetworkAddressLength);
    
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:capacity];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithParameters:parameters originalLength:buffer.length])) {
        NSUInteger offset = from;
        NSUInteger varIntLength;

        const NSUInteger count = (NSUInteger)[buffer varIntAtOffset:offset length:&varIntLength];
        if (count > WSMessageAddrMaxCount) {
            WSErrorSet(error, WSErrorCodeMalformed, @"Too many addresses (%u > %u)", count, WSMessageAddrMaxCount);
            return nil;
        }
        offset += varIntLength;
        
        const NSUInteger expectedLength = varIntLength + count * WSNetworkAddressLength;
        if (available < expectedLength) {
            WSErrorSetNotEnoughMessageBytes(error, self.messageType, available, expectedLength);
            return nil;
        }

        NSMutableArray *addresses = [[NSMutableArray alloc] initWithCapacity:count];
        for (NSUInteger i = 0; i < count; ++i) {
            WSNetworkAddress *address = [buffer networkAddressAtOffset:offset];
            offset += WSNetworkAddressLength;

            [addresses addObject:address];
        }
        self.addresses = addresses;
    }
    return self;
}

@end
