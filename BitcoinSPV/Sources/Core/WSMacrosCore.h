//
//  WSMacrosCore.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 04/07/14.
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

#pragma mark - Utils

static inline NSString *WSStringOptionalEx(BOOL condition, id object, NSString *format)
{
    return (condition ? [NSString stringWithFormat:format, object] : @"");
}

static inline NSString *WSStringOptional(id object, NSString *format)
{
    return WSStringOptionalEx(object != nil, object, format);
}

NSString *WSStringDescriptionFromTokens(NSArray *tokens, NSUInteger indent);

static inline BOOL WSUtilsCheckBit(const uint8_t *data, NSUInteger i)
{
    static const uint8_t bitMask[] = {
        0x01,
        0x02,
        0x04,
        0x08,
        0x10,
        0x20,
        0x40,
        0x80
    };
    return ((data[i >> 3] & bitMask[7 & i]) != 0);
}

static inline double WSUtilsProgress(const uint32_t from, const uint32_t to, const uint32_t current)
{
    return ((current >= to) ? 1.0 : ((double)(current - from) / (to - from)));
}

#pragma mark - Shortcuts

#import <arpa/inet.h>

#import "WSParameters.h"

@class WSHash256;
@class WSHash160;
@class WSBuffer;
@class WSMutableBuffer;
@class WSKey;
@class WSPublicKey;
@class WSAddress;
@class WSBlockHeader;
@class WSBlock;
@class WSPartialMerkleTree;
@class WSFilteredBlock;
@class WSInventory;
@class WSNetworkAddress;
@class WSSeed;
@class WSScript;
@class WSCoinbaseScript;
@class WSSignedTransaction;
@class WSBIP21URL;
@class WSBIP38Key;

WSParameters *WSParametersForNetworkType(WSNetworkType networkType);

WSHash256 *WSHash256Compute(NSData *sourceData);
WSHash256 *WSHash256FromHex(NSString *hexString);
WSHash256 *WSHash256FromData(NSData *data);
WSHash256 *WSHash256Zero();

WSHash160 *WSHash160Compute(NSData *sourceData);
WSHash160 *WSHash160FromHex(NSString *hexString);
WSHash160 *WSHash160FromData(NSData *data);

WSBuffer *WSBufferFromHex(NSString *hex);
WSMutableBuffer *WSMutableBufferFromHex(NSString *hex);

WSKey *WSKeyFromHex(NSString *hex);
WSKey *WSKeyFromWIF(WSParameters *parameters, NSString *wif);
WSPublicKey *WSPublicKeyFromHex(NSString *hex);

WSAddress *WSAddressFromString(WSParameters *parameters, NSString *string);
WSAddress *WSAddressFromHex(WSParameters *parameters, NSString *hexString);
WSAddress *WSAddressP2PKHFromHash160(WSParameters *parameters, WSHash160 *hash160);
WSAddress *WSAddressP2SHFromHash160(WSParameters *parameters, WSHash160 *hash160);

WSBlockHeader *WSBlockHeaderFromHex(WSParameters *parameters, NSString *hex);
WSBlock *WSBlockFromHex(WSParameters *parameters, NSString *hex);
WSPartialMerkleTree *WSPartialMerkleTreeFromHex(NSString *hex);
WSFilteredBlock *WSFilteredBlockFromHex(WSParameters *parameters, NSString *hex);

WSInventory *WSInventoryTx(WSHash256 *hash);
WSInventory *WSInventoryTxFromHex(NSString *hex);
WSInventory *WSInventoryBlock(WSHash256 *hash);
WSInventory *WSInventoryBlockFromHex(NSString *hex);
WSInventory *WSInventoryFilteredBlock(WSHash256 *hash);
WSInventory *WSInventoryFilteredBlockFromHex(NSString *hex);

WSNetworkAddress *WSNetworkAddressMake(uint32_t address, uint16_t port, uint64_t services, uint32_t timestamp);

WSSeed *WSSeedMake(NSString *mnemonic, NSTimeInterval creationTime);
WSSeed *WSSeedMakeUnknown(NSString *mnemonic);
WSSeed *WSSeedMakeNow(NSString *mnemonic);
WSSeed *WSSeedMakeFromDate(NSString *mnemonic, NSDate *date);
WSSeed *WSSeedMakeFromISODate(NSString *mnemonic, NSString *iso); // yyyy-MM-dd

NSString *WSNetworkHostFromIPv4(uint32_t ipv4);
uint32_t WSNetworkIPv4FromHost(NSString *host);
NSString *WSNetworkHostFromIPv6(NSData *ipv6);
NSData *WSNetworkIPv6FromHost(NSString *host);

NSData *WSNetworkIPv6FromIPv4(uint32_t ipv4);
uint32_t WSNetworkIPv4FromIPv6(NSData *ipv6);

WSScript *WSScriptFromHex(NSString *hex);
WSCoinbaseScript *WSCoinbaseScriptFromHex(NSString *hex);
WSSignedTransaction *WSTransactionFromHex(WSParameters *parameters, NSString *hex);

WSBIP21URL *WSBIP21URLFromString(WSParameters *parameters, NSString *string);
WSBIP38Key *WSBIP38KeyFromString(NSString *string);

NSString *WSCurrentQueueLabel();
uint32_t WSCurrentTimestamp();
void WSTimestampSetCurrent(uint32_t timestamp);
void WSTimestampUnsetCurrent();
uint32_t WSTimestampFromISODate(NSString *iso); // yyyy-MM-dd
