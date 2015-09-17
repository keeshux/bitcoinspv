//
//  WSTransactionEntity.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 16/07/14.
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

#import "WSTransactionEntity.h"
#import "WSStorableBlockEntity.h"
#import "WSTransactionInputEntity.h"
#import "WSTransactionOutputEntity.h"
#import "WSCoreDataManager.h"
#import "WSHash256.h"
#import "WSMacrosCore.h"

@implementation WSTransactionEntity

@dynamic version;
@dynamic lockTime;
@dynamic txIdData;
@dynamic block;
@dynamic inputs;
@dynamic outputs;

- (void)copyFromSignedTransaction:(WSSignedTransaction *)transaction
{
    self.version = @(transaction.version);
    self.txIdData = transaction.txId.data;
    
//    for (WSSignedTransactionInput *input in transaction.inputs) {
//        WSTransactionInputEntity *entity = [[WSTransactionInputEntity alloc] initWithContext:self.managedObjectContext];
//        [entity copyFromSignedInput:input];
//        [self addInputsObject:entity];
//    }
//
//    for (WSTransactionOutput *output in transaction.outputs) {
//        WSTransactionOutputEntity *entity = [[WSTransactionOutputEntity alloc] initWithContext:self.managedObjectContext];
//        [entity copyFromOutput:output];
//        [self addOutputsObject:entity];
//    }

    NSMutableOrderedSet *inputEntities = [[NSMutableOrderedSet alloc] initWithCapacity:transaction.inputs.count];
    for (WSSignedTransactionInput *input in transaction.inputs) {
        WSTransactionInputEntity *entity = [[WSTransactionInputEntity alloc] initWithContext:self.managedObjectContext];
        [entity copyFromSignedInput:input];
        [inputEntities addObject:entity];
    }
    self.inputs = inputEntities;
    
    NSMutableOrderedSet *outputEntities = [[NSMutableOrderedSet alloc] initWithCapacity:transaction.inputs.count];
    for (WSTransactionOutput *output in transaction.outputs) {
        WSTransactionOutputEntity *entity = [[WSTransactionOutputEntity alloc] initWithContext:self.managedObjectContext];
        [entity copyFromOutput:output];
        [outputEntities addObject:entity];
    }
    self.outputs = outputEntities;

    self.lockTime = @(transaction.lockTime);
}

- (WSSignedTransaction *)toSignedTransactionWithParameters:(WSParameters *)parameters
{
    const uint32_t version = (uint32_t)[self.version unsignedIntegerValue];

    NSMutableOrderedSet *signedInputs = [[NSMutableOrderedSet alloc] initWithCapacity:self.inputs.count];
    for (WSTransactionInputEntity *entity in self.inputs) {
        [signedInputs addObject:[entity toSignedInputWithParameters:parameters]];
    }

    NSMutableOrderedSet *outputs = [[NSMutableOrderedSet alloc] initWithCapacity:self.outputs.count];
    for (WSTransactionOutputEntity *entity in self.outputs) {
        [outputs addObject:[entity toOutputWithParameters:parameters]];
    }

    const uint32_t lockTime = (uint32_t)[self.lockTime unsignedIntegerValue];
    
    WSSignedTransaction *transaction = [[WSSignedTransaction alloc] initWithVersion:version
                                                                       signedInputs:signedInputs
                                                                            outputs:outputs
                                                                           lockTime:lockTime
                                                                              error:NULL];

    __unused WSHash256 *expectedTxId = WSHash256FromData(self.txIdData);

#ifdef BSPV_TEST_NO_HASH_VALIDATIONS
    [transaction setValue:expectedTxId forKey:@"txId"];
#else
    NSAssert([transaction.txId isEqual:expectedTxId], @"Corrupted id while deserializing WSTransaction (%@ != %@): %@",
             transaction.txId, expectedTxId, [[transaction toBuffer] hexString]);
#endif

    return transaction;
}

@end

//@implementation WSTransactionEntity (CoreDataGeneratedAccessors)
//
//// Core Data is broken, http://openradar.io/10114310
//
//- (void)addInputsObject:(WSTransactionInputEntity *)value
//{
//    if ([self.inputs containsObject:value]) {
//        return;
//    }
//    [self insertObject:value inInputsAtIndex:self.inputs.count];
//}
//
//- (void)addOutputsObject:(WSTransactionOutputEntity *)value
//{
//    if ([self.outputs containsObject:value]) {
//        return;
//    }
//    [self insertObject:value inOutputsAtIndex:self.outputs.count];
//}
//
//@end
