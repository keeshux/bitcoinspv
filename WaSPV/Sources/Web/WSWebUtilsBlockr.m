//
//  WSWebUtilsBlockr.m
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

#import "WSWebUtilsBlockr.h"
#import "WSMacros.h"
#import "WSErrors.h"

static NSString *const WSWebUtilsBlockrFormat               = @"http://%@.blockr.io/";
static NSString *const WSWebUtilsBlockrNetworkMain          = @"btc";
static NSString *const WSWebUtilsBlockrNetworkTest          = @"tbtc";

static NSString *const WSWebUtilsBlockrObjectPathFormat     = @"%@/info/%@";
static NSString *const WSWebUtilsBlockrObjectBlock          = @"block";
static NSString *const WSWebUtilsBlockrObjectTransaction    = @"tx";

@implementation WSWebUtilsBlockr

#pragma mark WSWebUtils

- (NSURL *)URLForObjectType:(WSWebUtilsObjectType)objectType hash:(WSHash256 *)hash
{
    WSExceptionCheckIllegal(hash != nil, @"Nil hash");
    
    NSString *network = nil;
    NSString *object = nil;
    
    switch (WSParametersGetCurrentType()) {
        case WSParametersTypeMain: {
            network = WSWebUtilsBlockrNetworkMain;
            break;
        }
        case WSParametersTypeTestnet3: {
            network = WSWebUtilsBlockrNetworkTest;
            break;
        }
        case WSParametersTypeRegtest: {
            return nil;
        }
    }
    
    switch (objectType) {
        case WSWebUtilsObjectTypeBlock: {
            object = WSWebUtilsBlockrObjectBlock;
            break;
        }
        case WSWebUtilsObjectTypeTransaction: {
            object = WSWebUtilsBlockrObjectTransaction;
            break;
        }
    }
    
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:WSWebUtilsBlockrFormat, network]];
    return [NSURL URLWithString:[NSString stringWithFormat:WSWebUtilsBlockrObjectPathFormat, object, hash] relativeToURL:baseURL];
}

@end
