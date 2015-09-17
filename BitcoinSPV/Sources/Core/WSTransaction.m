//
//  WSTransaction.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/06/14.
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

#import "WSTransaction.h"
#import "WSTransactionOutPoint.h"
#import "WSTransactionInput.h"
#import "WSTransactionOutput.h"
#import "WSHash256.h"
#import "WSScript.h"
#import "WSKey.h"
#import "WSPublicKey.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSSignedTransaction ()

@property (nonatomic, assign) uint32_t version;
@property (nonatomic, strong) NSOrderedSet *signedInputs;
@property (nonatomic, strong) NSOrderedSet *outputs;
@property (nonatomic, assign) uint32_t lockTime;

@property (nonatomic, strong) WSHash256 *txId;
@property (nonatomic, assign) NSUInteger txIdPrefix;
@property (nonatomic, assign) NSUInteger size;

@end

@implementation WSSignedTransaction

- (instancetype)initWithSignedInputs:(NSOrderedSet *)inputs outputs:(NSOrderedSet *)outputs error:(NSError *__autoreleasing *)error
{
    return [self initWithVersion:WSTransactionVersion signedInputs:inputs outputs:outputs lockTime:WSTransactionDefaultLockTime error:error];
}

- (instancetype)initWithVersion:(uint32_t)version
                   signedInputs:(NSOrderedSet *)inputs      // WSSignedTransactionInput
                        outputs:(NSOrderedSet *)outputs     // WSTransactionOutput
                       lockTime:(uint32_t)lockTime
                          error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(inputs.count > 0);
    WSExceptionCheckIllegal(outputs.count > 0);
    
    if ((self = [super init])) {
        self.version = version;
        self.signedInputs = inputs;
        self.outputs = outputs;
        self.lockTime = lockTime;

        WSBuffer *buffer = [self toBuffer];
//        if (buffer.length > WSTransactionMaxSize) {
//            WSErrorSet(error, WSErrorCodeInvalidTransaction, @"Transaction is too big (size: %u > %u)", buffer.length, WSTransactionMaxSize);
//            return nil;
//        }

        self.txId = [buffer computeHash256];
        self.txIdPrefix = *(NSUInteger *)self.txId.bytes;
        self.size = buffer.length;
    }
    return self;
}

- (WSSignedTransactionInput *)signedInputAtIndex:(uint32_t)index
{
    WSExceptionCheckIllegal(index < self.signedInputs.count);
    
    return self.signedInputs[index];
}

- (WSTransactionOutput *)outputAtIndex:(uint32_t)index
{
    WSExceptionCheckIllegal(index < self.outputs.count);
    
    return self.outputs[index];
}

- (NSSet *)inputTxIds
{
    NSMutableSet *ids = [[NSMutableSet alloc] init];
    for (WSSignedTransactionInput *input in self.inputs) {
        [ids addObject:input.outpoint.txId];
    }
    return ids;
}

- (NSSet *)outputAddresses
{
    NSMutableSet *addresses = [[NSMutableSet alloc] init];
    for (WSTransactionOutput *output in self.outputs) {
        if (output.address) {
            [addresses addObject:output.address];
        }
    }
    return addresses;
}

- (uint64_t)outputValue
{
    uint64_t value = 0;
    for (WSTransactionOutput *output in self.outputs) {
        value += output.value;
    }
    return value;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSSignedTransaction *tx = object;
    return [tx.txId isEqual:self.txId];
}

