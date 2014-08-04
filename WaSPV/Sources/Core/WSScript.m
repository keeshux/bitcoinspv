//
//  WSScript.m
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

#import "DDLog.h"

#import "WSScript.h"
#import "WSPublicKey.h"
#import "WSAddress.h"
#import "WSConfig.h"
#import "WSBitcoin.h"
#import "WSMacros.h"
#import "WSErrors.h"
#import "NSData+Binary.h"

@interface WSScriptChunk ()

@property (nonatomic, assign) BOOL isOpcode;
@property (nonatomic, assign) WSScriptOpcode opcode;
@property (nonatomic, strong) NSData *pushData;

- (instancetype)initWithOpcode:(WSScriptOpcode)opcode;
- (instancetype)initWithOpcode:(WSScriptOpcode)opcode pushData:(NSData *)pushData;
- (instancetype)initWithPushData:(NSData *)pushData;
- (NSUInteger)estimatedSize;

@end

#pragma mark -

@interface WSScript ()

@property (nonatomic, strong) NSArray *chunks;

- (WSAddress *)addressFromPay2PubKeyHash;
- (WSAddress *)addressFromPay2ScriptHash;
- (WSAddress *)addressFromPay2PubKey;
- (WSAddress *)addressFromPay2MultiSig;

@end

@implementation WSScript

+ (instancetype)scriptWithAddress:(WSAddress *)address
{
    return [[[WSScriptBuilder alloc] initWithAddress:address] build];
}

+ (instancetype)scriptWithSignature:(NSData *)signature publicKey:(WSPublicKey *)publicKey
{
    return [[[WSScriptBuilder alloc] initWithSignature:signature publicKey:publicKey] build];
}

- (instancetype)initWithChunks:(NSArray *)chunks
{
    if ((self = [super init])) {
        self.chunks = chunks;
    }
    return self;
}

