//
//  WSHDWallet.m
//  WaSPV
//
//  Created by Davide De Rosa on 22/07/14.
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
#import "AutoCoding.h"

#import "WSHDWallet.h"
#import "WSSeed.h"
#import "WSHash256.h"
#import "WSHDKeyring.h"
#import "WSTransactionOutPoint.h"
#import "WSTransactionInput.h"
#import "WSTransactionOutput.h"
#import "WSTransaction.h"
#import "WSBloomFilter.h"
#import "WSPublicKey.h"
#import "WSScript.h"
#import "WSStorableBlock.h"
#import "WSTransactionMetadata.h"
#import "WSParametersFactory.h"
#import "WSConfig.h"
#import "WSBitcoin.h"
#import "WSMacros.h"
#import "WSErrors.h"

@interface WSHDWallet () {

    // essential backup data
    WSParametersType _parametersType;
    NSTimeInterval _creationTime;
    NSUInteger _gapLimit;

    // serialized for convenience
    uint32_t _currentAccount;
    NSMutableOrderedSet *_txs;                          // WSSignedTransaction
    NSMutableSet *_usedAddresses;                       // WSAddress
    NSMutableDictionary *_metadataByTxId;               // WSHash256 -> WSTransactionMetadata

    // transient
    WSSeed *_seed;
    NSString *_path;
    id<WSBIP32Keyring> _keyring;
    id<WSBIP32Keyring> _externalChain;
    id<WSBIP32Keyring> _internalChain;
    NSMutableOrderedSet *_allExternalAddresses;         // WSAddress
    NSMutableOrderedSet *_allInternalAddresses;         // WSAddress
    NSMutableOrderedSet *_allAddresses;                 // WSAddress
    NSMutableDictionary *_txsById;                      // WSHash256 -> WSSignedTransaction
    NSSet *_spentOutputs;                               // WSTransactionOutPoint
    NSOrderedSet *_unspentOutputs;                      // WSTransactionOutPoint
    NSSet *_invalidTxIds;                               // WSHash256
    uint64_t _balance;
}

- (void)rebuildTransientStructuresWithSeed:(WSSeed *)seed;
- (void)generateAddressesForAccount:(uint32_t)account;
- (void)cleanTransientStructures;

//
// if (batch == YES)
//
// - transactions are not sorted
// - balance is not updated
// - notifications are disabled
//
- (BOOL)registerTransaction:(WSSignedTransaction *)transaction didGenerateNewAddresses:(BOOL *)didGenerateNewAddresses batch:(BOOL)batch;
- (BOOL)unregisterTransaction:(WSSignedTransaction *)transaction batch:(BOOL)batch;
- (NSDictionary *)registerBlock:(WSStorableBlock *)block batch:(BOOL)batch;
- (NSDictionary *)unregisterBlock:(WSStorableBlock *)block batch:(BOOL)batch;
- (void)sortTransactions;
- (void)recalculateSpendsAndBalance;

- (void)setPath:(NSString *)path;

- (WSTransactionOutput *)previousOutputFromInput:(WSSignedTransactionInput *)input;
- (WSSignedTransaction *)signedTransactionWithBuilder:(WSTransactionBuilder *)builder error:(NSError *__autoreleasing *)error;
- (void)notifyWithName:(NSString *)name userInfo:(NSDictionary *)userInfo;

@end

@implementation WSHDWallet

- (instancetype)initWithSeed:(WSSeed *)seed
{
    return [self initWithSeed:seed gapLimit:WSHDWalletDefaultGapLimit];
}

- (instancetype)initWithSeed:(WSSeed *)seed gapLimit:(NSUInteger)gapLimit
{
    WSExceptionCheckIllegal(seed != nil, @"Nil seed");
    WSExceptionCheckIllegal(gapLimit > 0, @"Non-positive gapLimit");
    
    if ((self = [self init])) {
        _parametersType = WSParametersGetCurrentType();
        _creationTime = seed.creationTime;
        _gapLimit = gapLimit;

        _currentAccount = 0;
        _txs = [[NSMutableOrderedSet alloc] init];
        _usedAddresses = [[NSMutableSet alloc] init];
        _metadataByTxId = [[NSMutableDictionary alloc] init];

        [self rebuildTransientStructuresWithSeed:seed];
    }
    return self;
}

- (WSSeed *)seed
{
    @synchronized (self) {
        return _seed;
    }
}

- (NSUInteger)gapLimit
{
    @synchronized (self) {
        return _gapLimit;
    }
}

- (uint32_t)currentAccount
{
    @synchronized (self) {
        return _currentAccount;
    }
}

