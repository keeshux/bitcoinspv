//
//  WSWebExplorer.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 07/12/14.
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

#import "WSNetworkType.h"

@class WSHash256;
@class WSKey;
@class WSBIP38Key;
@class WSAddress;
@class WSSignedTransaction;

#pragma mark -

extern NSString *const WSWebExplorerProviderBiteasy;
extern NSString *const WSWebExplorerProviderBlockExplorer;
extern NSString *const WSWebExplorerProviderBlockr;
extern NSString *const WSWebExplorerProviderBlockchain;

@protocol WSWebExplorer;

@interface WSWebExplorerFactory : NSObject

+ (id<WSWebExplorer>)explorerForProvider:(NSString *)provider networkType:(WSNetworkType)networkType;

@end

#pragma mark -

typedef enum {
    WSWebExplorerObjectTypeBlock,
    WSWebExplorerObjectTypeTransaction
} WSWebExplorerObjectType;

@protocol WSWebExplorer <NSObject>

- (NSString *)provider;
- (WSNetworkType)networkType;
- (void)setNetworkType:(WSNetworkType)networkType;

- (NSURL *)URLForObjectType:(WSWebExplorerObjectType)objectType hash:(WSHash256 *)hash;

- (void)buildSweepTransactionsFromKey:(WSKey *)fromKey
                            toAddress:(WSAddress *)toAddress
                                  fee:(uint64_t)fee
                            maxTxSize:(NSUInteger)maxTxSize
                             callback:(void (^)(WSSignedTransaction *))callback
                           completion:(void (^)(NSUInteger))completion
                              failure:(void (^)(NSError *))failure;

- (void)buildSweepTransactionsFromBIP38Key:(WSBIP38Key *)fromBIP38Key
                                passphrase:(NSString *)passphrase
                                 toAddress:(WSAddress *)toAddress
                                       fee:(uint64_t)fee
                                 maxTxSize:(NSUInteger)maxTxSize
                                  callback:(void (^)(WSSignedTransaction *))callback
                                completion:(void (^)(NSUInteger))completion
                                   failure:(void (^)(NSError *))failure;

@end
