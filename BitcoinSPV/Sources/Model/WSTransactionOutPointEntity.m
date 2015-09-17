//
//  WSTransactionOutPointEntity.m
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

#import "WSTransactionOutPointEntity.h"
#import "WSTransactionInputEntity.h"
#import "WSCoreDataManager.h"
#import "WSHash256.h"
#import "WSMacrosCore.h"

@implementation WSTransactionOutPointEntity

@dynamic txIdData;
@dynamic index;
@dynamic input;

- (void)copyFromOutpoint:(WSTransactionOutPoint *)outpoint
{
    self.txIdData = [outpoint.txId data];
    self.index = @(outpoint.index);
}

- (WSTransactionOutPoint *)toOutpointWithParameters:(WSParameters *)parameters
{
    WSHash256 *txId = WSHash256FromData(self.txIdData);
    const uint32_t index = (uint32_t)[self.index unsignedIntegerValue];
    
    return [WSTransactionOutPoint outpointWithParameters:parameters txId:txId index:index];
}

@end