- (void)rebuildTransientStructuresWithSeed:(WSSeed *)seed
{
    @synchronized (self) {
        const NSTimeInterval rebuildStartTime = [NSDate timeIntervalSinceReferenceDate];
        
        _seed = seed;
        _keyring = [[WSHDKeyring alloc] initWithData:[seed derivedKeyData]];
        _externalChain = [_keyring chainForAccount:0 internal:NO];
        _internalChain = [_keyring chainForAccount:0 internal:YES];
        
        const NSUInteger numberOfAddresses = self.currentAccount + 1;
        _allExternalAddresses = [[NSMutableOrderedSet alloc] initWithCapacity:numberOfAddresses];
        _allInternalAddresses = [[NSMutableOrderedSet alloc] initWithCapacity:numberOfAddresses];
        _allAddresses = [[NSMutableOrderedSet alloc] initWithCapacity:(2 * numberOfAddresses)];
        for (uint32_t i = 0; i <= self.currentAccount; ++i) {
            [self generateAddressesForAccount:i];
        }
        
        _txsById = [[NSMutableDictionary alloc] initWithCapacity:_txs.count];
        for (WSSignedTransaction *tx in _txs) {
            _txsById[tx.txId] = tx;
        }
        
        [self recalculateSpendsAndBalance];
        [self generateAddressesIfNeeded];
        
        const NSTimeInterval rebuildTime = [NSDate timeIntervalSinceReferenceDate] - rebuildStartTime;
        DDLogDebug(@"Rebuilt wallet transient structures in %.3fs", rebuildTime);
    }
}

- (void)generateAddressesForAccount:(uint32_t)account
{
    @synchronized (self) {
        WSAddress *receiveAddress = [[_externalChain publicKeyForAccount:account] address];
        WSAddress *changeAddress = [[_internalChain publicKeyForAccount:account] address];
        
        [_allExternalAddresses addObject:receiveAddress];
        [_allInternalAddresses addObject:changeAddress];
        [_allAddresses addObject:receiveAddress];
        [_allAddresses addObject:changeAddress];
    }
}

- (void)cleanTransientStructures
{
    @synchronized (self) {
        _keyring = nil;
        _externalChain = nil;
        _internalChain = nil;
        _allExternalAddresses = nil;
        _allInternalAddresses = nil;
        _allAddresses = nil;
        _txsById = nil;
        _spentOutputs = nil;
        _unspentOutputs = nil;
        _invalidTxIds = nil;
        _balance = 0;
    }
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

#pragma mark Access

- (NSTimeInterval)creationTime
{
    @synchronized (self) {
        return _creationTime;
    }
}

#pragma mark Keys / Addresses

- (NSSet *)usedAddresses
{
    @synchronized (self) {
        return [_usedAddresses copy];
    }
}

- (WSKey *)privateKeyForAddress:(WSAddress *)address
{
    @synchronized (self) {
        WSExceptionCheckIllegal(address != nil, @"Nil address");

        const NSUInteger externalAccount = [_allExternalAddresses indexOfObject:address];
        if (externalAccount != NSNotFound) {
            return [_externalChain privateKeyForAccount:(uint32_t)externalAccount];
        }

        const NSUInteger internalAccount = [_allInternalAddresses indexOfObject:address];
        if (internalAccount != NSNotFound) {
            return [_internalChain privateKeyForAccount:(uint32_t)internalAccount];
        }

        return nil;
    }
}

- (WSPublicKey *)publicKeyForAddress:(WSAddress *)address
{
    @synchronized (self) {
        WSExceptionCheckIllegal(address != nil, @"Nil address");
    
        const NSUInteger externalAccount = [_allExternalAddresses indexOfObject:address];
        if (externalAccount != NSNotFound) {
            return [_externalChain publicKeyForAccount:(uint32_t)externalAccount];
        }
        
        const NSUInteger internalAccount = [_allInternalAddresses indexOfObject:address];
        if (internalAccount != NSNotFound) {
            return [_internalChain publicKeyForAccount:(uint32_t)internalAccount];
        }
        
        return nil;
    }
}

- (WSAddress *)receiveAddress
{
    @synchronized (self) {
        return [[_externalChain publicKeyForAccount:self.currentAccount] address];
    }
}

- (WSAddress *)changeAddress
{
    @synchronized (self) {
        return [[_internalChain publicKeyForAccount:self.currentAccount] address];
    }
}

- (NSOrderedSet *)allReceiveAddresses
{
    @synchronized (self) {
        return [_allExternalAddresses copy];
    }
}

- (NSOrderedSet *)allChangeAddresses
{
    @synchronized (self) {
        return [_allInternalAddresses copy];
    }
}

- (NSOrderedSet *)allAddresses
{
    @synchronized (self) {
        NSMutableOrderedSet *allAddresses = [[NSMutableOrderedSet alloc] initWithCapacity:(_allExternalAddresses.count + _allInternalAddresses.count)];
        [allAddresses unionOrderedSet:_allExternalAddresses];
        [allAddresses unionOrderedSet:_allInternalAddresses];
        return allAddresses;
    }
}

#pragma mark History

- (NSArray *)allTransactions
{
    @synchronized (self) {
        return [_txs array];
    }
}

- (NSArray *)transactionsInRange:(NSRange)range
{
    @synchronized (self) {
        NSMutableArray *txs = [[NSMutableArray alloc] init];
        const NSUInteger last = MIN(range.location + range.length, _txs.count);
        for (NSUInteger i = range.location; i < last; ++i) {
            [txs addObject:_txs[i]];
        }
        return txs;
    }
}

- (uint64_t)receivedValueFromTransaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");
    
    @synchronized (self) {
        uint64_t value = 0;
        for (WSTransactionOutput *output in transaction.outputs) {
            if ([self.usedAddresses containsObject:output.address]) {
                value += output.value;
            }
        }
        return value;
    }
}

