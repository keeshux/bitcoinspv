//
//  WSWebExplorerBlockchain.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 04/09/14.
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

#import "WSWebExplorerBlockchain.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

static NSString *const WSWebExplorerBlockchainBaseFormat           = @"https://blockchain.info/";

static NSString *const WSWebExplorerBlockchainObjectPathFormat     = @"%@/%@";
static NSString *const WSWebExplorerBlockchainObjectBlock          = @"block";
static NSString *const WSWebExplorerBlockchainObjectTransaction    = @"tx";

@interface WSWebExplorerBlockchain ()

@property (nonatomic, assign) WSNetworkType networkType;

@end

@implementation WSWebExplorerBlockchain

#pragma mark WSWebExplorer

- (NSString *)provider
{
    return WSWebExplorerProviderBlockchain;
}

- (NSURL *)URLForObjectType:(WSWebExplorerObjectType)objectType hash:(WSHash256 *)hash
{
    WSExceptionCheckIllegal(hash);
    
    NSString *object = nil;
    
    if (self.networkType != WSNetworkTypeMain) {
        return nil;
    }
    
    switch (objectType) {
        case WSWebExplorerObjectTypeBlock: {
            object = WSWebExplorerBlockchainObjectBlock;
            break;
        }
        case WSWebExplorerObjectTypeTransaction: {
            object = WSWebExplorerBlockchainObjectTransaction;
            break;
        }
    }
    
    NSURL *baseURL = [NSURL URLWithString:WSWebExplorerBlockchainBaseFormat];
    return [NSURL URLWithString:[NSString stringWithFormat:WSWebExplorerBlockchainObjectPathFormat, object, hash] relativeToURL:baseURL];
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
