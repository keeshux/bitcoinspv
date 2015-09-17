//
//  WSTransactionInput.h
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

#import <Foundation/Foundation.h>

#import "WSBuffer.h"
#import "WSSized.h"
#import "WSBitcoinConstants.h"

@class WSHash256;
@class WSScript;
@class WSAddress;
@class WSTransactionOutPoint;
@class WSTransactionOutput;
@class WSSignedTransactionInput;
@class WSSignedTransaction;
@class WSKey;
@class WSPublicKey;

#pragma mark -

@protocol WSTransactionInput <NSObject>

- (WSParameters *)parameters;
- (WSTransactionOutPoint *)outpoint;
- (WSScript *)script;
- (uint32_t)sequence;

- (BOOL)isCoinbase;
- (BOOL)isSigned;
- (WSAddress *)address; // nil if script is not standard

@end

#pragma mark -

@interface WSSignedTransactionInput : NSObject <WSTransactionInput, WSBufferEncoder, WSBufferDecoder, WSSized>

- (instancetype)initWithOutpoint:(WSTransactionOutPoint *)outpoint signature:(NSData *)signature publicKey:(WSPublicKey *)publicKey;
- (instancetype)initWithOutpoint:(WSTransactionOutPoint *)outpoint signature:(NSData *)signature publicKey:(WSPublicKey *)publicKey sequence:(uint32_t)sequence;
- (instancetype)initWithOutpoint:(WSTransactionOutPoint *)outpoint script:(WSScript *)script;
- (instancetype)initWithOutpoint:(WSTransactionOutPoint *)outpoint script:(WSScript *)script sequence:(uint32_t)sequence;

@end

#pragma mark -

@interface WSSignableTransactionInput : NSObject <WSTransactionInput, WSSized>

- (instancetype)initWithPreviousTransaction:(WSSignedTransaction *)previousTransaction outputIndex:(uint32_t)outputIndex;
- (instancetype)initWithPreviousTransaction:(WSSignedTransaction *)previousTransaction outputIndex:(uint32_t)outputIndex sequence:(uint32_t)sequence;

// should only use for testing
- (instancetype)initWithPreviousOutput:(WSTransactionOutput *)previousOutput outpoint:(WSTransactionOutPoint *)outpoint;
- (instancetype)initWithPreviousOutput:(WSTransactionOutput *)previousOutput outpoint:(WSTransactionOutPoint *)outpoint sequence:(uint32_t)sequence;

- (WSTransactionOutput *)previousOutput;
- (uint64_t)value;
- (WSSignedTransactionInput *)signedInputWithKey:(WSKey *)key hash256:(WSHash256 *)hash256; // WSTransactionSigHash_ALL
- (WSSignedTransactionInput *)signedInputWithKey:(WSKey *)key hash256:(WSHash256 *)hash256 hashFlags:(WSTransactionSigHash)hashFlags;

@end
