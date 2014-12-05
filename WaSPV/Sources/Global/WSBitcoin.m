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
const NSUInteger        WSTransactionInputTypicalSize           = 148;
const NSUInteger        WSTransactionOutputTypicalSize          = 34;
const NSUInteger        WSTransactionOutPointSize               = 36;
const uint64_t          WSTransactionMinOutValue                = WSTransactionRelayFeePerUnit * 3 * (WSTransactionInputTypicalSize + WSTransactionOutputTypicalSize) / WSTransactionSizeUnit; // no txout can be below this amount (or it won't relay)
const NSUInteger        WSTransactionCoinbaseInputIndex         = 0xffffffff;

const uint64_t          WSTransactionMaxSize                    = 100000;   // no tx can be larger than this size in bytes
const uint64_t          WSTransactionFreeMaxSize                = 1000;     // tx must not be larger than this size in bytes without a fee
const uint64_t          WSTransactionFreeMinPriority            = 57600000; // tx must not have a priority below this value without a fee

NSUInteger WSTransactionTypicalSize(NSUInteger numberOfInputs, NSUInteger numberOfOutputs)
{
    // version + locktime + ins/outs
    return (8 + numberOfInputs * WSTransactionInputTypicalSize + numberOfOutputs * WSTransactionOutputTypicalSize);
}
