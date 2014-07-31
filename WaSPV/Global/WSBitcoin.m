//
//  WSBitcoin.m
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

#import "WSBitcoin.h"

//
// https://en.bitcoin.it/wiki/Base58Check#Base58_symbol_chart
//
const char              WSBase58Alphabet[]                      = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

const NSUInteger        WSKeyLength                             = 32;
const uint8_t           WSKeySignaturePrefix                    = 0x30;
const NSUInteger        WSPublicKeyCompressedLength             = 33;
const NSUInteger        WSPublicKeyUncompressedLength           = 65;

BOOL WSKeyIsValidData(NSData *data)
{
    return (data.length == WSKeyLength);
}

BOOL WSPublicKeyIsValidData(NSData *data)
{
    return ((data.length == WSPublicKeyCompressedLength) ||
            (data.length == WSPublicKeyUncompressedLength));
}

const NSUInteger        WSHash160Length                         = 160 / 8; // 20
const NSUInteger        WSHash256Length                         = 256 / 8; // 32
const NSUInteger        WSAddressLength                         = 1 + WSHash160Length; // 1-byte version prefix
const NSUInteger        WSNetworkAddressLength                  = 26;
const NSUInteger        WSInventoryLength                       = 36;

#pragma mark - Scripts

NSString *WSScriptOpcodeString(WSScriptOpcode opcode)
{
    static NSMutableDictionary *names = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        names = [[NSMutableDictionary alloc] init];
        names[@(WSScriptOpcode_OP_0)]               	= @"OP_0";
        //        names[@(WSScriptOpcode_PUSHDATA1)]              = @"OP_PUSHDATA1";
        //        names[@(WSScriptOpcode_PUSHDATA2)]              = @"OP_PUSHDATA2";
        //        names[@(WSScriptOpcode_PUSHDATA4)]              = @"OP_PUSHDATA4";
        for (int numberOpcode = WSScriptOpcode_OP_1; numberOpcode <= WSScriptOpcode_OP_16; ++numberOpcode) {
            names[@(numberOpcode)] = [NSString stringWithFormat:@"OP_%u", WSScriptOpcodeValue(numberOpcode)];
        }
        names[@(WSScriptOpcode_OP_RETURN)]              = @"RETURN";
        names[@(WSScriptOpcode_DUP)]                    = @"DUP";
        names[@(WSScriptOpcode_EQUAL)]                  = @"EQUAL";
        names[@(WSScriptOpcode_EQUALVERIFY)]            = @"EQUALVERIFY";
        names[@(WSScriptOpcode_HASH160)]                = @"HASH160";
        names[@(WSScriptOpcode_CHECKSIG)]               = @"CHECKSIG";
        names[@(WSScriptOpcode_CHECKSIGVERIFY)]         = @"CHECKSIGVERIFY";
        names[@(WSScriptOpcode_CHECKMULTISIG)]          = @"CHECKMULTISIG";
        names[@(WSScriptOpcode_CHECKMULTISIGVERIFY)]    = @"CHECKMULTISIGVERIFY";
    });

    return names[@(opcode)] ?: [NSString stringWithFormat:@"OP_?(%X)", opcode];
}

NSUInteger WSScriptOpcodeValue(WSScriptOpcode opcode)
{
    NSCAssert(((opcode >= WSScriptOpcode_OP_1) && (opcode <= WSScriptOpcode_OP_16)),
              @"Not an OP_1-16 opcode (%x)", opcode);

    return (opcode - WSScriptOpcode_OP_1 + 1);
}

#pragma mark - Blocks

const NSUInteger        WSBlockHeaderLength                     = 81;
const NSUInteger        WSBlockMaxLength                        = 1 * 1000 * 1000;
const NSUInteger        WSFilteredBlockBaseLength               = (WSBlockHeaderLength - 1 + 4);
const uint32_t          WSBlockAllowedTimeDrift                 = 2 * WSDatesOneHour;   // the furthest in the future a block is allowed to be timestamped

#pragma mark - Transactions

const uint32_t          WSTransactionVersion                    = 0x00000001;
const uint32_t          WSTransactionDefaultLockTime            = 0x00000000;
const uint32_t          WSTransactionInputDefaultSequence       = UINT32_MAX;
const uint64_t          WSTransactionSizeUnit                   = 1000;         // tx size unit is 1000 bytes

#ifdef WASPV_FEE_PRE_0_9_2_RULES
const uint64_t          WSTransactionRelayFeePerUnit            = 10000;    // standard tx fee per unit of tx size, rounded up to nearest kb (pre-0.9.2 rules)
#else
const uint64_t          WSTransactionRelayFeePerUnit            = 1000;     // standard tx fee per unit of tx size, rounded up to nearest kb (lowered due to exchange rates as of 02/2014)
#endif

