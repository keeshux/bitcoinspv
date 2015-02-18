//
//  WSConfig.h
//  WaSPV
//
//  Created by Davide De Rosa on 13/06/14.
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

//#define WASPV_FEE_PRE_0_9_2_RULES

#define WASPV_WALLET_FILTER_PUBKEYS         1 // bitcoinj approach
#define WASPV_WALLET_FILTER_UNSPENT         2 // BreadWallet approach
#define WASPV_WALLET_FILTER                 WASPV_WALLET_FILTER_UNSPENT

//#define WASPV_TEST_NO_HASH_VALIDATIONS    // skip some checks for testing (e.g. hashed block id, tx id, ...)
#define WASPV_TEST_MESSAGE_QUEUE          // bufferize received messages for synchronous peer requests
//#define WASPV_TEST_DUMMY_TXS              // don't check transaction relevancy

#pragma mark - Library

extern NSString *const          WSClientName;
extern NSString *const          WSClientVersion;

NSBundle *WSClientBundle(Class clazz);

#pragma mark - Local parameters

extern const uint32_t           WSSeedGeneratorDefaultEntropyBits;

extern const uint32_t           WSBlockUnknownHeight;
extern const uint32_t           WSBlockUnknownTimestamp;

extern const NSTimeInterval     WSPeerConnectTimeout;
extern const NSTimeInterval     WSPeerWriteTimeout;
extern const uint32_t           WSPeerProtocol;
extern const uint32_t           WSPeerMinProtocol;
extern const NSUInteger         WSPeerEnabledServices;
extern const NSUInteger         WSPeerMaxFilteredBlockCount;

extern const NSUInteger         WSPeerGroupDefaultMaxConnections;
extern const NSUInteger         WSPeerGroupDefaultMaxConnectionFailures;
extern const NSTimeInterval     WSPeerGroupDefaultReconnectionDelay;
//extern const NSTimeInterval     WSPeerGroupDefaultPingInterval;
extern const NSTimeInterval     WSPeerGroupDefaultRequestTimeout;
extern const NSUInteger         WSPeerGroupMaxConnectionsMultiplier;

extern const double             WSPeerGroupDefaultBFRateMin;
extern const double             WSPeerGroupDefaultBFRateDelta;
extern const double             WSPeerGroupDefaultBFObservedRateMax;
extern const double             WSPeerGroupDefaultBFLowPassRatio;
extern const NSUInteger         WSPeerGroupDefaultBFTxsPerBlock;

extern const uint32_t           WSMessageVersionLocalhost;

extern const NSUInteger         WSHDWalletDefaultGapLimit;

extern const NSTimeInterval     WSJSONClientDefaultTimeout;