- (BOOL)isPushDataOnly
{
    for (WSScriptChunk *chunk in self.chunks) {
        if (![chunk isPushData]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)containsData:(NSData *)data
{
    WSExceptionCheckIllegal(data != nil, @"Nil data");
    
    for (WSScriptChunk *chunk in self.chunks) {
        if ([chunk.pushData isEqualToData:data]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray *)arrayWithPushData
{
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:self.chunks.count];
    for (WSScriptChunk *chunk in self.chunks) {
        if (chunk.pushData) {
            [array addObject:chunk.pushData];
        }
    }
    return array;
}

- (NSSet *)setWithPushData
{
    NSMutableSet *set = [[NSMutableSet alloc] initWithCapacity:self.chunks.count];
    for (WSScriptChunk *chunk in self.chunks) {
        if (chunk.pushData) {
            [set addObject:chunk.pushData];
        }
    }
    return set;
}

- (WSAddress *)addressFromHash
{
    return WSAddressP2SHFromScript(self);
}

- (WSPublicKey *)publicKey
{
    for (WSScriptChunk *chunk in self.chunks) {
        if (WSPublicKeyIsValidData(chunk.pushData)) {
            return [WSPublicKey publicKeyWithData:chunk.pushData];
        }
    }
    return nil;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSScript *script = object;
    return [script.chunks isEqualToArray:self.chunks];
}

- (NSUInteger)hash
{
    return [self.chunks hash];
}

- (NSString *)description
{
    return [self.chunks componentsJoinedByString:@" "];
}

#pragma mark Output scripts

- (BOOL)isPay2PubKeyHash
{
    return ((self.chunks.count == 5) &&
            ([self.chunks[0] opcode] == WSScriptOpcode_DUP) &&
            ([self.chunks[1] opcode] == WSScriptOpcode_HASH160) &&
            ([self.chunks[2] pushDataLength] == WSHash160Length) &&
            ([self.chunks[3] opcode] == WSScriptOpcode_EQUALVERIFY) &&
            ([self.chunks[4] opcode] == WSScriptOpcode_CHECKSIG));
}

- (BOOL)isPay2ScriptHash
{
    return ((self.chunks.count == 3) &&
            ([self.chunks[0] opcode] == WSScriptOpcode_HASH160) &&
            ([self.chunks[1] pushDataLength] == WSHash160Length) &&
            ([self.chunks[2] opcode] == WSScriptOpcode_EQUAL));
}

- (BOOL)isPay2PubKey
{
    return ((self.chunks.count == 2) &&
            WSPublicKeyIsValidData([self.chunks[0] pushData]) &&
            ([self.chunks[1] opcode] == WSScriptOpcode_CHECKSIG));
}

//
// m <pubkey> ... <pubkey> n OP_CHECKMULTISIG
//   |                   |
//   \-------------------/
//          n pubkeys
//
// extra ops = m, n, OP_CHECKMULTISIG = 3
//
// script chunks = (3 + n) with (n > 0)
//
- (BOOL)isPay2MultiSigWithM:(NSUInteger *)m N:(NSUInteger *)n
{
    if (self.chunks.count < 4) {
        return NO;
    }
    if ([[self.chunks lastObject] opcode] != WSScriptOpcode_CHECKMULTISIG) {
        return NO;
    }

    const NSUInteger chunkN = [self.chunks[self.chunks.count - 2] opcodeValue];
    if (chunkN == NSNotFound) {
        return NO;
    }
    if (self.chunks.count != 3 + chunkN) {
        return NO;
    }

    const NSUInteger chunkM = [self.chunks[0] opcodeValue];
    if (chunkM == NSNotFound) {
        return NO;
    }
    if (chunkN < chunkM) {
        DDLogWarn(@"Invalid multiSig, N < M (%u < %u)", chunkN, chunkM);
        return NO;
    }

    if (m) {
        *m = chunkM;
    }
    if (n) {
        *n = chunkN;
    }

    return YES;
}

- (NSArray *)publicKeysFromPay2MultiSigWithM:(NSUInteger *)m N:(NSUInteger *)n
{
    NSUInteger localM, localN;
    if (![self isPay2MultiSigWithM:&localM N:&localN]) {
        return NO;
    }
    
    NSMutableArray *pubKeys = [[NSMutableArray alloc] initWithCapacity:localN];
    for (NSUInteger i = 0; i < localN; ++i) {
        NSData *pubKeyData = [self.chunks[1 + i] pushData];
        [pubKeys addObject:[WSPublicKey publicKeyWithData:pubKeyData]];
    }
    if (m) {
        *m = localM;
    }
    if (n) {
        *n = localN;
    }
    return pubKeys;
}

#pragma mark Standard address

- (WSAddress *)standardAddress
{
    WSAddress *address = [self addressFromPay2PubKeyHash];
    if (!address) {
        address = [self addressFromPay2ScriptHash];
    }
    if (!address) {
        address = [self addressFromPay2PubKey];
    }
    if (!address) {
        address = [self addressFromPay2MultiSig];
    }
    return address;
}
            
- (WSAddress *)addressFromPay2PubKeyHash
{
    if (![self isPay2PubKeyHash]) {
        return nil;
    }
    NSData *hash160 = [self.chunks[2] pushData];
    return WSAddressP2PKHFromHash160(hash160);
}

- (WSAddress *)addressFromPay2ScriptHash
{
    if (![self isPay2ScriptHash]) {
        return nil;
    }
    NSData *hash160 = [self.chunks[1] pushData];
    return WSAddressP2SHFromHash160(hash160);
}

- (WSAddress *)addressFromPay2PubKey
{
    if (![self isPay2PubKey]) {
        return nil;
    }
    return [[WSPublicKey publicKeyWithData:[self.chunks[0] pushData]] address];
}

- (WSAddress *)addressFromPay2MultiSig
{
    if (![self isPay2MultiSigWithM:NULL N:NULL]) {
        return nil;
    }
    return [self addressFromHash];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSScript *copy = [[self class] allocWithZone:zone];
    copy.chunks = [self.chunks copyWithZone:zone];
    return copy;
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    for (WSScriptChunk *chunk in self.chunks) {
        [chunk appendToMutableBuffer:buffer];
    }
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:[self estimatedSize]];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithBuffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    NSData *scriptData = [buffer dataAtOffset:from length:available];

    NSMutableArray *chunks = [[NSMutableArray alloc] init];
    const uint8_t *bytes = scriptData.bytes;
    const NSUInteger length = scriptData.length;
    NSUInteger currentLength = 0;

    for (NSUInteger i = 0; i < length; i++) {
        const WSScriptOpcode opcode = (WSScriptOpcode)bytes[i];
        
        if (opcode > WSScriptOpcode_PUSHDATA4) {
            [chunks addObject:[WSScriptChunk chunkWithOpcode:opcode]];
            continue;
        }

        BOOL stop = NO;

        switch (opcode) {
            case WSScriptOpcode_OP_0: {
                [chunks addObject:[WSScriptChunk chunkWithOpcode:opcode pushData:nil]];
                continue;
            }
            case WSScriptOpcode_PUSHDATA1: {
                ++i;
                if (i + sizeof(uint8_t) > length) {
                    stop = YES;
                    break;
                }
                currentLength = bytes[i];
                i += sizeof(uint8_t);
                break;
            }
            case WSScriptOpcode_PUSHDATA2: {
                ++i;
                if (i + sizeof(uint16_t) > length) {
                    stop = YES;
                    break;
                }
                currentLength = CFSwapInt16LittleToHost(*(uint16_t *)&bytes[i]);
                i += sizeof(uint16_t);
                break;
            }
            case WSScriptOpcode_PUSHDATA4: {
                ++i;
                if (i + sizeof(uint32_t) > length) {
                    stop = YES;
                    break;
                }
                currentLength = CFSwapInt32LittleToHost(*(uint32_t *)&bytes[i]);
                i += sizeof(uint32_t);
                break;
            }
            default: {
                currentLength = bytes[i];
                ++i;
                break;
            }
        }

        if (stop || (i + currentLength > length)) {
            break;
        }

        NSData *pushData = [NSData dataWithBytes:(bytes + i) length:currentLength];
        [chunks addObject:[WSScriptChunk chunkWithOpcode:opcode pushData:pushData]];

        i += currentLength - 1;
    }

//    NSAssert([self estimatedSize] == scriptData.length, @"Parsed script doesn't match original length (%u != %u)",
//             [self estimatedSize], scriptData.length);

    return [self initWithChunks:chunks];
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    NSUInteger size = 0;
    for (WSScriptChunk *chunk in self.chunks) {
        size += [chunk estimatedSize];
    }
    return size;
}

@end

#pragma mark -

@interface WSScriptBuilder ()

@property (nonatomic, strong) NSMutableArray *chunks;

@end

@implementation WSScriptBuilder

- (instancetype)init
{
    if ((self = [super init])) {
        self.chunks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype)initWithAddress:(WSAddress *)address
{
    WSExceptionCheckIllegal(address != nil, @"Nil address");
    
    if ((self = [self init])) {
        [self appendScriptForAddress:address];
    }
    return self;
}

- (instancetype)initWithSignature:(NSData *)signature publicKey:(WSPublicKey *)publicKey
{
    WSExceptionCheckIllegal(signature != nil, @"Nil signature");
    WSExceptionCheckIllegal(publicKey != nil, @"Nil publicKey");
    
    if ((self = [self init])) {
        [self appendPushData:signature];
        [self appendPushData:publicKey.data];
    }
    return self;
}

- (void)appendChunk:(WSScriptChunk *)chunk
{
    WSExceptionCheckIllegal(chunk != nil, @"Nil chunk");
    
    [self.chunks addObject:chunk];
}

- (void)appendOpcode:(WSScriptOpcode)opcode
{
    [self.chunks addObject:[WSScriptChunk chunkWithOpcode:opcode]];
}

- (void)appendPushData:(NSData *)pushData
{
    [self.chunks addObject:[WSScriptChunk chunkWithPushData:pushData]];
}

- (void)appendScriptForAddress:(WSAddress *)address
{
    WSExceptionCheckIllegal(address != nil, @"Nil address");
    
    //
    // pay-to-pubkey-hash
    //
    // https://en.bitcoin.it/wiki/Script#Standard_Transaction_to_Bitcoin_address_.28pay-to-pubkey-hash.29
    //
    if (address.version == [WSCurrentParameters publicKeyAddressVersion]) {
        [self appendOpcode:WSScriptOpcode_DUP];
        [self appendOpcode:WSScriptOpcode_HASH160];
        [self appendPushData:address.hash160];
        [self appendOpcode:WSScriptOpcode_EQUALVERIFY];
        [self appendOpcode:WSScriptOpcode_CHECKSIG];
    }
    //
    // BIP16: pay-to-script-hash
    //
    // https://github.com/bitcoin/bips/blob/master/bip-0016.mediawiki
    //
    else if (address.version == [WSCurrentParameters scriptAddressVersion]) {
        [self appendOpcode:WSScriptOpcode_HASH160];
        [self appendPushData:address.hash160];
        [self appendOpcode:WSScriptOpcode_EQUAL];
    }
}

- (void)appendScript:(WSScript *)script
{
    WSExceptionCheckIllegal(script != nil, @"Nil script");
    
    [self.chunks addObjectsFromArray:script.chunks];
}

- (void)removeChunksWithOpcode:(WSScriptOpcode)opcode
{
    NSMutableArray *removedChunks = [[NSMutableArray alloc] init];
    for (WSScriptChunk *chunk in self.chunks) {
        if (chunk.isOpcode && (chunk.opcode == opcode)) {
            [removedChunks addObject:chunk];
        }
    }
    [self.chunks removeObjectsInArray:removedChunks];
}

- (WSScript *)build
{
    return [[WSScript alloc] initWithChunks:self.chunks];
}

- (WSScript *)buildWithCopy
{
    return [[WSScript alloc] initWithChunks:[self.chunks copy]];
}

@end

#pragma mark -

@interface WSCoinbaseScript ()

@property (nonatomic, strong) NSData *coinbaseData;
@property (nonatomic, assign) uint32_t blockHeight;

- (instancetype)initWithCoinbaseData:(NSData *)coinbaseData;

@end

@implementation WSCoinbaseScript

+ (instancetype)scriptWithCoinbaseData:(NSData *)coinbaseData
{
    return [[self alloc] initWithCoinbaseData:coinbaseData];
}

- (instancetype)initWithCoinbaseData:(NSData *)coinbaseData
{
    WSExceptionCheckIllegal(coinbaseData != nil, @"Nil coinbaseData");

    WSBuffer *buffer = [[WSBuffer alloc] initWithData:coinbaseData];

    return [self initWithBuffer:buffer from:0 available:buffer.length error:NULL];
}

- (BOOL)isPushDataOnly
{
    return YES;
}

- (BOOL)containsData:(NSData *)data
{
    WSExceptionCheckIllegal(data != nil, @"Nil data");

    return [self.coinbaseData isEqualToData:data];
}

- (NSArray *)arrayWithPushData
{
    return @[self.coinbaseData];
}

- (NSSet *)setWithPushData
{
    return [NSSet setWithObject:self.coinbaseData];
}

- (WSAddress *)addressFromHash
{
    return nil;
}

- (WSPublicKey *)publicKey
{
    return nil;
}

- (BOOL)isPay2PubKeyHash
{
    return NO;
}

- (BOOL)isPay2ScriptHash
{
    return NO;
}

- (BOOL)isPay2PubKey
{
    return NO;
}

- (BOOL)isPay2MultiSigWithM:(NSUInteger *)m N:(NSUInteger *)n
{
    return NO;
}

- (NSArray *)publicKeysFromPay2MultiSigWithM:(NSUInteger *)m N:(NSUInteger *)n
{
    return nil;
}

- (WSAddress *)standardAddress
{
    return nil;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSCoinbaseScript *script = object;
    return [script.coinbaseData isEqualToData:script.coinbaseData];
}

- (NSUInteger)hash
{
    return [self.coinbaseData hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<#%u, %@>", self.blockHeight, [self.coinbaseData hexString]];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSCoinbaseScript *copy = [super copyWithZone:zone];
    copy.coinbaseData = [self.coinbaseData copyWithZone:zone];
    return copy;
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendData:self.coinbaseData];
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:self.coinbaseData.length];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

//
// http://bitcoin.stackexchange.com/questions/20721/what-is-the-format-of-coinbase-transaction
//
// The txin's prevout script is an arbitrary byte array (it doesn't have to be a valid script,
// though this is commonly done anyway) of 2 to 100 bytes. It has to start with a correct
// push of the block height (see BIP34).
//
// https://github.com/bitcoin/bips/blob/master/bip-0034.mediawiki
//
- (instancetype)initWithBuffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithBuffer:buffer from:from available:available error:error])) {
        self.coinbaseData = [buffer.data subdataWithRange:NSMakeRange(from, available)];

        if (self.chunks.count > 0) {
            NSData *heightData = [self.chunks[0] pushData];
            if (heightData.length <= sizeof(_blockHeight)) {
                [heightData getBytes:&_blockHeight length:heightData.length];
            }
            else {
                DDLogVerbose(@"Corrupted height in coinbase script (length: %u)", heightData.length);
                self.blockHeight = WSBlockUnknownHeight;
            }
        }
    }
    return self;
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    return self.coinbaseData.length;
}

