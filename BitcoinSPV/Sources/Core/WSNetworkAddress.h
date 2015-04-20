//
//  WSNetworkAddress.h
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

#import <Foundation/Foundation.h>

#import "WSBuffer.h"

@interface WSNetworkAddress : NSObject <WSBufferEncoder, WSBufferDecoder>

- (instancetype)initWithTimestamp:(uint32_t)timestamp services:(uint64_t)services ipv6Address:(NSData *)ipv6Address port:(uint16_t)port;
- (instancetype)initWithTimestamp:(uint32_t)timestamp services:(uint64_t)services ipv4Address:(uint32_t)ipv4Address port:(uint16_t)port;
- (uint32_t)timestamp;
- (uint64_t)services;
- (NSData *)ipv6Address;
- (uint32_t)ipv4Address;
- (uint16_t)port;
- (NSString *)host;

@end
