//
//  WSWebUtils.m
//  WaSPV
//
//  Created by Davide De Rosa on 07/12/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
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

#import "DDLog.h"

#import "WSWebUtils.h"
#import "WSJSONClient.h"
#import "WSKey.h"
#import "WSBIP38.h"
#import "WSAddress.h"
#import "WSTransactionInput.h"
#import "WSTransactionOutPoint.h"
#import "WSTransactionOutput.h"
#import "WSTransaction.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"

static NSString *const         WSWebUtilsBiteasyBaseURLFormat           = @"https://api.biteasy.com/%@/v1/";
static const NSTimeInterval    WSWebUtilsBiteasyYieldInterval           = 1.0;
static NSString *const         WSWebUtilsBiteasyUnspentFormat           = @"addresses/%@/unspent-outputs?page=%u&per_page=%u";
static const NSUInteger        WSWebUtilsBiteasyUnspentPerPage          = 100;

@interface WSWebUtils ()

- (void)fetchUnspentInputsForAddress:(WSAddress *)address
                                page:(NSUInteger)page
                             handler:(void (^)(WSSignableTransactionInput *, BOOL, BOOL *))handler
                          completion:(void (^)())completion
                             failure:(void (^)(NSError *))failure;

- (NSString *)networkName;

@end

@implementation WSWebUtils

+ (instancetype)sharedInstance
{
    static WSWebUtils *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)buildSweepTransactionsFromKey:(WSKey *)fromKey
                            toAddress:(WSAddress *)toAddress
                                  fee:(uint64_t)fee
                            maxTxSize:(NSUInteger)maxTxSize
                              success:(void (^)(NSArray *))success
                              failure:(void (^)(NSError *))failure
{
    WSExceptionCheckIllegal(fromKey != nil, @"Nil fromKey");
    WSExceptionCheckIllegal(toAddress != nil, @"Nil toAddress");
    WSExceptionCheckIllegal(success != nil, @"Nil success");
    WSExceptionCheckIllegal(failure != nil, @"Nil failure");
    
    if (maxTxSize == 0) {
        maxTxSize = WSTransactionMaxSize;
    }
    
    WSAddress *fromAddress = [fromKey address];
    NSMutableArray *transactions = [[NSMutableArray alloc] init];
    __block WSTransactionBuilder *builder = [[WSTransactionBuilder alloc] init];
    
    // XXX: unspent outputs may be _A LOT_
    //
    // https://api.biteasy.com/testnet/v1/addresses/muyDoehpBExCbRRXLtDUpw5DaTb33UZeyG/unspent-outputs
    
    DDLogVerbose(@"Sweeping %@ funds into %@", fromAddress, toAddress);

    [self fetchUnspentInputsForAddress:fromAddress page:1 handler:^(WSSignableTransactionInput *input, BOOL isLast, BOOL *stop) {
        [builder addSignableInput:input];
        
        const NSUInteger estimatedTxSizeBefore = [builder sizeWithExtraInputs:nil outputs:1];
        const NSUInteger estimatedTxSizeAfter = [builder sizeWithExtraInputs:@[input] outputs:1];

        DDLogVerbose(@"#%u Sweep transaction estimated size: %u->%u > %u ?",
                     transactions.count, estimatedTxSizeBefore, estimatedTxSizeAfter, maxTxSize);

        if (isLast || ((estimatedTxSizeBefore <= maxTxSize) && (estimatedTxSizeAfter > maxTxSize))) {
            DDLogVerbose(@"#%u Sweep inputs (%u): %@", transactions.count, builder.signableInputs.count, builder.signableInputs);
            DDLogVerbose(@"#%u Sweep input value: %llu", transactions.count, [builder inputValue]);
            
            if (![builder addSweepOutputAddress:toAddress fee:fee]) {
                failure(WSErrorMake(WSErrorCodeInsufficientFunds, @"Unspent balance is less than fee + min output value"));
                return;
            }
            
            DDLogVerbose(@"#%u Sweep output value: %llu", transactions.count, [builder outputValue]);
            DDLogVerbose(@"#%u Sweep fee: %llu", transactions.count, [builder fee]);
            
            NSError *error;
            NSDictionary *keys = @{fromAddress: fromKey};
            WSSignedTransaction *transaction = [builder signedTransactionWithInputKeys:keys error:&error];
            if (!transaction) {
                DDLogDebug(@"#%u Sweep transaction error: %@", transactions.count, error);

                *stop = YES;
                failure(error);
                return;
            }
            DDLogDebug(@"#%u Sweep transaction: %@", transactions.count, transaction);
            [transactions addObject:transaction];
            
            builder = [[WSTransactionBuilder alloc] init];
        }
    } completion:^{
        success(transactions);
    } failure:failure];
}

