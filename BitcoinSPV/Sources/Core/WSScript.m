//
//  WSScript.m
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

#import "WSScript.h"
#import "WSPublicKey.h"
#import "WSHash160.h"
#import "WSAddress.h"
#import "WSLogging.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "NSData+Binary.h"

@interface WSScriptChunk ()

@property (nonatomic, assign) BOOL isOpcode;
@property (nonatomic, assign) WSScriptOpcode opcode;
@property (nonatomic, strong) NSData *pushData;

- (instancetype)initWithOpcode:(WSScriptOpcode)opcode;
- (instancetype)initWithOpcode:(WSScriptOpcode)opcode pushData:(NSData *)pushData;
- (instancetype)initWithPushData:(NSData *)pushData;

@end

#pragma mark -

@interface WSScript ()

@property (nonatomic, strong) NSData *originalData;
@property (nonatomic, strong) NSArray *chunks;

- (WSAddress *)addressFromScriptSigWithParameters:(WSParameters *)parameters;
- (WSAddress *)addressFromScriptMultisigWithParameters:(WSParameters *)parameters;
- (WSAddress *)addressFromPay2PubKeyHashWithParameters:(WSParameters *)parameters;
- (WSAddress *)addressFromPay2ScriptHashWithParameters:(WSParameters *)parameters;
- (WSAddress *)addressFromPay2PubKeyWithParameters:(WSParameters *)parameters;

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

+ (instancetype)scriptWithSignatures:(NSArray *)signatures publicKeys:(NSArray *)publicKeys
{
    return [[[WSScriptBuilder alloc] initWithSignatures:signatures publicKeys:publicKeys] build];
}

+ (instancetype)redeemScriptWithNumberOfSignatures:(NSUInteger)numberOfSignatures publicKeys:(NSArray *)publicKeys
{
    return [[[WSScriptBuilder alloc] initWithRedeemNumberOfSignatures:numberOfSignatures publicKeys:publicKeys] build];
}

