//
//  WSMessageVersion.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 26/06/14.
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

#import "WSAbstractMessage.h"

@class WSNetworkAddress;

@interface WSMessageVersion : WSAbstractMessage <WSBufferDecoder>

+ (instancetype)messageWithParameters:(WSParameters *)parameters
                              version:(uint32_t)version
                             services:(uint64_t)services
                 remoteNetworkAddress:(WSNetworkAddress *)remoteNetworkAddress
                            localPort:(uint16_t)localPort
                    relayTransactions:(uint8_t)relayTransactions;

- (uint32_t)version;
- (uint64_t)services;
- (uint64_t)timestamp; // UNIX timestamp in seconds
- (WSNetworkAddress *)remoteNetworkAddress;
- (WSNetworkAddress *)localNetworkAddress;
- (uint64_t)nonce;
- (NSString *)userAgent;
- (uint32_t)lastBlockHeight;
- (uint8_t)relayTransactions;

@end
