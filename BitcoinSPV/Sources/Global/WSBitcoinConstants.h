//
//  WSBitcoinConstants.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 25/07/14.
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

#define WSDatesOneMinute        (60)
#define WSDatesOneHour          (60 * WSDatesOneMinute)
#define WSDatesOneDay           (24 * WSDatesOneHour)
#define WSDatesOneWeek          (7 * WSDatesOneDay)

//
// https://en.bitcoin.it/wiki/Base58Check#Base58_symbol_chart
//
extern const char               WSBase58Alphabet[];

extern const NSUInteger         WSKeyLength;
extern const NSUInteger         WSKeyEncodedUncompressedLength;
extern const NSUInteger         WSKeyEncodedCompressedLength;
extern const uint8_t            WSKeySignaturePrefix;
extern const NSUInteger         WSPublicKeyUncompressedLength;
extern const NSUInteger         WSPublicKeyCompressedLength;

extern const NSUInteger         WSHash160Length;
extern const NSUInteger         WSHash256Length;
extern const NSUInteger         WSAddressLength;
extern const NSUInteger         WSNetworkAddressLength;
extern const NSUInteger         WSNetworkAddressLegacyLength;
extern const NSUInteger         WSInventoryLength;

#pragma mark - Blocks

extern const uint32_t           WSBlockUnknownHeight;
extern const NSUInteger         WSBlockHeaderSize;
extern const NSUInteger         WSBlockMaxSize;
extern const NSUInteger         WSFilteredBlockBaseSize;
extern const uint32_t           WSBlockAllowedTimeDrift;

#pragma mark - Transactions

extern const uint32_t           WSTransactionVersion;
extern const uint32_t           WSTransactionDefaultLockTime;
extern const uint32_t           WSTransactionUnconfirmedHeight;
extern const uint32_t           WSTransactionInputDefaultSequence;
extern const uint64_t           WSTransactionSizeUnit;
extern const uint64_t           WSTransactionRelayFeePerUnit;

uint64_t WSTransactionStandardRelayFee(NSUInteger txSize);

extern const NSUInteger         WSTransactionInputTypicalSize;
extern const NSUInteger         WSTransactionOutputTypicalSize;
extern const NSUInteger         WSTransactionOutPointSize;
extern const uint64_t           WSTransactionMinOutValue;
extern const NSUInteger         WSTransactionCoinbaseInputIndex;

extern const NSUInteger         WSTransactionMaxSize;
extern const NSUInteger         WSTransactionFreeMaxSize;
extern const NSUInteger         WSTransactionFreeMinPriority;

NSUInteger WSTransactionTypicalSize(NSUInteger numberOfInputs, NSUInteger numberOfOutputs);
NSUInteger WSTransactionEstimatedSize(NSOrderedSet *inputs, NSOrderedSet *outputs, NSArray *extraInputs, NSArray *extraOutputs, BOOL simulatingSignatures);

typedef enum {
    WSTransactionSigHash_ALL            = 0x00000001U
} WSTransactionSigHash;