- (instancetype)initWithChunks:(NSArray *)chunks
{
    WSExceptionCheckIllegal(chunks);
    
    if ((self = [super init])) {
        self.chunks = chunks;
        self.originalData = nil;
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
    WSExceptionCheckIllegal(data);
    
    for (WSScriptChunk *chunk in self.chunks) {
        if ([chunk.pushData isEqualToData:data]) {
            return YES;
        }
    }
    return NO;
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

#pragma mark Input scripts

- (BOOL)isScriptSigWithSignature:(NSData *__autoreleasing *)signature publicKey:(WSPublicKey *__autoreleasing *)publicKey
{
    if (self.chunks.count != 2) {
        return NO;
    }
    
    WSScriptChunk *chunkSig = self.chunks[0];
    if (![chunkSig isSignature]) {
        return NO;
    }
    WSScriptChunk *chunkPublicKey = self.chunks[1];
    WSPublicKey *localPublicKey = [WSPublicKey publicKeyWithData:chunkPublicKey.pushData];
    if (!localPublicKey) {
        return NO;
    }
    
    if (signature) {
        *signature = chunkSig.pushData;
    }
    if (publicKey) {
        *publicKey = localPublicKey;
    }

    return YES;
}

- (BOOL)isScriptSigWithSignatures:(NSArray *__autoreleasing *)signatures publicKeys:(NSArray *__autoreleasing *)publicKeys redeemScript:(WSScript *__autoreleasing *)redeemScript
{
    if (self.chunks.count < 4) {
        return NO;
    }

#warning XXX: discard first opcode, usually OP_0
    if (![[self.chunks firstObject] isOpcode]) {
        return NO;
    }
    
    // last chunk is push data with redeem script
    if (![[self.chunks lastObject] isPushData]) {
        return NO;
    }

    // middle chunks are a sequence of signatures
    const NSUInteger numberOfSignatures = self.chunks.count - 2;
    NSMutableArray *localSignatures = [[NSMutableArray alloc] initWithCapacity:numberOfSignatures];
    for (NSUInteger i = 1; i <= numberOfSignatures; ++i) {
        WSScriptChunk *chunk = self.chunks[i];
        if (![chunk isSignature]) {
            return NO;
        }
        [localSignatures addObject:chunk.pushData];
    }

    WSScriptChunk *chunkRedeem = [self.chunks lastObject];
    WSBuffer *chunkRedeemBuffer = [[WSBuffer alloc] initWithData:chunkRedeem.pushData];
    WSScript *localRedeemScript = [[WSScript alloc] initWithParameters:nil buffer:chunkRedeemBuffer from:0 available:chunkRedeemBuffer.length error:NULL];

    NSUInteger outNumberOfSignatures;
    NSArray *localPublicKeys;
    if (![localRedeemScript isScriptSigWithReedemNumberOfSignatures:&outNumberOfSignatures publicKeys:&localPublicKeys]) {
        return NO;
    }

    NSAssert(localSignatures.count == outNumberOfSignatures, @"Incorrect number of signatures (%lu != %lu)",
             (unsigned long)localSignatures.count,
             (unsigned long)outNumberOfSignatures);

    if (signatures) {
        *signatures = localSignatures;
    }
    if (publicKeys) {
        *publicKeys = localPublicKeys;
    }
    if (redeemScript) {
        *redeemScript = localRedeemScript;
    }

    return YES;
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
- (BOOL)isScriptSigWithReedemNumberOfSignatures:(NSUInteger *)numberOfSignatures publicKeys:(NSArray *__autoreleasing *)publicKeys
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
        DDLogDebug(@"Invalid multiSig, N < M (%lu < %lu)", (unsigned long)chunkN, (unsigned long)chunkM);
        return NO;
    }
    
    NSMutableArray *localPublicKeys = [[NSMutableArray alloc] initWithCapacity:chunkN];
    for (NSUInteger i = 1; i <= chunkN; ++i) {
        WSScriptChunk *chunk = self.chunks[i];
        WSPublicKey *publicKey = [WSPublicKey publicKeyWithData:chunk.pushData];
        if (!publicKey) {
            return NO;
        }
        [localPublicKeys addObject:publicKey];
    }
    if (localPublicKeys.count != chunkN) {
        return NO;
    }
    
    if (numberOfSignatures) {
        *numberOfSignatures = chunkM;
    }
    if (publicKeys) {
        *publicKeys = localPublicKeys;
    }
    
    return YES;
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

- (BOOL)isPay2PubKey
{
    return ((self.chunks.count == 2) &&
            [WSPublicKey publicKeyWithData:[self.chunks[0] pushData]] &&
            ([self.chunks[1] opcode] == WSScriptOpcode_CHECKSIG));
}

- (BOOL)isPay2ScriptHash
{
    return ((self.chunks.count == 3) &&
            ([self.chunks[0] opcode] == WSScriptOpcode_HASH160) &&
            ([self.chunks[1] pushDataLength] == WSHash160Length) &&
            ([self.chunks[2] opcode] == WSScriptOpcode_EQUAL));
}

#pragma mark Standard address

- (WSAddress *)standardInputAddressWithParameters:(WSParameters *)parameters
{
    WSExceptionCheckIllegal(parameters);
    
    WSAddress *address = [self addressFromScriptSigWithParameters:parameters];
    if (!address) {
        address = [self addressFromScriptMultisigWithParameters:parameters];
    }
    return address;
}
            
- (WSAddress *)standardOutputAddressWithParameters:(WSParameters *)parameters
{
    WSExceptionCheckIllegal(parameters);

    WSAddress *address = [self addressFromPay2PubKeyHashWithParameters:parameters];
    if (!address) {
        address = [self addressFromPay2PubKeyWithParameters:parameters];
    }
    if (!address) {
        address = [self addressFromPay2ScriptHashWithParameters:parameters];
    }
    return address;
}

- (WSAddress *)standardAddressWithParameters:(WSParameters *)parameters
{
    WSExceptionCheckIllegal(parameters);

    WSAddress *address = [self standardInputAddressWithParameters:parameters];
    if (!address) {
        address = [self standardOutputAddressWithParameters:parameters];
    }
    return address;
}

- (WSAddress *)addressFromScriptSigWithParameters:(WSParameters *)parameters
{
    NSParameterAssert(parameters);
    
    if (self.chunks.count != 2) {
        return nil;
    }
    
    WSScriptChunk *chunkSig = self.chunks[0];
    if (![chunkSig isSignature]) {
        return nil;
    }
    WSScriptChunk *chunkPublicKey = self.chunks[1];
    WSPublicKey *localPublicKey = [WSPublicKey publicKeyWithData:chunkPublicKey.pushData];
    if (!localPublicKey) {
        return nil;
    }
    return WSAddressP2PKHFromHash160(parameters, [localPublicKey hash160]);
}

- (WSAddress *)addressFromScriptMultisigWithParameters:(WSParameters *)parameters
{
    NSParameterAssert(parameters);

    WSScript *redeemScript;
    if (![self isScriptSigWithSignatures:NULL publicKeys:NULL redeemScript:&redeemScript]) {
        return nil;
    }
    return WSAddressP2SHFromHash160(parameters, [[redeemScript toBuffer] computeHash160]);
}

- (WSAddress *)addressFromPay2PubKeyHashWithParameters:(WSParameters *)parameters
{
    NSParameterAssert(parameters);

    if (![self isPay2PubKeyHash]) {
        return nil;
    }
    NSData *hash160 = [self.chunks[2] pushData];
    return WSAddressP2PKHFromHash160(parameters, WSHash160FromData(hash160));
}

- (WSAddress *)addressFromPay2ScriptHashWithParameters:(WSParameters *)parameters
{
    NSParameterAssert(parameters);

    if (![self isPay2ScriptHash]) {
        return nil;
    }
    NSData *hash160 = [self.chunks[1] pushData];
    return WSAddressP2SHFromHash160(parameters, WSHash160FromData(hash160));
}

- (WSAddress *)addressFromPay2PubKeyWithParameters:(WSParameters *)parameters
{
    NSParameterAssert(parameters);

    if (![self isPay2PubKey]) {
        return nil;
    }
    WSPublicKey *pubKey = [WSPublicKey publicKeyWithData:[self.chunks[0] pushData]];
    return [pubKey addressWithParameters:parameters];
}

- (WSAddress *)addressFromHashWithParameters:(WSParameters *)parameters
{
    NSParameterAssert(parameters);

    return WSAddressP2SHFromHash160(parameters, [[self toBuffer] computeHash160]);
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
    if (self.originalData) {
        [buffer appendData:self.originalData];
    }
    else {
        for (WSScriptChunk *chunk in self.chunks) {
            [chunk appendToMutableBuffer:buffer];
        }
    }
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:[self estimatedSize]];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
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

    if ((self = [self initWithChunks:chunks])) {
        self.originalData = scriptData;
    }
    return self;
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    if (self.originalData) {
        return self.originalData.length;
    }
    else {
        NSUInteger size = 0;
        for (WSScriptChunk *chunk in self.chunks) {
            size += [chunk estimatedSize];
        }
        return size;
    }
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
    WSExceptionCheckIllegal(address);
    
    if ((self = [self init])) {
        [self appendScriptForAddress:address];
    }
    return self;
}

- (instancetype)initWithSignature:(NSData *)signature publicKey:(WSPublicKey *)publicKey
{
    WSExceptionCheckIllegal(signature);
    WSExceptionCheckIllegal(publicKey);
    
    if ((self = [self init])) {
        [self appendPushData:signature];
        [self appendPushData:publicKey.data];
    }
    return self;
}

- (instancetype)initWithSignatures:(NSArray *)signatures publicKeys:(NSArray *)publicKeys
{
    WSExceptionCheckIllegal(signatures.count > 0);
    WSExceptionCheckIllegal(publicKeys.count > 0);
    WSExceptionCheckIllegal(signatures.count <= 16);
    WSExceptionCheckIllegal(publicKeys.count <= 16);
    WSExceptionCheckIllegal(signatures.count >= 2);
    WSExceptionCheckIllegal(publicKeys.count >= signatures.count);
    
    if ((self = [self init])) {
        [self appendOpcode:WSScriptOpcode_OP_0];
        for (NSData *signature in signatures) {
            [self appendPushData:signature];
        }

        WSScript *redeemScript = [WSScript redeemScriptWithNumberOfSignatures:signatures.count publicKeys:publicKeys];
        [self appendPushData:[redeemScript toBuffer].data];
    }
    return self;
}

- (instancetype)initWithRedeemNumberOfSignatures:(NSUInteger)numberOfSignatures publicKeys:(NSArray *)publicKeys
{
    WSExceptionCheckIllegal(numberOfSignatures > 0);
    WSExceptionCheckIllegal(publicKeys.count > 0);
    WSExceptionCheckIllegal(numberOfSignatures <= 16);
    WSExceptionCheckIllegal(publicKeys.count <= 16);
    WSExceptionCheckIllegal(publicKeys.count >= numberOfSignatures);

    if ((self = [self init])) {
        [self appendOpcode:WSScriptOpcodeFromValue(numberOfSignatures)];
        for (WSPublicKey *publicKey in publicKeys) {
            [self appendPushData:publicKey.data];
        }
        [self appendOpcode:WSScriptOpcodeFromValue(publicKeys.count)];
        [self appendOpcode:WSScriptOpcode_CHECKMULTISIG];
    }
    return self;
}

- (void)appendChunk:(WSScriptChunk *)chunk
{
    WSExceptionCheckIllegal(chunk);
    
    [self.chunks addObject:chunk];
}

- (void)appendOpcode:(WSScriptOpcode)opcode
{
    if (opcode == WSScriptOpcode_OP_0) {
        [self.chunks addObject:[WSScriptChunk chunkWithOpcode:opcode pushData:nil]];
    }
    else {
        [self.chunks addObject:[WSScriptChunk chunkWithOpcode:opcode]];
    }
}

- (void)appendPushData:(NSData *)pushData
{
    [self.chunks addObject:[WSScriptChunk chunkWithPushData:pushData]];
}

- (void)appendScriptForAddress:(WSAddress *)address
{
    WSExceptionCheckIllegal(address);
    
    //
    // pay-to-pubkey-hash
    //
    // https://en.bitcoin.it/wiki/Script#Standard_Transaction_to_Bitcoin_address_.28pay-to-pubkey-hash.29
    //
    if (address.version == [address.parameters publicKeyAddressVersion]) {
        [self appendOpcode:WSScriptOpcode_DUP];
        [self appendOpcode:WSScriptOpcode_HASH160];
        [self appendPushData:address.hash160.data];
        [self appendOpcode:WSScriptOpcode_EQUALVERIFY];
        [self appendOpcode:WSScriptOpcode_CHECKSIG];
    }
    //
    // BIP16: pay-to-script-hash
    //
    // https://github.com/bitcoin/bips/blob/master/bip-0016.mediawiki
    //
    else if (address.version == [address.parameters scriptAddressVersion]) {
        [self appendOpcode:WSScriptOpcode_HASH160];
        [self appendPushData:address.hash160.data];
        [self appendOpcode:WSScriptOpcode_EQUAL];
    }
}

- (void)appendScript:(WSScript *)script
{
    WSExceptionCheckIllegal(script);
    
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
    WSExceptionCheckIllegal(coinbaseData);

    WSBuffer *buffer = [[WSBuffer alloc] initWithData:coinbaseData];

    return [self initWithParameters:nil buffer:buffer from:0 available:buffer.length error:NULL];
}

- (BOOL)isPushDataOnly
{
    return YES;
}

- (BOOL)containsData:(NSData *)data
{
    WSExceptionCheckIllegal(data);

    return [self.originalData isEqualToData:data];
}

- (BOOL)isScriptSigWithSignature:(NSData *__autoreleasing *)signature publicKey:(WSPublicKey *__autoreleasing *)publicKey
{
    return NO;
}

- (BOOL)isScriptSigWithSignatures:(NSArray *__autoreleasing *)signatures publicKeys:(NSArray *__autoreleasing *)publicKeys redeemScript:(WSScript *__autoreleasing *)redeemScript
{
    return NO;
}

- (BOOL)isScriptSigWithReedemNumberOfSignatures:(NSUInteger *)numberOfSignatures publicKeys:(NSArray *__autoreleasing *)publicKeys
{
    return NO;
}

- (BOOL)isPay2PubKeyHash
{
    return NO;
}

- (BOOL)isPay2PubKey
{
    return NO;
}

- (BOOL)isPay2ScriptHash
{
    return NO;
}

- (WSAddress *)standardInputAddress
{
    return nil;
}

- (WSAddress *)standardOutputAddress
{
    return nil;
}

- (WSAddress *)standardAddress
{
    return nil;
}

- (WSAddress *)addressFromHash
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
    return [script.originalData isEqualToData:self.originalData];
}

