//
//  WSNetworkAddress.m
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

#import "WSNetworkAddress.h"

@interface WSNetworkAddress ()

@property (nonatomic, assign) uint64_t services;
@property (nonatomic, strong) NSData *ipv6Address;
@property (nonatomic, assign) uint32_t ipv4Address;
@property (nonatomic, assign) uint16_t port;

@property (nonatomic, strong) NSString *host;

@end

@implementation WSNetworkAddress

- (instancetype)initWithServices:(uint64_t)services ipv6Address:(NSData *)ipv6Address port:(uint16_t)port
{
    WSExceptionCheckIllegal(ipv6Address.length == 16, @"ipv6Address must be 16 bytes long");
    
    if ((self = [super init])) {
        self.services = services;
        self.ipv6Address = ipv6Address;
        self.ipv4Address = WSNetworkIPv4FromIPv6(ipv6Address);
        self.port = port;
    }
    return self;
}

- (instancetype)initWithServices:(uint64_t)services ipv4Address:(uint32_t)ipv4Address port:(uint16_t)port
{
    if ((self = [super init])) {
        self.services = services;
        self.ipv6Address = WSNetworkIPv6FromIPv4(ipv4Address);
        self.ipv4Address = ipv4Address;
        self.port = port;
    }
    return self;
}

- (NSString *)host
{
    if (!_host) {
        if (self.ipv4Address > 0) {
            _host = WSNetworkHostFromUint32(self.ipv4Address);
        }
        else {
            NSString *hexAddress = [self.ipv6Address hexString];
            NSMutableArray *groups = [[NSMutableArray alloc] initWithCapacity:4];
            for (NSUInteger i = 0; i < 32; i += 4) {
                [groups addObject:[hexAddress substringWithRange:NSMakeRange(i, 4)]];
            }
            _host = [groups componentsJoinedByString:@":"];
        }
    }
    return _host;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@:%u", self.host, self.port];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    const uint16_t networkPort = CFSwapInt16HostToBig(self.port);
    
    [buffer appendUint64:self.services];
    [buffer appendData:self.ipv6Address];
    [buffer appendBytes:&networkPort length:sizeof(networkPort)];
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:WSNetworkAddressLength];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithBuffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if (available < WSNetworkAddressLength) {
        WSErrorSetNotEnoughBytes(error, [self class], available, WSNetworkAddressLength);
        return nil;
    }

    NSUInteger offset = from;

    const uint64_t services = CFSwapInt64LittleToHost([buffer uint64AtOffset:offset]);
    offset += sizeof(uint64_t);

    NSData *ipv6Address = [buffer dataAtOffset:offset length:16];
    offset += 16;

    const uint16_t port = CFSwapInt16BigToHost([buffer uint16AtOffset:offset]);

    return [self initWithServices:services ipv6Address:ipv6Address port:port];
}

@end