@end

#pragma mark -

@implementation WSScriptChunk

+ (instancetype)chunkWithOpcode:(WSScriptOpcode)opcode
{
    return [[self alloc] initWithOpcode:opcode];
}

+ (instancetype)chunkWithOpcode:(WSScriptOpcode)opcode pushData:(NSData *)pushData
{
    return [[self alloc] initWithOpcode:opcode pushData:pushData];
}

+ (instancetype)chunkWithPushData:(NSData *)pushData
{
    return [[self alloc] initWithPushData:pushData];
}

- (instancetype)initWithOpcode:(WSScriptOpcode)opcode
{
    WSExceptionCheckIllegal(opcode > WSScriptOpcode_PUSHDATA4, @"For push chunks use initWithOpcode:pushData: (%@)",
                            WSScriptOpcodeString(opcode));
    
    if ((self = [super init])) {
        self.isOpcode = YES;
        self.opcode = opcode;
        self.pushData = nil;
    }
    return self;
}

- (instancetype)initWithOpcode:(WSScriptOpcode)opcode pushData:(NSData *)pushData
{
    WSExceptionCheckIllegal(opcode <= WSScriptOpcode_PUSHDATA4, @"For opcode chunks use initWithOpcode: (%@)",
                            WSScriptOpcodeString(opcode));
    
    if ((self = [super init])) {
        if (opcode == WSScriptOpcode_OP_0) {
            self.isOpcode = YES;
            self.opcode = opcode;
            self.pushData = nil; // ignored parameter
        }
        else {
            WSExceptionCheckIllegal(pushData != nil, @"Nil pushData");
            
            self.isOpcode = (opcode >= WSScriptOpcode_PUSHDATA1);
            self.opcode = opcode;
            self.pushData = [pushData copy];
        }
    }
    return self;
}