- (NSUInteger)hash
{
    return [self.originalData hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<#%u, %@>", self.blockHeight, [self.originalData hexString]];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSCoinbaseScript *copy = [super copyWithZone:zone];
    copy.originalData = [self.originalData copyWithZone:zone];
    return copy;
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendData:self.originalData];
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:self.originalData.length];
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
- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithParameters:parameters buffer:buffer from:from available:available error:error])) {
        self.originalData = [buffer.data subdataWithRange:NSMakeRange(from, available)];

        if (self.chunks.count > 0) {
            NSData *heightData = [self.chunks[0] pushData];
            if (heightData.length <= sizeof(_blockHeight)) {
                [heightData getBytes:&_blockHeight length:heightData.length];
            }
            else {
                DDLogVerbose(@"Corrupted height in coinbase script (length: %lu)", (unsigned long)heightData.length);
                self.blockHeight = WSBlockUnknownHeight;
            }
        }
    }
    return self;
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
    WSExceptionCheck(opcode > WSScriptOpcode_PUSHDATA4,
                     WSExceptionIllegalArgument,
                     @"For push chunks use initWithOpcode:pushData: (%@)",
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
    WSExceptionCheck(opcode <= WSScriptOpcode_PUSHDATA4,
                     WSExceptionIllegalArgument,
                     @"For opcode chunks use initWithOpcode: (%@)",
                     WSScriptOpcodeString(opcode));
    
    if ((self = [super init])) {
        if (opcode == WSScriptOpcode_OP_0) {
            self.isOpcode = YES;
            self.opcode = opcode;
            self.pushData = nil; // ignored parameter
        }
        else {
            WSExceptionCheckIllegal(pushData);
            
            self.isOpcode = (opcode >= WSScriptOpcode_PUSHDATA1);
            self.opcode = opcode;
            self.pushData = pushData;
        }
    }
    return self;
}

