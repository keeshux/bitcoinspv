//
//  WSTransactionInput.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 26/07/14.
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

#import "WSTransactionInput.h"
#import "WSTransactionOutPoint.h"
#import "WSTransactionOutput.h"
#import "WSTransaction.h"
#import "WSScript.h"
#import "WSKey.h"
#import "WSPublicKey.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSSignedTransactionInput ()

@property (nonatomic, strong) WSTransactionOutPoint *outpoint;
@property (nonatomic, strong) WSScript *script;
@property (nonatomic, assign) uint32_t sequence;

@end

@implementation WSSignedTransactionInput

- (instancetype)initWithOutpoint:(WSTransactionOutPoint *)outpoint signature:(NSData *)signature publicKey:(WSPublicKey *)publicKey
{
    return [self initWithOutpoint:outpoint signature:signature publicKey:publicKey sequence:WSTransactionInputDefaultSequence];
}

- (instancetype)initWithOutpoint:(WSTransactionOutPoint *)outpoint signature:(NSData *)signature publicKey:(WSPublicKey *)publicKey sequence:(uint32_t)sequence
{
    WSExceptionCheckIllegal(signature);
    WSExceptionCheckIllegal(publicKey);

    return [self initWithOutpoint:outpoint script:[WSScript scriptWithSignature:signature publicKey:publicKey] sequence:sequence];
}

- (instancetype)initWithOutpoint:(WSTransactionOutPoint *)outpoint script:(WSScript *)script
{
    return [self initWithOutpoint:outpoint script:script sequence:WSTransactionInputDefaultSequence];
}

- (instancetype)initWithOutpoint:(WSTransactionOutPoint *)outpoint script:(WSScript *)script sequence:(uint32_t)sequence
{
    WSExceptionCheckIllegal(outpoint);
    WSExceptionCheckIllegal(script);
    
    if ((self = [super init])) {
        self.outpoint = outpoint;
        self.script = script;
        self.sequence = sequence;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"{%@outpoint=%@, script='%@', sequence=0x%x}",
            WSStringOptional([self address], @"address='%@', "),
            self.outpoint, self.script, self.sequence];
}

#pragma mark WSTransactionInput

- (WSParameters *)parameters
{
    return self.outpoint.parameters;
}

- (BOOL)isCoinbase
{
    return [self.outpoint isCoinbase];
}

- (BOOL)isSigned
{
    return YES;
}

- (WSAddress *)address
{
    return [self.script standardInputAddressWithParameters:self.outpoint.parameters];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [self.outpoint appendToMutableBuffer:buffer];
    [buffer appendVarInt:[self.script estimatedSize]];
    [self.script appendToMutableBuffer:buffer];
    [buffer appendUint32:self.sequence];
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
    NSUInteger varIntLength;
    
    WSTransactionOutPoint *outpoint = [[WSTransactionOutPoint alloc] initWithParameters:parameters buffer:buffer from:offset available:WSTransactionOutPointSize error:error];
    if (!outpoint) {
        return nil;
    }
    offset += WSTransactionOutPointSize;
    
    const NSUInteger scriptLength = (NSUInteger)[buffer varIntAtOffset:offset length:&varIntLength];
    offset += varIntLength;
    
    WSScript *script = nil;
    if ([outpoint isCoinbase]) {
        script = [[WSCoinbaseScript alloc] initWithParameters:parameters buffer:buffer from:offset available:scriptLength error:error];
    }
    else {
        script = [[WSScript alloc] initWithParameters:parameters buffer:buffer from:offset available:scriptLength error:error];
    }
    if (!script) {
        return nil;
    }
    offset += scriptLength;
    
    const uint32_t sequence = [buffer uint32AtOffset:offset];
    
    return [self initWithOutpoint:outpoint script:script sequence:sequence];
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    const NSUInteger scriptSize = [self.script estimatedSize];
    
    // outpoint + var_int + script + sequence
    return [self.outpoint estimatedSize] + WSBufferVarIntSize(scriptSize) + scriptSize + 4;
}