uint64_t WSTransactionStandardRelayFee(NSUInteger txSize)
{
    return ((txSize + WSTransactionSizeUnit - 1) / WSTransactionSizeUnit) * WSTransactionRelayFeePerUnit;
}

//
// Taken from: https://github.com/bitcoin/bitcoin/blob/master/src/core.h
//
// "Dust" is defined in terms of CTransaction::minRelayTxFee,
// which has units satoshis-per-kilobyte.
// If you'd pay more than 1/3 in fees
// to spend something, then we consider it dust.
// A typical txout is 34 bytes big, and will
// need a CTxIn of at least 148 bytes to spend:
// so dust is a txout less than 546 satoshis
// with default minRelayTxFee.
//
const NSUInteger        WSTransactionInputTypicalLength         = 148;
const NSUInteger        WSTransactionOutputTypicalLength        = 34;
const NSUInteger        WSTransactionOutPointLength             = 36;
const uint64_t          WSTransactionMinOutValue                = WSTransactionRelayFeePerUnit * 3 * (WSTransactionInputTypicalLength + WSTransactionOutputTypicalLength) / WSTransactionSizeUnit; // no txout can be below this amount (or it won't relay)
const NSUInteger        WSTransactionCoinbaseInputIndex         = 0xffffffff;

const uint64_t          WSTransactionMaxSize                    = 100000;   // no tx can be larger than this size in bytes
const uint64_t          WSTransactionFreeMaxSize                = 1000;     // tx must not be larger than this size in bytes without a fee
const uint64_t          WSTransactionFreeMinPriority            = 57600000; // tx must not have a priority below this value without a fee

NSUInteger WSTransactionTypicalSize(NSUInteger numberOfInputs, NSUInteger numberOfOutputs)
{
    // version + locktime + ins/outs
    return (8 + numberOfInputs * WSTransactionInputTypicalLength + numberOfOutputs * WSTransactionOutputTypicalLength);
}

#pragma mark - Protocol

//
// Protocol
//
// https://en.bitcoin.it/wiki/Protocol_specification
//

const NSInteger         WSMessageHeaderLength                   = 24;
const NSUInteger        WSMessageMaxLength                      = 0x02000000;
const NSUInteger        WSMessageMaxInventories                 = 50000;
const uint8_t           WSMessageVarInt16Header                 = 0xfd;
const uint8_t           WSMessageVarInt32Header                 = 0xfe;
const uint8_t           WSMessageVarInt64Header                 = 0xff;

NSUInteger WSMessageVarIntSize(uint64_t i)
{
    if (i < WSMessageVarInt16Header) {
        return sizeof(uint8_t);
    }
    else if (i <= UINT16_MAX) {
        return sizeof(uint8_t) + sizeof(uint16_t);
    }
    else if (i <= UINT32_MAX) {
        return sizeof(uint8_t) + sizeof(uint32_t);
    }
    else {
        return sizeof(uint8_t) + sizeof(uint64_t);
    }
}

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

NSString *WSInventoryTypeString(WSInventoryType inventoryType)
{
    static NSMutableDictionary *names = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        names = [[NSMutableDictionary alloc] init];
        names[@(WSInventoryTypeError)]          = @"error";
        names[@(WSInventoryTypeTx)]             = @"tx";
        names[@(WSInventoryTypeBlock)]          = @"block";
        names[@(WSInventoryTypeFilteredBlock)]  = @"filtered_block";
    });

    return (names[@(inventoryType)] ?: @"");
}

const NSUInteger        WSMessageAddrMaxCount                   = 1000;
const NSUInteger        WSMessageBlocksMaxCount                 = 500;
const NSUInteger        WSMessageHeadersMaxCount                = 2000;

#pragma mark - BIP32

//
// HD wallets
//
// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
//

const char *            WSBIP32InitSeed                         = "Bitcoin seed";
const uint32_t          WSBIP32HardenedMask                     = 0x80000000;
const NSUInteger        WSBIP32KeyLength                        = 78;
NSString *const         WSBIP32PathValidityRegex                = @"m(/[1-9]?\\d+'?)*";

#pragma mark - BIP37

//
// Bloom filtering
//
// https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki
//

const uint32_t          WSBIP37MaxFilterLength                  = 36000;
const uint32_t          WSBIP37MaxHashFunctions                 = 50;
const uint32_t          WSBIP37HashMultiplier                   = 0xfba4c795;

#pragma mark - BIP39

//
// Mnemonic code for HD wallets
//
// https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
//

NSString *const         WSBIP39WordsResource                    = @"WSBIP39Words";
NSString *const         WSBIP39WordsType                        = @"txt";
const CFStringRef       WSBIP39SaltPrefix                       = CFSTR("mnemonic");
const NSUInteger        WSBIP39SaltPrefixLength                 = 8;