- (void)buildSweepTransactionsFromBIP38Key:(WSBIP38Key *)fromBIP38Key
                                passphrase:(NSString *)passphrase
                                 toAddress:(WSAddress *)toAddress
                                       fee:(uint64_t)fee
                                 maxTxSize:(NSUInteger)maxTxSize
                                   success:(void (^)(NSArray *))success
                                   failure:(void (^)(NSError *))failure
{
    WSExceptionCheckIllegal(fromBIP38Key != nil, @"Nil fromBIP38Key");
    WSExceptionCheckIllegal(toAddress != nil, @"Nil toAddress");
    WSExceptionCheckIllegal(success != nil, @"Nil success");
    WSExceptionCheckIllegal(failure != nil, @"Nil failure");

    WSKey *fromKey = [fromBIP38Key decryptedKeyWithPassphrase:passphrase];
    [self buildSweepTransactionsFromKey:fromKey toAddress:toAddress fee:fee maxTxSize:maxTxSize success:success failure:failure];
}

- (void)fetchUnspentInputsForAddress:(WSAddress *)address
                                page:(NSUInteger)page
                             handler:(void (^)(WSSignableTransactionInput *, BOOL, BOOL *))handler
                          completion:(void (^)())completion
                             failure:(void (^)(NSError *))failure
{
    NSAssert(address != nil, @"Nil address");
    NSAssert(page > 0, @"Non positive page");
    NSAssert(handler, @"NULL handler");
    NSAssert(completion, @"NULL completion");
    NSAssert(failure, @"NULL failure");
    
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:WSWebUtilsBiteasyBaseURLFormat, [self networkName]]];
    NSString *path = [NSString stringWithFormat:WSWebUtilsBiteasyUnspentFormat, address, page, WSWebUtilsBiteasyUnspentPerPage];
    
    [[WSJSONClient sharedInstance] asynchronousRequestWithBaseURL:baseURL path:path success:^(int statusCode, id object) {
        NSDictionary *jsonData = object[@"data"];
        NSArray *jsonOutputs = jsonData[@"outputs"];
        NSDictionary *jsonPagination = jsonData[@"pagination"];
        const NSUInteger nextPage = [jsonPagination[@"next_page"] unsignedIntegerValue];
        const BOOL isLastPage = (nextPage == 0);
        
        for (NSDictionary *jsonOutput in jsonOutputs) {
            const uint64_t previousValue = [jsonOutput[@"value"] unsignedLongLongValue];
            WSAddress *previousAddress = WSAddressFromString(jsonOutput[@"to_address"]);
            
            NSAssert([previousAddress isEqual:address], @"Output address should be searched address (%@ != %@)",
                     previousAddress, address);
            
            WSHash256 *previousTxId = WSHash256FromHex(jsonOutput[@"transaction_hash"]);
            const uint32_t previousIndex = [jsonOutput[@"transaction_index"] unsignedIntegerValue];
            
            WSTransactionOutput *previousOutput = [[WSTransactionOutput alloc] initWithValue:previousValue address:previousAddress];
            WSTransactionOutPoint *previousOutpoint = [WSTransactionOutPoint outpointWithTxId:previousTxId index:previousIndex];
            WSSignableTransactionInput *input = [[WSSignableTransactionInput alloc] initWithPreviousOutput:previousOutput outpoint:previousOutpoint];
            
            const BOOL isLast = (isLastPage && (jsonOutput == [jsonOutputs lastObject]));
            BOOL stop = NO;
            handler(input, isLast, &stop);
            if (stop) {
                return;
            }
        }
        
        if (isLastPage) {
            completion();
        }
        else {
        
            // yield to avoid rate limiting
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, WSWebUtilsBiteasyYieldInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self fetchUnspentInputsForAddress:address page:nextPage handler:handler completion:completion failure:failure];
            });
        }
    } failure:^(int statusCode, NSError *error) {
        failure(error ? : WSErrorMake(WSErrorCodeNetworking, @"HTTP %u", statusCode));
    }];
}

- (NSString *)networkName
{
    switch (WSParametersGetCurrentType()) {
        case WSParametersTypeMain: {
            return @"blockchain";
        }
        case WSParametersTypeTestnet3: {
            return @"testnet";
        }
        case WSParametersTypeRegtest: {
            WSExceptionRaiseUnsupported(@"Regtest network is not supported");
        }
    }
    return nil;
}

@end
