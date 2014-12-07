//
//  WSTransaction.h
//  WaSPV
//
//  Created by Davide De Rosa on 08/06/14.
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

#import "WSBuffer.h"
#import "WSSized.h"
#import "WSIndentableDescription.h"

@class WSHash256;
@protocol WSTransactionInput;
@class WSSignedTransactionInput;
@class WSSignableTransactionInput;
@class WSTransactionOutput;
@class WSAddress;

#pragma mark -

@protocol WSTransaction <NSObject>

- (uint32_t)version;
- (NSOrderedSet *)inputs;   // id<WSTransactionInput>
- (NSOrderedSet *)outputs;  // WSTransactionOutput
- (uint32_t)lockTime;

- (WSHash256 *)txId;
- (BOOL)isCoinbase;

@end

#pragma mark -

@interface WSSignedTransaction : NSObject <WSTransaction, WSBufferEncoder, WSBufferDecoder, WSSized, WSIndentableDescription>

- (instancetype)initWithSignedInputs:(NSOrderedSet *)inputs outputs:(NSOrderedSet *)outputs error:(NSError **)error;
- (instancetype)initWithVersion:(uint32_t)version
                   signedInputs:(NSOrderedSet *)inputs      // WSSignedTransactionInput
                        outputs:(NSOrderedSet *)outputs     // WSTransactionOutput
                       lockTime:(uint32_t)lockTime
                          error:(NSError **)error;

- (NSUInteger)size;
- (WSSignedTransactionInput *)signedInputAtIndex:(uint32_t)index;
- (WSTransactionOutput *)outputAtIndex:(uint32_t)index;

- (NSSet *)inputTxIds; // WSHash256
- (NSSet *)outputAddresses; // WSAddress
- (uint64_t)outputValue;

@end

#pragma mark -

@interface WSTransactionBuilder : NSObject <WSSized>

@property (nonatomic, assign) uint32_t version;     // WSTransactionVersion
@property (nonatomic, assign) uint32_t lockTime;    // WSTransactionDefaultLockTime

- (instancetype)init;

- (void)addSignableInput:(WSSignableTransactionInput *)signableInput;
- (void)addOutput:(WSTransactionOutput *)output;
- (NSOrderedSet *)signableInputs; // WSSignableTransactionInput
- (NSOrderedSet *)outputs; // WSTransactionOutput

- (uint64_t)inputValue;
- (uint64_t)outputValue;
- (uint64_t)fee;
- (uint64_t)standardFee;
- (uint64_t)standardFeeWithExtraOutputs:(NSUInteger)numberOfOutputs;
- (uint64_t)standardFeeWithExtraBytes:(NSUInteger)numberOfBytes;

// fee = 0 for standard fee
- (void)addWipeOutputAddressWithStandardFee:(WSAddress *)address;
- (void)addWipeOutputAddress:(WSAddress *)address fee:(uint64_t)fee;

- (WSSignedTransaction *)signedTransactionWithInputKeys:(NSOrderedSet *)keys error:(NSError **)error;

@end