- (instancetype)initWithPushData:(NSData *)pushData
{
    WSExceptionCheckIllegal(pushData);
    
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

- (BOOL)isSignature
{
    return ((self.pushData.length > 0) && (*(uint8_t *)self.pushData.bytes == WSKeySignaturePrefix));
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
    return WSScriptOpcodeToValue(self.opcode);
}

- (NSUInteger)pushDataLength
{
    return self.pushData.length;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSScriptChunk *chunk = object;
    if (self.isOpcode) {
        return (chunk.opcode == self.opcode);
    }
    else {
        return [chunk.pushData isEqualToData:self.pushData];
    }
}

- (NSUInteger)hash
{
    if (self.isOpcode) {
        return self.opcode;
    }
    else {
        return [self.pushData hash];
    }
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
            names[@(numberOpcode)] = [NSString stringWithFormat:@"OP_%ld", (long)WSScriptOpcodeToValue(numberOpcode)];
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

WSScriptOpcode WSScriptOpcodeFromValue(NSInteger value)
{
    WSExceptionCheckIllegal((value >= 1) && (value <= 16));
    
    return (WSScriptOpcode_OP_1 + (int)value - 1);
}

NSInteger WSScriptOpcodeToValue(WSScriptOpcode opcode)
{
    WSExceptionCheckIllegal((opcode >= WSScriptOpcode_OP_1) && (opcode <= WSScriptOpcode_OP_16));
    
    return (opcode - WSScriptOpcode_OP_1 + 1);
}