- (uint64_t)sentValueByTransaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");

    @synchronized (self) {
        uint64_t value = 0;
        for (WSSignedTransactionInput *input in transaction.inputs) {
            WSTransactionOutput *previousOutput = [self previousOutputFromInput:input];

            if ([self.usedAddresses containsObject:previousOutput.address]) {
                value += previousOutput.value;
            }
        }
        return value;
    }
}

- (int64_t)valueForTransaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");

    @synchronized (self) {
        return [self receivedValueFromTransaction:transaction] - [self sentValueByTransaction:transaction];
    }
}

- (uint64_t)feeForTransaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");
    
    @synchronized (self) {
        uint64_t fee = 0;

        for (WSSignedTransactionInput *input in transaction.inputs) {
            WSTransactionOutput *previousOutput = [self previousOutputFromInput:input];
            
            if (![self.usedAddresses containsObject:previousOutput.address]) {
                return UINT64_MAX;
            }
            fee += previousOutput.value;
        }

        for (WSTransactionOutput *output in transaction.outputs) {
            fee -= output.value;
        }

        return fee;
    }
}

- (BOOL)isInternalTransaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");

    @synchronized (self) {
        for (WSTransactionOutput *output in transaction.outputs) {
            if (![self.usedAddresses containsObject:output.address]) {
                return NO;
            }
        }

        for (WSSignedTransactionInput *input in transaction.inputs) {
            WSTransactionOutput *previousOutput = [self previousOutputFromInput:input];

            if (![self.usedAddresses containsObject:previousOutput.address]) {
                return NO;
            }
        }

        return YES;
    }
}

- (uint64_t)balance
{
    @synchronized (self) {
        return _balance;
    }
}

- (WSTransactionMetadata *)metadataForTransactionId:(WSHash256 *)txId
{
    @synchronized (self) {
        WSExceptionCheckIllegal(txId != nil, @"Nil txId");
        
        return _metadataByTxId[txId];
    }
}

#pragma mark Spending

- (WSTransactionOutput *)previousOutputFromInput:(WSSignedTransactionInput *)input
{
    WSSignedTransaction *previousTx = _txsById[input.outpoint.txId];
    if (!previousTx) {
        return nil;
    }
    return [previousTx outputAtIndex:input.outpoint.index];
}

- (WSTransactionBuilder *)buildTransactionToAddress:(WSAddress *)address forValue:(uint64_t)value fee:(uint64_t)fee error:(NSError *__autoreleasing *)error
{
    @synchronized (self) {
        WSExceptionCheckIllegal(address != nil, @"Nil address");
        WSExceptionCheckIllegal(value > 0, @"Zero value");

        WSTransactionOutput *output = [[WSTransactionOutput alloc] initWithValue:value address:address];
        return [self buildTransactionWithOutputs:[NSOrderedSet orderedSetWithObject:output] fee:fee error:error];
    }
}

- (WSTransactionBuilder *)buildTransactionToAddresses:(NSArray *)addresses forValues:(NSArray *)values fee:(uint64_t)fee error:(NSError *__autoreleasing *)error
{
    @synchronized (self) {
        WSExceptionCheckIllegal(addresses.count > 0, @"Empty addresses");
        WSExceptionCheckIllegal(values.count == addresses.count, @"Values count must match addresses count");
        
        uint64_t totalValue = 0;
        for (NSNumber *value in values) {
            totalValue += [value unsignedLongLongValue];
        }
        WSExceptionCheckIllegal(totalValue > 0, @"Zero total value");

        NSMutableOrderedSet *outputs = [[NSMutableOrderedSet alloc] initWithCapacity:values.count];
        NSUInteger i = 0;
        for (NSNumber *valueNumber in values) {
            const uint64_t value = [valueNumber unsignedLongLongValue];
            WSAddress *address = addresses[i];
            
            WSTransactionOutput *output = [[WSTransactionOutput alloc] initWithValue:value address:address];
            [outputs addObject:output];
            
            ++i;
        }
        return [self buildTransactionWithOutputs:outputs fee:fee error:error];
    }
}