- (instancetype)initWithPushData:(NSData *)pushData
{
    WSExceptionCheckIllegal(pushData != nil, @"Nil pushData");
    
    WSScriptOpcode opcode;
    if (pushData.length < WSScriptOpcode_PUSHDATA1) {
        opcode = (WSScriptOpcode)pushData.length;
    }
    else {
        if (pushData.length < UINT8_MAX) {
            opcode = WSScriptOpcode_PUSHDATA1;
        }
        else if (pushData.length < UINT16_MAX) {
            opcode = WSScriptOpcode_PUSHDATA2;
        }
        else {
            opcode = WSScriptOpcode_PUSHDATA4;
        }
    }
    
    return [self initWithOpcode:opcode pushData:pushData];
}

- (BOOL)isPushData
{
    return ((self.opcode == WSScriptOpcode_OP_0) || (self.pushData != nil));
}

- (NSString *)opcodeString
{
    if (!self.isOpcode) {
        return nil;
    }
    return WSScriptOpcodeString(self.opcode);
}

- (NSUInteger)opcodeValue
{
    if (!self.isOpcode) {
        return NSNotFound;
    }
    return WSScriptOpcodeValue(self.opcode);
}

- (NSUInteger)pushDataLength
{
    return self.pushData.length;
}

- (NSString *)description
{
    NSMutableArray *components = [[NSMutableArray alloc] init];
    if (self.isOpcode && !self.pushData) {
        [components addObject:self.opcodeString];
    }
    if (self.pushData) {
        [components addObject:[NSString stringWithFormat:@"[%@]", [self.pushData hexString]]];
    }
    return [components componentsJoinedByString:@" "];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSScriptChunk *copy = [[self class] allocWithZone:zone];
    copy.isOpcode = self.isOpcode;
    copy.opcode = self.opcode;
    copy.pushData = [self.pushData copyWithZone:zone];
    return copy;
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    if (self.isOpcode) {
        [buffer appendUint8:self.opcode];
    }
    switch (self.opcode) {
        case WSScriptOpcode_PUSHDATA1: {
            [buffer appendUint8:(uint8_t)self.pushData.length];
            break;
        }
        case WSScriptOpcode_PUSHDATA2: {
            [buffer appendUint16:(uint16_t)self.pushData.length];
            break;
        }
        case WSScriptOpcode_PUSHDATA4: {
            [buffer appendUint32:(uint32_t)self.pushData.length];
            break;
        }
        default: {
            if (self.pushData) {
                [buffer appendUint8:(uint8_t)self.pushData.length];
            }
            break;
        }
    }
    if (self.pushData) {
        [buffer appendData:self.pushData];
    }
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:[self estimatedSize]];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    NSUInteger size = 1; // opcode / push length
    
    switch (self.opcode) {
        case WSScriptOpcode_PUSHDATA1: {
            size += 1;
            break;
        }
        case WSScriptOpcode_PUSHDATA2: {
            size += 2;
            break;
        }
        case WSScriptOpcode_PUSHDATA4: {
            size += 4;
            break;
        }
        default: {
            break;
        }
    }
    if (self.pushData) {
        size += self.pushData.length;
    }
    
    return size;
}

@end

#pragma mark -

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
