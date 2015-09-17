//
//  WSStorableBlockEntity.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 12/07/14.
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

#import "WSStorableBlockEntity.h"
#import "WSBlockHeaderEntity.h"
#import "WSPartialMerkleTreeEntity.h"
#import "WSTransactionEntity.h"
#import "WSCoreDataManager.h"

@implementation WSStorableBlockEntity

@dynamic height;
@dynamic work;
@dynamic header;
@dynamic transactions;

- (void)copyFromStorableBlock:(WSStorableBlock *)block
{
    WSBlockHeaderEntity *headerEntity = [[WSBlockHeaderEntity alloc] initWithContext:self.managedObjectContext];
    [headerEntity copyFromBlockHeader:block.header];
    self.header = headerEntity;

    self.height = @(block.height);
    self.work = [[block workData] copy];

    NSMutableOrderedSet *txEntities = [[NSMutableOrderedSet alloc] initWithCapacity:block.transactions.count];
    for (WSSignedTransaction *tx in block.transactions) {
        WSTransactionEntity *txEntity = [[WSTransactionEntity alloc] initWithContext:self.managedObjectContext];
        [txEntity copyFromSignedTransaction:tx];
        [txEntities addObject:txEntity];
    }
    self.transactions = txEntities;
}

- (WSStorableBlock *)toStorableBlockWithParameters:(WSParameters *)parameters
{
    WSBlockHeader *header = [self.header toBlockHeaderWithParameters:parameters];
    const uint32_t height = (uint32_t)[self.height unsignedIntegerValue];

    NSMutableOrderedSet *transactions = [[NSMutableOrderedSet alloc] initWithCapacity:self.transactions.count];
    for (WSTransactionEntity *entity in self.transactions) {
        WSSignedTransaction *tx = [entity toSignedTransactionWithParameters:parameters];
        [transactions addObject:tx];
    }
    
    return [[WSStorableBlock alloc] initWithHeader:header transactions:transactions height:height work:self.work];
}

@end