- (WSTransactionBuilder *)buildTransactionWithOutputs:(NSOrderedSet *)outputs fee:(uint64_t)fee error:(NSError *__autoreleasing *)error
{
    @synchronized (self) {
        WSExceptionCheckIllegal(outputs.count > 0, @"Empty outputs");

        if (self.balance == 0) {
            WSErrorSet(error, WSErrorCodeInsufficientFunds, @"Wallet is empty");
            return nil;
        }

        WSTransactionBuilder *builder = [[WSTransactionBuilder alloc] init];
        
        uint64_t needed = 0;
        for (WSTransactionOutput *output in outputs) {
            [builder addOutput:output];
            needed += output.value;
        }
        uint64_t gathered = 0;
        uint64_t effectiveFee = 0;

        for (WSTransactionOutPoint *utxo in _unspentOutputs) {
            WSSignedTransaction *unspentTx = _txsById[utxo.txId];
            NSAssert(unspentTx, @"Unspent outputs must only point to wallet transactions, or txsById wasn't rebuilt correctly");
            
            WSSignableTransactionInput *input = [[WSSignableTransactionInput alloc] initWithPreviousTransaction:unspentTx
                                                                                                    outputIndex:utxo.index];

            [builder addSignableInput:input];
            gathered += input.value;
            
            // add change bytes added below
            const uint64_t standardFee = [builder standardFeeWithExtraBytes:WSTransactionOutputTypicalLength];
            effectiveFee = MAX(fee, standardFee);
            if ((gathered == needed + effectiveFee) || (gathered >= needed + effectiveFee + WSTransactionMinOutValue)) {
                break;
            }
        }
        
        if (gathered < needed + effectiveFee) {
            WSErrorSet(error, WSErrorCodeInsufficientFunds, @"Insufficient funds (%llu < %llu + fee(%llu))",
                       gathered, needed, effectiveFee);

            return nil;
        }
        
        const uint64_t change = gathered - (needed + effectiveFee);
        if (change >= WSTransactionMinOutValue) {
            WSTransactionOutput *output = [[WSTransactionOutput alloc] initWithValue:change address:self.changeAddress];
            [builder addOutput:output];
        }
        else {
            // dust change, lost as additional fee
        }
    
        return builder;
    }
}

- (WSTransactionBuilder *)buildWipeTransactionToAddress:(WSAddress *)address fee:(uint64_t)fee error:(NSError *__autoreleasing *)error
{
    @synchronized (self) {
        WSExceptionCheckIllegal(address != nil, @"Nil address");

        if (self.balance == 0) {
            WSErrorSet(error, WSErrorCodeInsufficientFunds, @"Wallet is empty");
            return nil;
        }
        
        WSTransactionBuilder *builder = [[WSTransactionBuilder alloc] init];
        uint64_t gathered = 0;

        for (WSTransactionOutPoint *utxo in _unspentOutputs) {
            WSSignedTransaction *unspentTx = _txsById[utxo.txId];
            NSAssert(unspentTx, @"Unspent outputs must only point to wallet transactions, or txsById wasn't rebuilt correctly");
            
            WSSignableTransactionInput *input = [[WSSignableTransactionInput alloc] initWithPreviousTransaction:unspentTx
                                                                                                    outputIndex:utxo.index];

            [builder addSignableInput:input];
            gathered += input.value;
        }
        
        // we know by construction that we're adding typical inputs/outputs, so fee is predictable
        const NSUInteger estimatedTxSize = WSTransactionTypicalSize(builder.signableInputs.count, 1);
        const uint64_t effectiveFee = MAX(fee, WSTransactionStandardRelayFee(estimatedTxSize));
        
        WSTransactionOutput *output = [[WSTransactionOutput alloc] initWithValue:(gathered - effectiveFee) address:address];
        [builder addOutput:output];
        
        NSAssert(gathered == self.balance, @"Transaction doesn't spend full balance (%llu != %llu)",
                 gathered, self.balance);
        
        return builder;
    }
}

- (WSSignedTransaction *)signedTransactionWithBuilder:(WSTransactionBuilder *)builder error:(NSError *__autoreleasing *)error
{
    @synchronized (self) {
        NSMutableOrderedSet *keys = [[NSMutableOrderedSet alloc] initWithCapacity:builder.signableInputs.count];

        for (WSSignableTransactionInput *input in builder.signableInputs) {
            WSKey *key = [self privateKeyForAddress:input.address];
            if (!key) {
                const NSUInteger index = keys.count;
                WSErrorSet(error, WSErrorCodeSignature, @"Missing key for input #%u (address: %@)",
                           index, input.address);

                return nil;
            }
            [keys addObject:key];
        }
        
        return [builder signedTransactionWithInputKeys:keys error:error];
    }
}

#pragma mark Serialization

- (void)setPath:(NSString *)path
{
    @synchronized (self) {
        _path = path;
    }
}

- (BOOL)saveToPath:(NSString *)path
{
    WSExceptionCheckIllegal(path != nil, @"Nil path");
    
    @synchronized (self) {
        if (![NSKeyedArchiver archiveRootObject:self toFile:path]) {
            return NO;
        }
        _path = path;
        return YES;
    }
}

