//
//  WSMessage.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 27/06/14.
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

//
// Protocol
//
// https://en.bitcoin.it/wiki/Protocol_specification
//

extern const NSInteger          WSMessageHeaderLength;
extern const NSUInteger         WSMessageMaxLength;
extern const NSUInteger         WSMessageMaxInventories;
extern const NSUInteger         WSMessageAddrMaxCount;
extern const NSUInteger         WSMessageBlocksMaxCount;
extern const NSUInteger         WSMessageHeadersMaxCount;

extern NSString *const          WSMessageType_VERSION;
extern NSString *const          WSMessageType_VERACK;
extern NSString *const          WSMessageType_ADDR;
extern NSString *const          WSMessageType_INV;
extern NSString *const          WSMessageType_GETDATA;
extern NSString *const          WSMessageType_NOTFOUND;
extern NSString *const          WSMessageType_GETBLOCKS;
extern NSString *const          WSMessageType_GETHEADERS;
extern NSString *const          WSMessageType_TX;
extern NSString *const          WSMessageType_BLOCK;
extern NSString *const          WSMessageType_HEADERS;
extern NSString *const          WSMessageType_GETADDR;
extern NSString *const          WSMessageType_MEMPOOL;
extern NSString *const          WSMessageType_CHECKORDER;       // deprecated
extern NSString *const          WSMessageType_SUBMITORDER;      // deprecated
extern NSString *const          WSMessageType_REPLY;            // deprecated
extern NSString *const          WSMessageType_PING;
extern NSString *const          WSMessageType_PONG;
extern NSString *const          WSMessageType_REJECT;           // described in BIP61: https://gist.github.com/gavinandresen/7079034
extern NSString *const          WSMessageType_FILTERLOAD;
extern NSString *const          WSMessageType_FILTERADD;
extern NSString *const          WSMessageType_FILTERCLEAR;
extern NSString *const          WSMessageType_MERKLEBLOCK;
extern NSString *const          WSMessageType_ALERT;

@protocol WSMessage <WSBufferEncoder>

- (WSParameters *)parameters;
- (NSString *)messageType;
- (NSUInteger)originalLength;
- (WSBuffer *)toNetworkBufferWithHeaderLength:(NSUInteger *)headerLength;
- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent;
- (NSUInteger)length;

@end
