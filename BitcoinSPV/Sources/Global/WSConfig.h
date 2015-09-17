//
//  WSConfig.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 13/06/14.
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

//#define BSPV_FEE_PRE_0_9_2_RULES

#define BSPV_WALLET_FILTER_PUBKEYS          1 // bitcoinj approach
#define BSPV_WALLET_FILTER_UNSPENT          2 // BreadWallet approach
#define BSPV_WALLET_FILTER                  BSPV_WALLET_FILTER_UNSPENT

#define BSPV_BIP44_COMPLIANCE               // HD wallet defaults to BIP44 chains

//#define BSPV_TEST_NO_HASH_VALIDATIONS       // skip some checks for testing (e.g. hashed block id, tx id, ...)
//#define BSPV_TEST_MESSAGE_QUEUE             // bufferize received messages for synchronous peer requests
//#define BSPV_TEST_DUMMY_TXS                 // don't check transaction relevancy

#pragma mark - Library

extern NSString *const          WSClientName;
extern NSString *const          WSClientVersion;

NSBundle *WSClientBundle(Class clazz);

#pragma mark - Local parameters

extern const uint32_t           WSSeedGeneratorDefaultEntropyBits;

extern const uint32_t           WSBlockUnknownHeight;
extern const uint32_t           WSBlockUnknownTimestamp;

extern const NSUInteger         WSBlockChainDefaultMaxSize;

extern const NSTimeInterval     WSPeerConnectTimeout;
extern const uint32_t           WSPeerProtocol;
extern const uint32_t           WSPeerMinProtocol;
extern const NSUInteger         WSPeerEnabledServices;
extern const NSUInteger         WSPeerMaxFilteredBlockCount;

extern const NSUInteger         WSPeerGroupDefaultMaxConnections;
extern const NSUInteger         WSPeerGroupDefaultMaxConnectionFailures;
extern const NSTimeInterval     WSPeerGroupDefaultReconnectionDelay;
//extern const NSTimeInterval     WSPeerGroupDefaultPingInterval;
//extern const NSUInteger         WSPeerGroupMaxPeerHours;
extern const NSUInteger         WSPeerGroupMaxInactivePeers;

extern const double             WSBlockChainDownloaderDefaultBFRateMin;
extern const double             WSBlockChainDownloaderDefaultBFRateDelta;
extern const double             WSBlockChainDownloaderDefaultBFObservedRateMax;
extern const double             WSBlockChainDownloaderDefaultBFLowPassRatio;
extern const NSUInteger         WSBlockChainDownloaderDefaultBFTxsPerBlock;
extern const NSTimeInterval     WSBlockChainDownloaderDefaultRequestTimeout;

extern const uint32_t           WSMessageVersionLocalhost;

extern const NSUInteger         WSHDWalletDefaultGapLimit;

extern const NSTimeInterval     WSJSONClientDefaultTimeout;
