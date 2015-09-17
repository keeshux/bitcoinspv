//
//  WSTransactionInputEntity.m
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

#import "WSTransactionInputEntity.h"
#import "WSTransactionEntity.h"
#import "WSTransactionOutPointEntity.h"
#import "WSScript.h"
#import "WSCoreDataManager.h"

@implementation WSTransactionInputEntity

@dynamic sequence;
@dynamic scriptData;
@dynamic outpoint;
@dynamic transaction;

- (void)copyFromSignedInput:(WSSignedTransactionInput *)input
{
    WSTransactionOutPointEntity *outpointEntity = [[WSTransactionOutPointEntity alloc] initWithContext:self.managedObjectContext];
    [outpointEntity copyFromOutpoint:input.outpoint];
    self.outpoint = outpointEntity;

    self.sequence = @(input.sequence);
    self.scriptData = [[input.script toBuffer] data];
}

- (WSSignedTransactionInput *)toSignedInputWithParameters:(WSParameters *)parameters
{
    WSTransactionOutPoint *outpoint = [self.outpoint toOutpointWithParameters:parameters];
    WSBuffer *scriptBuffer = [[WSBuffer alloc] initWithData:self.scriptData];
    WSScript *script = nil;
    if (outpoint.isCoinbase) {
        script = [WSCoinbaseScript scriptWithCoinbaseData:self.scriptData];
    }
    else {
        script = [[WSScript alloc] initWithParameters:nil buffer:scriptBuffer from:0 available:scriptBuffer.length error:NULL];
    }
    const uint32_t sequence = (uint32_t)[self.sequence unsignedIntegerValue];

    return [[WSSignedTransactionInput alloc] initWithOutpoint:outpoint script:script sequence:sequence];
}

@end
