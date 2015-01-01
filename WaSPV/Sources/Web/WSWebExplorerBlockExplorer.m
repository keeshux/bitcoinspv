//
//  WSWebExplorerBlockExplorer.m
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

#import "WSWebExplorerBlockExplorer.h"
#import "WSMacros.h"
#import "WSErrors.h"

static NSString *const WSWebExplorerBlockExplorerFormat                = @"https://blockexplorer.com%@/";
static NSString *const WSWebExplorerBlockExplorerNetworkMain           = @"";
static NSString *const WSWebExplorerBlockExplorerNetworkTest           = @"/testnet";

static NSString *const WSWebExplorerBlockExplorerObjectPathFormat      = @"%@/%@";
static NSString *const WSWebExplorerBlockExplorerObjectBlock           = @"block";
static NSString *const WSWebExplorerBlockExplorerObjectTransaction     = @"tx";

@implementation WSWebExplorerBlockExplorer

#pragma mark WSWebExplorer

- (NSString *)provider
{
    return WSWebExplorerProviderBlockExplorer;
}

- (NSURL *)URLForObjectType:(WSWebExplorerObjectType)objectType hash:(WSHash256 *)hash
{
    WSExceptionCheckIllegal(hash != nil, @"Nil hash");
    
    NSString *network = nil;
    NSString *object = nil;
    
    switch (WSParametersGetCurrentType()) {
        case WSParametersTypeMain: {
            network = WSWebExplorerBlockExplorerNetworkMain;
            break;
        }
        case WSParametersTypeTestnet3: {
            network = WSWebExplorerBlockExplorerNetworkTest;
            break;
        }
        case WSParametersTypeRegtest: {
            return nil;
        }
    }
    
    switch (objectType) {
        case WSWebExplorerObjectTypeBlock: {
            object = WSWebExplorerBlockExplorerObjectBlock;
            break;
        }
        case WSWebExplorerObjectTypeTransaction: {
            object = WSWebExplorerBlockExplorerObjectTransaction;
            break;
        }
    }
    
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:WSWebExplorerBlockExplorerFormat, network]];
    return [NSURL URLWithString:[NSString stringWithFormat:WSWebExplorerBlockExplorerObjectPathFormat, object, hash] relativeToURL:baseURL];
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