@end

#pragma mark -

@interface WSSignableTransactionInput ()

@property (nonatomic, strong) WSTransactionOutput *previousOutput;
@property (nonatomic, strong) WSTransactionOutPoint *outpoint;
@property (nonatomic, assign) uint32_t sequence;

@end

@implementation WSSignableTransactionInput

- (instancetype)initWithPreviousTransaction:(WSSignedTransaction *)previousTransaction outputIndex:(uint32_t)outputIndex
{
    return [self initWithPreviousTransaction:previousTransaction outputIndex:outputIndex sequence:WSTransactionInputDefaultSequence];
}

- (instancetype)initWithPreviousTransaction:(WSSignedTransaction *)previousTransaction outputIndex:(uint32_t)outputIndex sequence:(uint32_t)sequence
{
    WSExceptionCheckIllegal(previousTransaction);
    
    WSTransactionOutput *previousOutput = [previousTransaction outputAtIndex:outputIndex];
    WSTransactionOutPoint *outpoint = [WSTransactionOutPoint outpointWithParameters:previousOutput.parameters txId:previousTransaction.txId index:outputIndex];

    return [self initWithPreviousOutput:previousOutput outpoint:outpoint sequence:sequence];
}

- (instancetype)initWithPreviousOutput:(WSTransactionOutput *)previousOutput outpoint:(WSTransactionOutPoint *)outpoint
{
    return [self initWithPreviousOutput:previousOutput outpoint:outpoint sequence:WSTransactionInputDefaultSequence];
}

- (instancetype)initWithPreviousOutput:(WSTransactionOutput *)previousOutput outpoint:(WSTransactionOutPoint *)outpoint sequence:(uint32_t)sequence
{
    WSExceptionCheckIllegal(previousOutput);
    WSExceptionCheckIllegal(outpoint);
    
    if ((self = [super init])) {
        self.previousOutput = previousOutput;
        self.outpoint = outpoint;
        self.sequence = sequence;
    }
    return self;
}

- (uint64_t)value
{
    return self.previousOutput.value;
}

- (WSSignedTransactionInput *)signedInputWithKey:(WSKey *)key hash256:(WSHash256 *)hash256
{
    return [self signedInputWithKey:key hash256:hash256 hashFlags:WSTransactionSigHash_ALL];
}

- (WSSignedTransactionInput *)signedInputWithKey:(WSKey *)key hash256:(WSHash256 *)hash256 hashFlags:(WSTransactionSigHash)hashFlags
{
    WSExceptionCheckIllegal(key);
    WSExceptionCheckIllegal(hash256);

    NSMutableData *signature = [[key signatureForHash256:hash256] mutableCopy];

    const uint8_t suffix = hashFlags;
    [signature appendBytes:&suffix length:1];

    return [[WSSignedTransactionInput alloc] initWithOutpoint:self.outpoint
                                                    signature:signature
                                                    publicKey:[key publicKey]
                                                     sequence:self.sequence];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"{address='%@', value='%llu', outpoint=%@, script='%@'}",
            self.address, self.value, self.outpoint, self.script];
}

#pragma mark WSTransactionInput

- (WSParameters *)parameters
{
    return self.previousOutput.parameters;
}

- (WSScript *)script
{
    return self.previousOutput.script;
}

- (BOOL)isCoinbase
{
    return [self.outpoint isCoinbase];
}

- (BOOL)isSigned
{
    return NO;
}

- (WSAddress *)address
{
    return self.previousOutput.address;
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    const NSUInteger scriptSize = [self.script estimatedSize];
    
    // outpoint + var_int + script + sequence
    return [self.outpoint estimatedSize] + WSBufferVarIntSize(scriptSize) + scriptSize + 4;
}

@end
