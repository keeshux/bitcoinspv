//
//  WSWallet.h
//  WaSPV
//
//  Created by Davide De Rosa on 28/12/13.
//  Copyright (c) 2013 WaSPV. All rights reserved.
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

#import "WSIndentableDescription.h"

@class WSHash256;
@class WSKey;
@class WSPublicKey;
@class WSAddress;
@class WSTransactionBuilder;
@class WSSignedTransaction;
@class WSStorableBlock;
@class WSTransactionOutput;
@class WSBloomFilter;
@class WSBIP37FilterParameters;
@class WSTransactionMetadata;

#pragma mark -

extern NSString *const WSWalletDidRegisterTransactionNotification;
extern NSString *const WSWalletDidUnregisterTransactionNotification;
extern NSString *const WSWalletDidUpdateBalanceNotification;
extern NSString *const WSWalletDidUpdateReceiveAddressNotification;
extern NSString *const WSWalletDidUpdateTransactionsMetadataNotification;
extern NSString *const WSWalletTransactionKey;
extern NSString *const WSWalletTransactionsMetadataKey;

//
// must be thread-safe
//
@protocol WSWallet <WSIndentableDescription>

- (NSTimeInterval)creationTime;

// keys / addresses
- (NSSet *)usedAddresses;                   // WSAddress
- (WSAddress *)receiveAddress;
- (WSAddress *)changeAddress;
- (NSOrderedSet *)allReceiveAddresses;      // WSAddress
- (NSOrderedSet *)allChangeAddresses;       // WSAddress
- (NSOrderedSet *)allAddresses;             // WSAddress
- (WSKey *)privateKeyForAddress:(WSAddress *)address;
- (WSPublicKey *)publicKeyForAddress:(WSAddress *)address;

// history
- (NSArray *)allTransactions; // recent first
- (NSArray *)transactionsInRange:(NSRange)range;
//- (uint64_t)amountReceivedFromTransaction:(WSSignedTransaction *)transaction;
//- (uint64_t)amountSentByTransaction:(WSSignedTransaction *)transaction;
- (uint64_t)balance;
- (WSTransactionMetadata *)metadataForTransactionId:(WSHash256 *)txId;

// spending (fee = 0 for standard fee)
- (WSTransactionBuilder *)buildTransactionToAddress:(WSAddress *)address forValue:(uint64_t)value fee:(uint64_t)fee error:(NSError **)error;
- (WSTransactionBuilder *)buildTransactionToAddresses:(NSArray *)addresses forValues:(NSArray *)values fee:(uint64_t)fee error:(NSError **)error; // NSNumber, WSAddress
- (WSTransactionBuilder *)buildTransactionWithOutputs:(NSOrderedSet *)outputs fee:(uint64_t)fee error:(NSError **)error;
- (WSTransactionBuilder *)buildWipeTransactionToAddress:(WSAddress *)address fee:(uint64_t)fee error:(NSError **)error;
- (WSSignedTransaction *)signedTransactionWithBuilder:(WSTransactionBuilder *)builder error:(NSError **)error;

// serialization (sensitive data should be excluded and saved by other means)
- (BOOL)saveToPath:(NSString *)path;
- (BOOL)save;
- (BOOL)shouldAutosave;
- (void)setShouldAutosave:(BOOL)shouldAutosave;

@end

#pragma mark -

@protocol WSSynchronizableWallet <NSObject>

- (uint32_t)earliestKeyTimestamp;
- (BOOL)generateAddressesIfNeeded;
- (WSBloomFilter *)bloomFilterWithParameters:(WSBIP37FilterParameters *)parameters;
- (BOOL)isRelevantTransaction:(WSSignedTransaction *)transaction;
- (BOOL)isRelevantTransaction:(WSSignedTransaction *)transaction savingReceivingAddresses:(NSMutableSet *)receivingAddresses;
- (BOOL)registerTransaction:(WSSignedTransaction *)transaction didGenerateNewAddresses:(BOOL *)didGenerateNewAddresses;
- (BOOL)unregisterTransaction:(WSSignedTransaction *)transaction;
- (NSDictionary *)registerBlock:(WSStorableBlock *)block networkHeight:(NSUInteger)networkHeight;
- (NSDictionary *)unregisterBlock:(WSStorableBlock *)block;
- (void)reorganizeWithOldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks didGenerateNewAddresses:(BOOL *)didGenerateNewAddresses;

@end