- (BOOL)save
{
    WSExceptionCheckIllegal(_path != nil, @"No implicit path set, call saveToPath: first");
    
    @synchronized (self) {
        return [self saveToPath:_path];
    }
}

+ (instancetype)loadFromPath:(NSString *)path mnemonic:(NSString *)mnemonic
{
    @synchronized (self) {
        WSHDWallet *wallet = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if (![wallet isKindOfClass:[WSHDWallet class]]) {
            return nil;
        }
        wallet.path = path;

        WSSeed *seed = WSSeedMake(mnemonic, wallet.creationTime);
        [wallet rebuildTransientStructuresWithSeed:seed];
        return wallet;
    }
}

#pragma mark WSSynchronizableWallet

- (uint32_t)earliestKeyTimestamp
{
    @synchronized (self) {
        return (NSTimeIntervalSince1970 + self.creationTime);
    }
}

- (BOOL)generateAddressesIfNeeded
{
    @synchronized (self) {
        NSAssert(_allExternalAddresses.count > 0, @"Wallet must have at least 1 receive address");
        
        __block NSUInteger accountOfFirstUnusedAddress = _allExternalAddresses.count;
        __block NSUInteger numberOfUsedAddresses = 0;
        
        [_allExternalAddresses enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            WSAddress *address = obj;
            if ([self.usedAddresses containsObject:address]) {
                numberOfUsedAddresses = idx + 1;
                *stop = YES;
            }
            else {
                accountOfFirstUnusedAddress = idx;
            }
        }];
        
        _currentAccount = (uint32_t)accountOfFirstUnusedAddress;
        
        DDLogDebug(@"Used %u/%u receive addresses", numberOfUsedAddresses, _allExternalAddresses.count);
        DDLogDebug(@"Current account set to first unused account (%u)", _currentAccount);
        
        const NSUInteger available = _allExternalAddresses.count - numberOfUsedAddresses;
        if (available >= self.gapLimit) {
            DDLogDebug(@"Still more available addresses than gap limit (%u >= %u), skipping generation",
                       available, self.gapLimit);
            
            return NO;
        }
        
        // generate more addresses than gap limit to avoid regenerating each time a new single address is used
        const NSUInteger lookAhead = 2 * self.gapLimit;
        
        DDLogDebug(@"Available addresses under gap limit (%u < %u), reestablish look-ahead %u (2 * gap limit)",
                   available, self.gapLimit, lookAhead);
        
        const NSTimeInterval generationStartTime = [NSDate timeIntervalSinceReferenceDate];
        
        const NSUInteger firstGenAccount = _allExternalAddresses.count;
        const NSUInteger lastGenAccount = accountOfFirstUnusedAddress + lookAhead; // excluded
        for (NSUInteger i = firstGenAccount; i < lastGenAccount; ++i) {
            [self generateAddressesForAccount:(uint32_t)i];
        }
        
        const NSUInteger watchedCount = lastGenAccount - self.currentAccount;
        NSAssert(watchedCount == lookAhead, @"Number of watched addresses must be equal to look-ahead (%u != %u)", watchedCount, lookAhead);
        
        const NSTimeInterval generationTime = [NSDate timeIntervalSinceReferenceDate] - generationStartTime;
        DDLogDebug(@"Generated accounts in %.3fs: %u -> %u (available: %u)",
                   generationTime, firstGenAccount, lastGenAccount - 1, watchedCount);
        
        return YES;
    }
}

- (WSBloomFilter *)bloomFilterWithParameters:(WSBIP37FilterParameters *)parameters
{
    @synchronized (self) {
        WSExceptionCheckIllegal(parameters != nil, @"Nil parameters");
        
#if (WASPV_WALLET_FILTER == WASPV_WALLET_FILTER_PUBKEYS)
        
        NSUInteger capacity = 2 * self.allAddresses.count;
        
#elif (WASPV_WALLET_FILTER == WASPV_WALLET_FILTER_UNSPENT)
        
        NSUInteger capacity = _allAddresses.count + _unspentOutputs.count;
        
#else
        
        return [[WSBloomFilter alloc] initWithFullMatch];
        
#endif
        
        if (capacity < 200) {
            capacity *= 1.5;
        }
        else {
            capacity += 100;
        }
        
        WSMutableBloomFilter *filter = [[WSMutableBloomFilter alloc] initWithParameters:parameters capacity:capacity];
        
#if (WASPV_WALLET_FILTER == WASPV_WALLET_FILTER_PUBKEYS)
        
        // number of watched accounts is based on external chain
        const uint32_t numberOfWatchedAddresses = (uint32_t)_allExternalAddresses.count;
        
        for (id<WSBIP32Keyring> chain in @[_externalChain, _internalChain]) {
            
            for (uint32_t account = 0; account < numberOfWatchedAddresses; ++account) {
                WSPublicKey *pubKey = [chain publicKeyForAccount:account];
                
#warning XXX: doesn't match multiSig inputs, but we don't send multiSig transactions
                // public keys match inputs scriptSig (sent money)
                [filter insertData:[pubKey encodedData]];
                
                // addresses match outputs scriptPubKey (received money)
                [filter insertData:[pubKey hash160]];
            }
        }
        
#elif (WASPV_WALLET_FILTER == WASPV_WALLET_FILTER_UNSPENT)
        
        // add addresses to watch for any tx receiveing money to the wallet
        for (WSAddress *address in _allAddresses) {
            [filter insertAddress:address];
        }
        
        // add unspent outputs to watch for any tx sending money from the wallet
        for (WSTransactionOutPoint *unspent in _unspentOutputs) {
            [filter insertUnspent:unspent];
        }
        
#endif
        
        return filter;
    }
}