- (NSUInteger)hash
{
    return self.txIdPrefix;
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

#pragma mark WSTransaction

- (NSOrderedSet *)inputs
{
    return self.signedInputs;
}

- (BOOL)isCoinbase
{
    if (self.inputs.count != 1) {
        return NO;
    }
    WSSignedTransactionInput *input = [self.signedInputs lastObject];
    return [input.outpoint isCoinbase];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendUint32:self.version];
    [buffer appendVarInt:self.inputs.count];
    for (WSSignedTransactionInput *input in self.signedInputs) {
        [input appendToMutableBuffer:buffer];
    }
    [buffer appendVarInt:self.outputs.count];
    for (WSTransactionOutput *output in self.outputs) {
        [output appendToMutableBuffer:buffer];
    }
    [buffer appendUint32:self.lockTime];
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
    NSUInteger offset = from;

    const uint32_t version = [buffer uint32AtOffset:offset];
    offset += sizeof(uint32_t);
    
    NSUInteger inputsCountLength;
    const NSUInteger inputsCount = (NSUInteger)[buffer varIntAtOffset:offset length:&inputsCountLength];
    if (inputsCount == 0) {
        WSErrorSet(error, WSErrorCodeInvalidTransaction, @"Empty inputs");
        return nil;
    }
    if (inputsCount > INT32_MAX) {
        WSErrorSet(error, WSErrorCodeInvalidTransaction, @"Too many inputs (%u > INT32_MAX)", inputsCount);
        return nil;
    }
    offset += inputsCountLength;
    
    NSMutableOrderedSet *inputs = [[NSMutableOrderedSet alloc] initWithCapacity:inputsCount];
    for (NSUInteger i = 0; i < inputsCount; ++i) {
        WSSignedTransactionInput *input = [[WSSignedTransactionInput alloc] initWithParameters:parameters
                                                                                        buffer:buffer
                                                                                          from:offset
                                                                                     available:(available - offset + from)
                                                                                         error:error];
        if (!input) {
            return nil;
        }
        [inputs addObject:input];
        offset += [input estimatedSize];
    }
    
    NSUInteger outputsCountLength;
    const NSUInteger outputsCount = (NSUInteger)[buffer varIntAtOffset:offset length:&outputsCountLength];
    if (outputsCount == 0) {
        WSErrorSet(error, WSErrorCodeInvalidTransaction, @"Empty outputs");
        return nil;
    }
    if (outputsCount > INT32_MAX) {
        WSErrorSet(error, WSErrorCodeInvalidTransaction, @"Too many outputs (%u > INT32_MAX)", outputsCount);
        return nil;
    }
    offset += outputsCountLength;
    
    NSMutableOrderedSet *outputs = [[NSMutableOrderedSet alloc] initWithCapacity:outputsCount];
    for (NSUInteger i = 0; i < outputsCount; ++i) {
        WSTransactionOutput *output = [[WSTransactionOutput alloc] initWithParameters:parameters
                                                                               buffer:buffer
                                                                                 from:offset
                                                                            available:(available - offset + from)
                                                                                error:error];
        if (!output) {
            return nil;
        }
        [outputs addObject:output];
        offset += [output estimatedSize];
    }
    
    const uint32_t lockTime = [buffer uint32AtOffset:offset];

    return [self initWithVersion:version signedInputs:inputs outputs:outputs lockTime:lockTime error:error];
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    if (self.size == 0) {
        return WSTransactionEstimatedSize(self.inputs, self.outputs, nil, nil, NO);
    }
    return self.size;
}

#pragma mark WSIndentableDescription

- (NSString *)descriptionWithIndent:(NSUInteger)indent
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];
    [tokens addObject:[NSString stringWithFormat:@"version = %u", self.version]];
    [tokens addObject:[NSString stringWithFormat:@"id = %@", self.txId]];
    [tokens addObject:[NSString stringWithFormat:@"size = %lu bytes", (unsigned long)self.size]];
    [tokens addObject:[NSString stringWithFormat:@"coinbase = %@", (self.isCoinbase ? @"YES" : @"NO")]];
    [tokens addObject:[NSString stringWithFormat:@"lockTime = %u", self.lockTime]];
    [tokens addObject:[NSString stringWithFormat:@"inputs =\n%@", [self.inputs descriptionWithLocale:nil indent:(indent + 1)]]];
    [tokens addObject:[NSString stringWithFormat:@"outputs =\n%@", [self.outputs descriptionWithLocale:nil indent:(indent + 1)]]];
    return [NSString stringWithFormat:@"{%@}", WSStringDescriptionFromTokens(tokens, indent)];
}

@end

#pragma mark -

@interface WSTransactionBuilder ()

@property (nonatomic, strong) NSMutableOrderedSet *signableInputs;
@property (nonatomic, strong) NSMutableOrderedSet *outputs;

- (WSBuffer *)signableBufferForInput:(WSSignableTransactionInput *)signableInput hashFlags:(WSTransactionSigHash)hashFlags;
- (NSUInteger)estimatedSizeWithExtraInputs:(NSArray *)inputs;

@end

@implementation WSTransactionBuilder

- (instancetype)init
{
    if ((self = [super init])) {
        self.version = WSTransactionVersion;
        self.signableInputs = [[NSMutableOrderedSet alloc] init];
        self.outputs = [[NSMutableOrderedSet alloc] init];
        self.lockTime = WSTransactionDefaultLockTime;
    }
    return self;
}

- (void)addSignableInput:(WSSignableTransactionInput *)signableInput
{
    WSExceptionCheckIllegal(signableInput);
    
    [_signableInputs addObject:signableInput];
}

- (void)addOutput:(WSTransactionOutput *)output
{
    WSExceptionCheckIllegal(output);

    [_outputs addObject:output];
}

- (BOOL)addSweepOutputAddressWithStandardFee:(WSAddress *)address
{
    return [self addSweepOutputAddress:address fee:0];
}

- (BOOL)addSweepOutputAddress:(WSAddress *)address fee:(uint64_t)fee
{
    const uint64_t effectiveFee = (fee ? : [self standardFeeWithExtraOutputs:1]);
    const uint64_t inputValue = [self inputValue];
    if (inputValue < effectiveFee + WSTransactionMinOutValue) {
        return NO;
    }

    const uint64_t outputValue = inputValue - effectiveFee;
    WSTransactionOutput *output = [[WSTransactionOutput alloc] initWithAddress:address value:outputValue];
    [self addOutput:output];
    return YES;
}

