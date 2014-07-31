//
//  WSBitcoin.h
//  WaSPV
//
//  Created by Davide De Rosa on 25/07/14.
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

#import <Foundation/Foundation.h>

//
// https://en.bitcoin.it/wiki/Base58Check#Base58_symbol_chart
//
extern const char               WSBase58Alphabet[];

extern const NSUInteger         WSKeyLength;
extern const uint8_t            WSKeySignaturePrefix;
extern const NSUInteger         WSPublicKeyCompressedLength;
extern const NSUInteger         WSPublicKeyUncompressedLength;

BOOL WSKeyIsValidData(NSData *data);
BOOL WSPublicKeyIsValidData(NSData *data);

extern const NSUInteger         WSHash160Length;
extern const NSUInteger         WSHash256Length;
extern const NSUInteger         WSAddressLength;
extern const NSUInteger         WSNetworkAddressLength;
extern const NSUInteger         WSInventoryLength;

#pragma mark - Scripts

//
// Script
//
// https://en.bitcoin.it/wiki/Script
//

typedef enum {
    WSScriptOpcode_OP_0                 = 0x00,
    WSScriptOpcode_PUSHDATA1            = 0x4c,
    WSScriptOpcode_PUSHDATA2            = 0x4d,
    WSScriptOpcode_PUSHDATA4            = 0x4e,
    WSScriptOpcode_OP_1                 = 0x51,
    WSScriptOpcode_OP_2                 = 0x52,
    WSScriptOpcode_OP_3                 = 0x53,
    WSScriptOpcode_OP_4                 = 0x54,
    WSScriptOpcode_OP_5                 = 0x55,
    WSScriptOpcode_OP_6                 = 0x56,
    WSScriptOpcode_OP_7                 = 0x57,
    WSScriptOpcode_OP_8                 = 0x58,
    WSScriptOpcode_OP_9                 = 0x59,
    WSScriptOpcode_OP_10                = 0x5a,
    WSScriptOpcode_OP_11                = 0x5b,
    WSScriptOpcode_OP_12                = 0x5c,
    WSScriptOpcode_OP_13                = 0x5d,
    WSScriptOpcode_OP_14                = 0x5e,
    WSScriptOpcode_OP_15                = 0x5f,
    WSScriptOpcode_OP_16                = 0x60,
    WSScriptOpcode_OP_RETURN            = 0x6a,
    WSScriptOpcode_DUP                  = 0x76,
    WSScriptOpcode_EQUAL                = 0x87,
    WSScriptOpcode_EQUALVERIFY          = 0x88,
    WSScriptOpcode_HASH160              = 0xa9,
    WSScriptOpcode_CHECKSIG             = 0xac,
    WSScriptOpcode_CHECKSIGVERIFY       = 0xad,
    WSScriptOpcode_CHECKMULTISIG        = 0xae,
    WSScriptOpcode_CHECKMULTISIGVERIFY  = 0xaf
} WSScriptOpcode;

NSString *WSScriptOpcodeString(WSScriptOpcode opcode);
NSUInteger WSScriptOpcodeValue(WSScriptOpcode opcode);

#pragma mark - Blocks

extern const uint32_t           WSBlockUnknownHeight;
extern const NSUInteger         WSBlockHeaderLength;
extern const NSUInteger         WSBlockMaxLength;
extern const NSUInteger         WSFilteredBlockBaseLength;
extern const uint32_t           WSBlockAllowedTimeDrift;

#pragma mark - Transactions

extern const uint32_t           WSTransactionVersion;
extern const uint32_t           WSTransactionDefaultLockTime;
extern const uint32_t           WSTransactionUnconfirmedHeight;
extern const uint32_t           WSTransactionInputDefaultSequence;
extern const uint64_t           WSTransactionSizeUnit;
extern const uint64_t           WSTransactionRelayFeePerUnit;

uint64_t WSTransactionStandardRelayFee(NSUInteger txSize);

extern const NSUInteger         WSTransactionInputTypicalLength;
extern const NSUInteger         WSTransactionOutputTypicalLength;
extern const NSUInteger         WSTransactionOutPointLength;
extern const uint64_t           WSTransactionMinOutValue;
extern const NSUInteger         WSTransactionCoinbaseInputIndex;

extern const uint64_t           WSTransactionMaxSize;
extern const uint64_t           WSTransactionFreeMaxSize;
extern const uint64_t           WSTransactionFreeMinPriority;

NSUInteger WSTransactionTypicalSize(NSUInteger numberOfInputs, NSUInteger numberOfOutputs);

typedef enum {
    WSTransactionSigHash_ALL            = 0x00000001U
} WSTransactionSigHash;

#pragma mark - Protocol

//
// Protocol
//
// https://en.bitcoin.it/wiki/Protocol_specification
//

extern const NSInteger          WSMessageHeaderLength;
extern const NSUInteger         WSMessageMaxLength;
extern const NSUInteger         WSMessageMaxInventories;
extern const uint8_t            WSMessageVarInt16Header;
extern const uint8_t            WSMessageVarInt32Header;
extern const uint8_t            WSMessageVarInt64Header;
extern NSUInteger               WSMessageVarIntSize(uint64_t i);

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

typedef enum {
    WSInventoryTypeError = 0,
    WSInventoryTypeTx,
    WSInventoryTypeBlock,
    WSInventoryTypeFilteredBlock
} WSInventoryType;

NSString *WSInventoryTypeString(WSInventoryType inventoryType);

typedef enum {
    WSPeerServicesNodeNetwork = 0x1     // indicates a node offers full blocks, not just headers
} WSPeerServices;

extern const NSUInteger         WSMessageAddrMaxCount;
extern const NSUInteger         WSMessageBlocksMaxCount;
extern const NSUInteger         WSMessageHeadersMaxCount;

#pragma mark - BIP32

//
// HD wallets
//
// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
//

extern const char *             WSBIP32InitSeed;
extern const uint32_t           WSBIP32HardenedMask;
extern const NSUInteger         WSBIP32KeyLength;
extern NSString *const          WSBIP32PathValidityRegex;

static inline uint32_t WSBIP32ChildIndex(uint32_t child)
{
    return (child & ~WSBIP32HardenedMask);
}

static inline BOOL WSBIP32ChildIsHardened(uint32_t child)
{
    return ((child & WSBIP32HardenedMask) != 0);
}

#pragma mark - BIP37

//
// Bloom filtering
//
// https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki
//

extern const uint32_t           WSBIP37MaxFilterLength;
extern const uint32_t           WSBIP37MaxHashFunctions;
extern const uint32_t           WSBIP37HashMultiplier;

typedef enum {
    WSBIP37FlagsUpdateNone = 0,
    WSBIP37FlagsUpdateAll,
    WSBIP37FlagsUpdateP2PubKeyOnly
} WSBIP37Flags;

#pragma mark - BIP39

//
// Mnemonic code for HD wallets
//
// https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
//

extern NSString *const          WSBIP39WordsResource;
extern NSString *const          WSBIP39WordsType;
extern const CFStringRef        WSBIP39SaltPrefix;