- (BOOL)isRelevantTransaction:(WSSignedTransaction *)transaction
{
    return [self isRelevantTransaction:transaction savingReceivingAddresses:nil];
}

- (BOOL)isRelevantTransaction:(WSSignedTransaction *)transaction savingReceivingAddresses:(NSMutableSet *)receivingAddresses
{
#ifdef WASPV_TEST_DUMMY_TXS
    return YES;
#endif
    
    @synchronized (self) {
        WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");
        
        //
        // the major weakness is that the test would drop new unconfirmed transactions received during
        // sync because spent transaction has not been registered yet (previous transaction in outpoint
        // not found in wallet). the missed transaction should be recovered from mempool after download
        // finish or after it's received in a block.
        //
        // by the way, say we're not synced and we receive an inv for a high block with a transaction we
        // know to be relevant to us as it spends money from another transaction of ours. the block is
        // requested and stored into the blockchain as an orphan, but the transaction spends inputs from
        // an older transactions we're still not aware of, so the relevacy test fails and the transaction
        // is dropped.
        //
        // later on we catch up with the blockchain and the orphan gets eventually connected. now
        // mempool is requested but the transaction is not there anymore since it was included in a
        // block. we actually own the block, so it won't be requested again.
        //
        // the transaction is lost unless a new registration attempt is done for all the transactions
        // from blocks added to the blockchain. following blockchain extension guarantees that
        // even in the worst case transactions are registered in ascending height.
        //
        // it's worth noting that most of the time the wallet will already have the transactions because
        // of the 'tx' messages preceeding the block.
        //
        
        BOOL isRelevant = NO;
        
#warning FIXME: inputs relevancy test relies on chronological transaction registration (unpredictable)
        
        // relevant if inputs spend wallet transaction
        for (WSSignedTransactionInput *input in transaction.inputs) {
            if (_txsById[input.outpoint.txId]) {
                isRelevant = YES;
                break;
            }
        }
        
        // if transaction is relevant from previous checks, receivingAddresses must be filled anyway (if not nil)
        if (!isRelevant || receivingAddresses) {
            NSSet *txOutputAddresses = [transaction outputAddresses];
            
            // relevant if outputs contain at least one wallet address
            NSMutableOrderedSet *walletReceivingAddresses = [NSMutableOrderedSet orderedSetWithSet:txOutputAddresses];
            [walletReceivingAddresses intersectOrderedSet:self.allAddresses];
            if (walletReceivingAddresses.count > 0) {
                isRelevant = YES;
                [receivingAddresses addObjectsFromArray:[walletReceivingAddresses array]];
            }
        }
        
        return isRelevant;
    }
}

- (BOOL)registerTransaction:(WSSignedTransaction *)transaction didGenerateNewAddresses:(BOOL *)didGenerateNewAddresses
{
    return [self registerTransaction:transaction didGenerateNewAddresses:didGenerateNewAddresses batch:NO];
}

- (BOOL)registerTransaction:(WSSignedTransaction *)transaction didGenerateNewAddresses:(BOOL *)didGenerateNewAddresses batch:(BOOL)batch
{
    @synchronized (self) {
        WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");
        
        if (_txsById[transaction.txId] || ![self isRelevantTransaction:transaction savingReceivingAddresses:_usedAddresses]) {
            return NO;
        }
        if (didGenerateNewAddresses) {
            *didGenerateNewAddresses = NO;
        }
        
        [_txs insertObject:transaction atIndex:0];
        _txsById[transaction.txId] = transaction;
        _metadataByTxId[transaction.txId] = [[WSTransactionMetadata alloc] initWithNoParentBlock];
        
        if (!batch) {
            [self sortTransactions];
            [self recalculateSpendsAndBalance];
            if (self.shouldAutosave) {
                [self save];
            }

            [self notifyWithName:WSWalletDidRegisterTransactionNotification userInfo:@{WSWalletTransactionKey: transaction}];
        }
        
        const uint32_t previousAccount = self.currentAccount;
        const BOOL didGenerate = [self generateAddressesIfNeeded];
        if (didGenerateNewAddresses) {
            *didGenerateNewAddresses = didGenerate;
        }
        if (!batch && (self.currentAccount != previousAccount)) {
            [self notifyWithName:WSWalletDidUpdateReceiveAddressNotification userInfo:nil];
        }
        
        return YES;
    }
}