- (uint64_t)inputValue
{
    uint64_t value = 0;
    for (WSSignableTransactionInput *input in self.signableInputs) {
        value += input.value;
    }
    return value;
}

- (uint64_t)outputValue
{
    uint64_t value = 0;
    for (WSTransactionOutput *output in self.outputs) {
        value += output.value;
    }
    return value;
}

- (NSUInteger)estimatedSizeWithExtraOutputs:(NSUInteger)numberOfOutputs
{
    return [self estimatedSizeWithExtraInputs:nil outputs:numberOfOutputs];
}

- (NSUInteger)estimatedSizeWithExtraInputs:(NSArray *)inputs outputs:(NSUInteger)numberOfOutputs
{
    if (inputs) {
        return [self estimatedSizeWithExtraInputs:inputs] + (numberOfOutputs * WSTransactionOutputTypicalSize);
    }
    else {
        return [self estimatedSize] + (numberOfOutputs * WSTransactionOutputTypicalSize);
    }
}

- (NSUInteger)estimatedSizeWithExtraBytes:(NSUInteger)numberOfBytes
{
    return [self estimatedSize] + numberOfBytes;
}

- (uint64_t)fee
{
    return [self inputValue] - [self outputValue];
}

- (uint64_t)standardFee
{
    return [self standardFeeWithExtraBytes:0];
}

- (uint64_t)standardFeeWithExtraOutputs:(NSUInteger)numberOfOutputs
{
    return [self standardFeeWithExtraBytes:(numberOfOutputs * WSTransactionOutputTypicalSize)];
}

- (uint64_t)standardFeeWithExtraBytes:(NSUInteger)numberOfBytes
{
    return WSTransactionStandardRelayFee([self estimatedSize] + numberOfBytes);
}

- (WSSignedTransaction *)signedTransactionWithInputKeys:(NSDictionary *)keys error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(keys.count > 0);

    if ((self.signableInputs.count == 0) || (self.outputs.count == 0)) {
        WSErrorSet(error, WSErrorCodeInvalidTransaction, @"Empty inputs or outputs");
        return nil;
    }
    
    const WSTransactionSigHash hashFlags = WSTransactionSigHash_ALL;
    
    NSMutableOrderedSet *signedInputs = [[NSMutableOrderedSet alloc] initWithCapacity:self.signableInputs.count];
    for (WSSignableTransactionInput *input in self.signableInputs) {
        WSAddress *inputAddress = input.address;
        WSKey *key = keys[inputAddress];
        if (!key) {
            WSErrorSetUserInfo(error, WSErrorCodeSignature, @{WSErrorInputAddressKey: inputAddress},
                               @"Missing key for input address %@", inputAddress);

            return nil;
        }

        WSBuffer *buffer = [self signableBufferForInput:input hashFlags:hashFlags];
        WSHash256 *hash256 = [buffer computeHash256];

        WSSignedTransactionInput *signedInput = [input signedInputWithKey:key hash256:hash256 hashFlags:hashFlags];
        [signedInputs addObject:signedInput];
    }
    
    return [[WSSignedTransaction alloc] initWithVersion:self.version signedInputs:signedInputs outputs:self.outputs lockTime:self.lockTime error:error];
}

- (WSBuffer *)signableBufferForInput:(WSSignableTransactionInput *)signableInput hashFlags:(WSTransactionSigHash)hashFlags
{
    NSParameterAssert(signableInput != nil);
    NSAssert([self.signableInputs containsObject:signableInput], @"Transaction doesn't contain this input");

    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] init];

    [buffer appendUint32:self.version];

    [buffer appendVarInt:self.signableInputs.count];
    for (WSSignableTransactionInput *input in self.signableInputs) {
        [input.outpoint appendToMutableBuffer:buffer];

        // include previous output script for the signable input
        if (input == signableInput) {
            [buffer appendVarInt:[signableInput.script estimatedSize]];
            [signableInput.script appendToMutableBuffer:buffer];
        }
        // exclude script from other inputs
        else {
            [buffer appendVarInt:0];
        }

        [buffer appendUint32:input.sequence];
    }

    [buffer appendVarInt:self.outputs.count];
    for (WSTransactionOutput *output in self.outputs) {
        [output appendToMutableBuffer:buffer];
    }

    [buffer appendUint32:self.lockTime];
    [buffer appendUint32:hashFlags];

    return buffer;
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    return WSTransactionEstimatedSize(self.signableInputs, self.outputs, nil, nil, YES);
}

- (NSUInteger)estimatedSizeWithExtraInputs:(NSArray *)inputs
{
    NSParameterAssert(inputs);
    
    return WSTransactionEstimatedSize(self.signableInputs, self.outputs, inputs, nil, YES);
}

@end
