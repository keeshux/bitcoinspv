//
//  WSMessage.m
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

#import "WSMessage.h"

const NSInteger         WSMessageHeaderLength                   = 24;
const NSUInteger        WSMessageMaxLength                      = 0x02000000;
const NSUInteger        WSMessageMaxInventories                 = 50000;
const NSUInteger        WSMessageAddrMaxCount                   = 1000;
const NSUInteger        WSMessageBlocksMaxCount                 = 500;
const NSUInteger        WSMessageHeadersMaxCount                = 2000;

NSString *const         WSMessageType_VERSION                   = @"version";
NSString *const         WSMessageType_VERACK                    = @"verack";
NSString *const         WSMessageType_ADDR                      = @"addr";
NSString *const         WSMessageType_INV                       = @"inv";
NSString *const         WSMessageType_GETDATA                   = @"getdata";
NSString *const         WSMessageType_NOTFOUND                  = @"notfound";
NSString *const         WSMessageType_GETBLOCKS                 = @"getblocks";
NSString *const         WSMessageType_GETHEADERS                = @"getheaders";
NSString *const         WSMessageType_TX                        = @"tx";
NSString *const         WSMessageType_BLOCK                     = @"block";
NSString *const         WSMessageType_HEADERS                   = @"headers";
NSString *const         WSMessageType_GETADDR                   = @"getaddr";
NSString *const         WSMessageType_MEMPOOL                   = @"mempool";
NSString *const         WSMessageType_CHECKORDER                = @"checkorder";
NSString *const         WSMessageType_SUBMITORDER               = @"submitorder";
NSString *const         WSMessageType_REPLY                     = @"reply";
NSString *const         WSMessageType_PING                      = @"ping";
NSString *const         WSMessageType_PONG                      = @"pong";
NSString *const         WSMessageType_REJECT                    = @"reject";
NSString *const         WSMessageType_FILTERLOAD                = @"filterload";
NSString *const         WSMessageType_FILTERADD                 = @"filteradd";
NSString *const         WSMessageType_FILTERCLEAR               = @"filterclear";
NSString *const         WSMessageType_MERKLEBLOCK               = @"merkleblock";
NSString *const         WSMessageType_ALERT                     = @"alert";