- (BOOL)unregisterTransaction:(WSSignedTransaction *)transaction
{
    return [self unregisterTransaction:transaction batch:NO];
}

- (BOOL)unregisterTransaction:(WSSignedTransaction *)transaction batch:(BOOL)batch
{
    @synchronized (self) {
        if (!_txsById[transaction.txId]) {
            return NO;
        }
        
        [_metadataByTxId removeObjectForKey:transaction.txId];
        [_txsById removeObjectForKey:transaction.txId];
        [_txs removeObject:transaction];
        
        if (!batch) {
            [self sortTransactions];
            [self recalculateSpendsAndBalance];
            if (self.shouldAutosave) {
                [self save];
            }

            [self notifyWithName:WSWalletDidUnregisterTransactionNotification userInfo:@{WSWalletTransactionKey: transaction}];
        }
        
        return YES;
    }
}

- (NSDictionary *)registerBlock:(WSStorableBlock *)block
{
    return [self registerBlock:block batch:NO];
}

- (NSDictionary *)registerBlock:(WSStorableBlock *)block batch:(BOOL)batch
{
    NSMutableDictionary *updates = nil;
    
    @synchronized (self) {
        WSExceptionCheckIllegal(block != nil, @"Nil block");
        
        for (WSSignedTransaction *tx in block.transactions) {
            WSTransactionMetadata *metadata = _metadataByTxId[tx.txId];
            if (!metadata || [block.blockId isEqual:metadata.parentBlockId]) {
                continue;
            }
            
            metadata = [[WSTransactionMetadata alloc] initWithParentBlock:block];
            _metadataByTxId[tx.txId] = metadata;
            
            if (!updates) {
                updates = [[NSMutableDictionary alloc] init];
            }
            updates[tx.txId] = metadata;
        }
    
        if (!batch && updates) {
            if (self.shouldAutosave) {
                [self save];
            }

            [self notifyWithName:WSWalletDidUpdateTransactionsMetadataNotification userInfo:@{WSWalletTransactionsMetadataKey: updates}];
        }
        return updates;
    }
}

- (NSDictionary *)unregisterBlock:(WSStorableBlock *)block
{
    return [self unregisterBlock:block batch:NO];
}

- (NSDictionary *)unregisterBlock:(WSStorableBlock *)block batch:(BOOL)batch
{
    NSMutableDictionary *updates = nil;
    
    @synchronized (self) {
        WSExceptionCheckIllegal(block != nil, @"Nil block");
        
        for (WSSignedTransaction *tx in block.transactions) {
            WSTransactionMetadata *metadata = _metadataByTxId[tx.txId];
            if (!metadata) {
                continue;
            }
            
            metadata = [[WSTransactionMetadata alloc] initWithNoParentBlock];
            _metadataByTxId[tx.txId] = metadata;
            
            if (!updates) {
                updates = [[NSMutableDictionary alloc] init];
            }
            updates[tx.txId] = metadata;
        }
    
        if (!batch && updates) {
            if (self.shouldAutosave) {
                [self save];
            }

            [self notifyWithName:WSWalletDidUpdateTransactionsMetadataNotification userInfo:@{WSWalletTransactionsMetadataKey: updates}];
        }
        return updates;
    }
}

- (void)reorganizeWithOldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks didGenerateNewAddresses:(BOOL *)didGenerateNewAddresses
{
    @synchronized (self) {
        WSExceptionCheckIllegal(oldBlocks.count > 0, @"Empty oldBlocks");
        WSExceptionCheckIllegal(newBlocks.count > 0, @"Empty newBlocks");
        
        if (didGenerateNewAddresses) {
            *didGenerateNewAddresses = NO;
        }
        
        NSMutableDictionary *unregisteredUpdates = [[NSMutableDictionary alloc] init];;
        NSMutableDictionary *updates = [[NSMutableDictionary alloc] init];;
        
        for (WSStorableBlock *block in oldBlocks) {
            [unregisteredUpdates addEntriesFromDictionary:[self unregisterBlock:block batch:YES]];
        }
        
        for (WSStorableBlock *block in [newBlocks reverseObjectEnumerator]) {
            for (WSSignedTransaction *transaction in block.transactions) {
                BOOL txDidGenerateNewAddresses = NO;
                [self registerTransaction:transaction didGenerateNewAddresses:&txDidGenerateNewAddresses];
                
                if (didGenerateNewAddresses) {
                    *didGenerateNewAddresses |= txDidGenerateNewAddresses;
                }
            }
            
            [updates addEntriesFromDictionary:[self registerBlock:block batch:YES]];
        }
        
        [self sortTransactions];
        [self recalculateSpendsAndBalance];
        
        // remove transactions that got reconfirmed in new blocks
        [unregisteredUpdates removeObjectsForKeys:[updates allKeys]];
        
        // merge all updates
        [updates addEntriesFromDictionary:unregisteredUpdates];
        
        if (updates.count > 0) {
            if (self.shouldAutosave) {
                [self save];
            }

            [self notifyWithName:WSWalletDidUpdateTransactionsMetadataNotification userInfo:@{WSWalletTransactionsMetadataKey: updates}];
        }
    }
}

