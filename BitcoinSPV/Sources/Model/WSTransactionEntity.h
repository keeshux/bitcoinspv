//
//  WSTransactionEntity.h
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "WSTransaction.h"

@class WSStorableBlockEntity, WSTransactionInputEntity, WSTransactionOutputEntity;
@class WSParameters;

@interface WSTransactionEntity : NSManagedObject

@property (nonatomic, retain) NSNumber * version;
@property (nonatomic, retain) NSNumber * lockTime;
@property (nonatomic, retain) NSData * txIdData;
@property (nonatomic, retain) WSStorableBlockEntity *block;
@property (nonatomic, retain) NSOrderedSet *inputs;
@property (nonatomic, retain) NSOrderedSet *outputs;

- (void)copyFromSignedTransaction:(WSSignedTransaction *)transaction;
- (WSSignedTransaction *)toSignedTransactionWithParameters:(WSParameters *)parameters;

@end

//@interface WSTransactionEntity (CoreDataGeneratedAccessors)
//
//- (void)addInputsObject:(WSTransactionInputEntity *)value;
//- (void)removeInputsObject:(WSTransactionInputEntity *)value;
//- (void)addOutputsObject:(WSTransactionOutputEntity *)value;
//- (void)removeOutputsObject:(WSTransactionOutputEntity *)value;
//
//@end
