//
//  WSScript.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 16/06/14.
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
#import "WSSized.h"

//
// Script
//
// https://en.bitcoin.it/wiki/Script
//

@class WSScriptChunk;
@class WSPublicKey;
@class WSAddress;

#pragma mark -

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

// for OP_1-16 opcodes
WSScriptOpcode WSScriptOpcodeFromValue(NSInteger value);
NSInteger WSScriptOpcodeToValue(WSScriptOpcode opcode);

#pragma mark -

//
// multisig scripts (M-of-N) are described in BIP11
//
// https://github.com/bitcoin/bips/blob/master/bip-0011.mediawiki
//

@interface WSScript : NSObject <NSCopying, WSBufferEncoder, WSBufferDecoder, WSSized>

+ (instancetype)scriptWithAddress:(WSAddress *)address;
+ (instancetype)scriptWithSignature:(NSData *)signature publicKey:(WSPublicKey *)publicKey;
+ (instancetype)scriptWithSignatures:(NSArray *)signatures publicKeys:(NSArray *)publicKeys;
+ (instancetype)redeemScriptWithNumberOfSignatures:(NSUInteger)numberOfSignatures publicKeys:(NSArray *)publicKeys;

- (instancetype)initWithChunks:(NSArray *)chunks; // WSScriptChunk
- (NSArray *)chunks;

- (BOOL)isPushDataOnly;
- (BOOL)containsData:(NSData *)data;

- (BOOL)isScriptSigWithSignature:(NSData **)signature publicKey:(WSPublicKey **)publicKey;
- (BOOL)isScriptSigWithSignatures:(NSArray **)signatures publicKeys:(NSArray **)publicKeys redeemScript:(WSScript **)redeemScript;
- (BOOL)isScriptSigWithReedemNumberOfSignatures:(NSUInteger *)numberOfSignatures publicKeys:(NSArray **)publicKeys;

- (BOOL)isPay2PubKeyHash;
- (BOOL)isPay2PubKey;
- (BOOL)isPay2ScriptHash;

- (WSAddress *)standardInputAddressWithParameters:(WSParameters *)parameters;     // nil if non-standard script
- (WSAddress *)standardOutputAddressWithParameters:(WSParameters *)parameters;    // nil if non-standard script
- (WSAddress *)standardAddressWithParameters:(WSParameters *)parameters;          // any of the above
- (WSAddress *)addressFromHashWithParameters:(WSParameters *)parameters;

- (NSData *)originalData; // nil if from chunks, non-nil if from buffer

@end

@interface WSCoinbaseScript : WSScript

+ (instancetype)scriptWithCoinbaseData:(NSData *)coinbaseData;
- (uint32_t)blockHeight;

@end

#pragma mark -

@interface WSScriptBuilder : NSObject

- (instancetype)init;
- (instancetype)initWithAddress:(WSAddress *)address; // P2PKH or P2SH
- (instancetype)initWithSignature:(NSData *)signature publicKey:(WSPublicKey *)publicKey;
- (instancetype)initWithSignatures:(NSArray *)signatures publicKeys:(NSArray *)publicKeys;
- (instancetype)initWithRedeemNumberOfSignatures:(NSUInteger)numberOfSignatures publicKeys:(NSArray *)publicKeys;

- (void)appendChunk:(WSScriptChunk *)chunk;
- (void)appendOpcode:(WSScriptOpcode)opcode;
- (void)appendPushData:(NSData *)pushData;
- (void)appendScriptForAddress:(WSAddress *)address;
- (void)appendScript:(WSScript *)script;
- (void)removeChunksWithOpcode:(WSScriptOpcode)opcode;

- (WSScript *)build;
- (WSScript *)buildWithCopy;

@end

#pragma mark -

@interface WSScriptChunk : NSObject <NSCopying, WSBufferEncoder, WSSized>

+ (instancetype)chunkWithOpcode:(WSScriptOpcode)opcode;
+ (instancetype)chunkWithOpcode:(WSScriptOpcode)opcode pushData:(NSData *)pushData;
+ (instancetype)chunkWithPushData:(NSData *)pushData;
- (BOOL)isOpcode;
- (BOOL)isPushData;
- (BOOL)isSignature;
- (WSScriptOpcode)opcode;
- (NSString *)opcodeString;
- (NSUInteger)opcodeValue; // for OP_[1-16]
- (NSData *)pushData;
- (NSUInteger)pushDataLength;

@end