- (void)sortTransactions
{
    @synchronized (self) {
        [_txs sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            WSSignedTransaction *tx1 = obj1;
            WSSignedTransaction *tx2 = obj2;
            WSTransactionMetadata *m1 = _metadataByTxId[tx1.txId];
            WSTransactionMetadata *m2 = _metadataByTxId[tx2.txId];
            
            if (m1.height > m2.height) {
                return NSOrderedAscending;
            }
            else if (m1.height < m2.height) {
                return NSOrderedDescending;
            }
            
            // same height, dependent first
            if ([tx1.inputTxIds containsObject:tx2.txId]) {
                return NSOrderedAscending;
            }
            else if ([tx2.inputTxIds containsObject:tx1.txId]) {
                return NSOrderedDescending;
            }
            
            return NSOrderedSame;
        }];
    }
}

- (void)recalculateSpendsAndBalance
{
    @synchronized (self) {
        NSMutableSet *spentOutputs = [[NSMutableSet alloc] init];
        NSMutableOrderedSet *unspentOutputs = [[NSMutableOrderedSet alloc] init];
        NSMutableSet *invalidTxIds = [[NSMutableSet alloc] init];
        
        for (WSSignedTransaction *tx in [_txs reverseObjectEnumerator]) {
            NSMutableSet *spentTxOutputs = [[NSMutableSet alloc] init];
            
            // inputs are spent outputs
            for (WSSignedTransactionInput *input in tx.inputs) {
                [spentTxOutputs addObject:input.outpoint];
            }
            
            // if tx is unconfirmed, invalidate on (double-spent input OR input from invalid tx output)
            WSTransactionMetadata *metadata = _metadataByTxId[tx.txId];
            if (!metadata.parentBlockId &&
                ([spentTxOutputs intersectsSet:spentOutputs] || [tx.inputTxIds intersectsSet:invalidTxIds])) {
                
                [invalidTxIds addObject:tx.txId];
                continue;
            }
            
            [spentOutputs unionSet:spentTxOutputs];
            
            // own outputs are unspent outputs
            uint32_t index = 0;
            for (WSTransactionOutput *output in tx.outputs) {
                if ([self.allAddresses containsObject:output.address]) {
                    [unspentOutputs addObject:[WSTransactionOutPoint outpointWithTxId:tx.txId index:index]];
                }
                ++index;
            }
        }
        
        [unspentOutputs minusSet:spentOutputs];
        
        uint64_t balance = 0;
        for (WSTransactionOutPoint *outpoint in unspentOutputs) {
            WSSignedTransaction *tx = _txsById[outpoint.txId];
            WSTransactionOutput *output = [tx outputAtIndex:outpoint.index];
            
            balance += output.value;
        }
        
        _invalidTxIds = invalidTxIds;
        _spentOutputs = spentOutputs;
        _unspentOutputs = unspentOutputs;
        
        if (balance != _balance) {
            _balance = balance;

            [self notifyWithName:WSWalletDidUpdateBalanceNotification userInfo:nil];
        }
    }
}

#pragma mark Utils

- (void)notifyWithName:(NSString *)name userInfo:(NSDictionary *)userInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:userInfo];
    });
}

#pragma mark WSIndentableDescription

- (NSString *)descriptionWithIndent:(NSUInteger)indent
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];

    @synchronized (self) {
        [tokens addObject:[NSString stringWithFormat:@"created = %@", [NSDate dateWithTimeIntervalSinceReferenceDate:_creationTime]]];
        [tokens addObject:[NSString stringWithFormat:@"receive = %@", self.receiveAddress]];
        [tokens addObject:[NSString stringWithFormat:@"transactions = %u", _txs.count]];
        [tokens addObject:[NSString stringWithFormat:@"balance = %llu", _balance]];
    }

    return [NSString stringWithFormat:@"{%@}", WSStringDescriptionFromTokens(tokens, indent)];
}

#pragma mark AutoCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        WSExceptionCheckIllegal(_parametersType == WSParametersGetCurrentType(),
                                @"Wallet created on '%@' network (current: '%@')",
                                WSParametersTypeString(_parametersType),
                                WSParametersGetCurrentTypeString());
    }
    return self;
}

+ (NSDictionary *)codableProperties
{
    return @{@"_parametersType": [NSNumber class],
             @"_creationTime": [NSNumber class],
             @"_gapLimit": [NSNumber class],
             @"_currentAccount": [NSNumber class],
             @"_txs": [NSMutableOrderedSet class],
             @"_usedAddresses": [NSMutableSet class],
             @"_metadataByTxId": [NSMutableDictionary class]};
}

@end
