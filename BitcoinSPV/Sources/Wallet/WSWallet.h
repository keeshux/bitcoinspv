//
//  WSWallet.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 28/12/13.
//  Copyright (c) 2013 BitcoinSPV. All rights reserved.
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

#import "WSIndentableDescription.h"

@class WSHash256;
@class WSKey;
@class WSPublicKey;
@class WSAddress;
@class WSTransactionBuilder;
@class WSSignedTransaction;
@class WSStorableBlock;
@class WSFilteredBlock;
@class WSTransactionOutput;
@class WSBloomFilter;
@class WSBIP37FilterParameters;
@class WSTransactionMetadata;

#pragma mark -

extern NSString *const WSWalletDidRegisterTransactionNotification;
extern NSString *const WSWalletDidUnregisterTransactionNotification;
extern NSString *const WSWalletDidUpdateBalanceNotification;
extern NSString *const WSWalletDidUpdateAddressesNotification;
extern NSString *const WSWalletDidUpdateTransactionsMetadataNotification;
extern NSString *const WSWalletTransactionKey;
extern NSString *const WSWalletTransactionsMetadataKey;

//
// thread-safety: required
//
@protocol WSWallet <WSIndentableDescription>

- (NSTimeInterval)creationTime;

// keys / addresses
- (NSSet *)usedAddresses;                   // WSAddress
- (WSAddress *)receiveAddress;
- (WSAddress *)changeAddress;
- (NSOrderedSet *)allReceiveAddresses;      // WSAddress
- (NSOrderedSet *)allChangeAddresses;       // WSAddress
- (WSKey *)privateKeyForAddress:(WSAddress *)address;
- (WSPublicKey *)publicKeyForAddress:(WSAddress *)address;
- (BOOL)isWalletAddress:(WSAddress *)address;

// history
- (NSDictionary *)allTransactions;          // WSHash256 -> WSSignedTransaction
- (NSArray *)sortedTransactions;            // WSSignedTransaction
- (WSSignedTransaction *)transactionForId:(WSHash256 *)txId;
- (NSArray *)transactionsInRange:(NSRange)range;
- (uint64_t)receivedValueFromTransaction:(WSSignedTransaction *)transaction;
- (uint64_t)sentValueByTransaction:(WSSignedTransaction *)transaction;
- (int64_t)valueForTransaction:(WSSignedTransaction *)transaction;
- (uint64_t)feeForTransaction:(WSSignedTransaction *)transaction; // UINT64_MAX if spending any non-wallet input
- (BOOL)isInternalTransaction:(WSSignedTransaction *)transaction;
- (uint64_t)balance;
- (uint64_t)confirmedBalance;
- (NSArray *)unspentOutputs;                // WSTransactionOutPoint
- (WSTransactionMetadata *)metadataForTransactionId:(WSHash256 *)txId;

// spending (fee = 0 for standard fee)
- (WSTransactionBuilder *)buildTransactionToAddress:(WSAddress *)address forValue:(uint64_t)value fee:(uint64_t)fee error:(NSError **)error;
- (WSTransactionBuilder *)buildTransactionToAddresses:(NSArray *)addresses forValues:(NSArray *)values fee:(uint64_t)fee error:(NSError **)error; // NSNumber, WSAddress
- (WSTransactionBuilder *)buildTransactionWithOutputs:(NSOrderedSet *)outputs fee:(uint64_t)fee error:(NSError **)error;
- (WSTransactionBuilder *)buildSweepTransactionToAddress:(WSAddress *)address fee:(uint64_t)fee error:(NSError **)error;
- (WSSignedTransaction *)signedTransactionWithBuilder:(WSTransactionBuilder *)builder error:(NSError **)error;

// serialization (sensitive data should be excluded and saved by other means)
- (BOOL)saveToPath:(NSString *)path;
- (BOOL)save;
- (BOOL)shouldAutoSave;
- (void)setShouldAutoSave:(BOOL)shouldAutoSave;
- (BOOL)maySpendUnconfirmed;
- (void)setMaySpendUnconfirmed:(BOOL)maySpendUnconfirmed;

@end

#pragma mark -

@protocol WSSynchronizableWallet <WSWallet>

- (uint32_t)earliestKeyTimestamp;
- (BOOL)generateAddressesIfNeeded;
- (BOOL)generateAddressesWithLookAhead:(NSUInteger)lookAhead;
- (WSBloomFilter *)bloomFilterWithParameters:(WSBIP37FilterParameters *)parameters;
- (BOOL)isCoveredByBloomFilter:(WSBloomFilter *)bloomFilter;
- (BOOL)isRelevantTransaction:(WSSignedTransaction *)transaction;
- (BOOL)isRelevantTransaction:(WSSignedTransaction *)transaction savingReceivingAddresses:(NSMutableSet *)receivingAddresses;
- (BOOL)registerTransaction:(WSSignedTransaction *)transaction didGenerateNewAddresses:(BOOL *)didGenerateNewAddresses;
- (BOOL)unregisterTransaction:(WSSignedTransaction *)transaction;
- (NSDictionary *)registerBlock:(WSStorableBlock *)block matchingFilteredBlock:(WSFilteredBlock *)filteredBlock;
- (NSDictionary *)unregisterBlock:(WSStorableBlock *)block;
- (void)reorganizeWithOldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks didGenerateNewAddresses:(BOOL *)didGenerateNewAddresses;
- (void)removeAllTransactions;

@end
