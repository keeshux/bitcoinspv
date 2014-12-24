//
//  WSWebUtilsBlockchain.m
//  WaSPV
//
//  Created by Davide De Rosa on 04/09/14.
//  Copyright (c) 2014 fingrtip. All rights reserved.
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

#import "WSWebUtilsBlockchain.h"
#import "WSMacros.h"
#import "WSErrors.h"

static NSString *const WSWebUtilsBlockchainBaseFormat           = @"https://blockchain.info/";

static NSString *const WSWebUtilsBlockchainObjectPathFormat     = @"%@/%@";
static NSString *const WSWebUtilsBlockchainObjectBlock          = @"block";
static NSString *const WSWebUtilsBlockchainObjectTransaction    = @"tx";

@implementation WSWebUtilsBlockchain

#pragma mark WSWebUtils

- (NSURL *)URLForObjectType:(WSWebUtilsObjectType)objectType hash:(WSHash256 *)hash
{
    WSExceptionCheckIllegal(hash != nil, @"Nil hash");
    
    NSString *object = nil;
    
    if (WSParametersGetCurrentType() != WSParametersTypeMain) {
        return nil;
    }
    
    switch (objectType) {
        case WSWebUtilsObjectTypeBlock: {
            object = WSWebUtilsBlockchainObjectBlock;
            break;
        }
        case WSWebUtilsObjectTypeTransaction: {
            object = WSWebUtilsBlockchainObjectTransaction;
            break;
        }
    }
    
    NSURL *baseURL = [NSURL URLWithString:WSWebUtilsBlockchainBaseFormat];
    return [NSURL URLWithString:[NSString stringWithFormat:WSWebUtilsBlockchainObjectPathFormat, object, hash] relativeToURL:baseURL];
}

@end
