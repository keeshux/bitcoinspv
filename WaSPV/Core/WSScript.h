//
//  WSScript.h
//  WaSPV
//
//  Created by Davide De Rosa on 16/06/14.
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

#import "WSSized.h"

@class WSScriptChunk;
@class WSPublicKey;
@class WSAddress;

#pragma mark -

//
// multisig scripts (M-of-N) are described in BIP11
//
// https://github.com/bitcoin/bips/blob/master/bip-0011.mediawiki
//

@interface WSScript : NSObject <NSCopying, WSBufferEncoder, WSBufferDecoder, WSSized>

+ (instancetype)scriptWithAddress:(WSAddress *)address;
+ (instancetype)scriptWithSignature:(NSData *)signature publicKey:(WSPublicKey *)publicKey;

- (instancetype)initWithChunks:(NSArray *)chunks; // WSScriptChunk
- (NSArray *)chunks;

- (BOOL)isPushDataOnly;
- (BOOL)containsData:(NSData *)data;
- (NSArray *)arrayWithPushData; // NSData
- (NSSet *)setWithPushData; // NSData
- (WSAddress *)addressFromHash;
- (WSPublicKey *)publicKey; // nil if non-trivial scriptSig (signature + script)

- (BOOL)isPay2PubKeyHash;
- (BOOL)isPay2ScriptHash;
- (BOOL)isPay2PubKey;
- (BOOL)isPay2MultiSigWithM:(NSUInteger *)m N:(NSUInteger *)n;
- (NSArray *)publicKeysFromPay2MultiSigWithM:(NSUInteger *)m N:(NSUInteger *)n; // WSPublicKey

- (WSAddress *)standardAddress; // nil if non-standard script

@end

@interface WSCoinbaseScript : WSScript

+ (instancetype)scriptWithCoinbaseData:(NSData *)coinbaseData;
- (NSData *)coinbaseData;
- (uint32_t)blockHeight;

@end

#pragma mark -

@interface WSScriptBuilder : NSObject

- (instancetype)init;
- (instancetype)initWithAddress:(WSAddress *)address; // P2PKH or P2SH
- (instancetype)initWithSignature:(NSData *)signature publicKey:(WSPublicKey *)publicKey;

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
- (WSScriptOpcode)opcode;
- (NSString *)opcodeString;
- (NSUInteger)opcodeValue; // for OP_[1-16]
- (NSData *)pushData;
- (NSUInteger)pushDataLength;

@end
