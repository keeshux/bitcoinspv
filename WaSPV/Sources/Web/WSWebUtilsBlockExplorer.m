//
//  WSWebUtilsBlockExplorer.m
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

#import "WSWebUtilsBlockExplorer.h"
#import "WSMacros.h"
#import "WSErrors.h"

static NSString *const WSWebUtilsBlockExplorerFormat                = @"https://blockexplorer.com%@/";
static NSString *const WSWebUtilsBlockExplorerNetworkMain           = @"";
static NSString *const WSWebUtilsBlockExplorerNetworkTest           = @"/testnet";

static NSString *const WSWebUtilsBlockExplorerObjectPathFormat      = @"%@/%@";
static NSString *const WSWebUtilsBlockExplorerObjectBlock           = @"block";
static NSString *const WSWebUtilsBlockExplorerObjectTransaction     = @"tx";

@implementation WSWebUtilsBlockExplorer

#pragma mark WSWebUtils

- (NSString *)provider
{
    return WSWebUtilsProviderBlockExplorer;
}

- (NSURL *)URLForObjectType:(WSWebUtilsObjectType)objectType hash:(WSHash256 *)hash
{
    WSExceptionCheckIllegal(hash != nil, @"Nil hash");
    
    NSString *network = nil;
    NSString *object = nil;
    
    switch (WSParametersGetCurrentType()) {
        case WSParametersTypeMain: {
            network = WSWebUtilsBlockExplorerNetworkMain;
            break;
        }
        case WSParametersTypeTestnet3: {
            network = WSWebUtilsBlockExplorerNetworkTest;
            break;
        }
        case WSParametersTypeRegtest: {
            return nil;
        }
    }
    
    switch (objectType) {
        case WSWebUtilsObjectTypeBlock: {
            object = WSWebUtilsBlockExplorerObjectBlock;
            break;
        }
        case WSWebUtilsObjectTypeTransaction: {
            object = WSWebUtilsBlockExplorerObjectTransaction;
            break;
        }
    }
    
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:WSWebUtilsBlockExplorerFormat, network]];
    return [NSURL URLWithString:[NSString stringWithFormat:WSWebUtilsBlockExplorerObjectPathFormat, object, hash] relativeToURL:baseURL];
}

- (void)buildSweepTransactionsFromKey:(WSKey *)fromKey toAddress:(WSAddress *)toAddress fee:(uint64_t)fee maxTxSize:(NSUInteger)maxTxSize callback:(void (^)(WSSignedTransaction *))callback completion:(void (^)(NSUInteger))completion failure:(void (^)(NSError *))failure
{
    WSExceptionRaiseUnsupported(@"Unsupported operation");
}

- (void)buildSweepTransactionsFromBIP38Key:(WSBIP38Key *)fromBIP38Key passphrase:(NSString *)passphrase toAddress:(WSAddress *)toAddress fee:(uint64_t)fee maxTxSize:(NSUInteger)maxTxSize callback:(void (^)(WSSignedTransaction *))callback completion:(void (^)(NSUInteger))completion failure:(void (^)(NSError *))failure
{
    WSExceptionRaiseUnsupported(@"Unsupported operation");
}

@end
