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
#import "WSAddress.h"
#import "WSTransactionInput.h"
#import "WSTransactionOutPoint.h"
#import "WSTransactionOutput.h"
#import "WSTransaction.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"

static NSString *const         WSWebUtilsBiteasyBaseURLFormat           = @"https://api.biteasy.com/%@/v1/";
static const NSTimeInterval    WSWebUtilsBiteasyYieldInterval           = 1;
static NSString *const         WSWebUtilsBiteasyUnspentFormat           = @"addresses/%@/unspent-outputs?page=%u&per_page=%u";
static const NSUInteger        WSWebUtilsBiteasyUnspentPerPage          = 100;

@interface WSWebUtils ()

- (void)fetchUnspentInputsForAddress:(WSAddress *)address
                                page:(NSUInteger)page
                             handler:(void (^)(WSSignableTransactionInput *))handler
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

- (void)buildSweepTransactionFromKey:(WSKey *)fromKey
                           toAddress:(WSAddress *)toAddress
                                 fee:(uint64_t)fee
                             success:(void (^)(WSSignedTransaction *))success
                             failure:(void (^)(NSError *))failure
{
    WSExceptionCheckIllegal(fromKey != nil, @"Nil fromKey");
    WSExceptionCheckIllegal(toAddress != nil, @"Nil toAddress");
    WSExceptionCheckIllegal(success != nil, @"Nil success");
    WSExceptionCheckIllegal(failure != nil, @"Nil failure");
    
    WSAddress *fromAddress = [fromKey address];
    WSTransactionBuilder *builder = [[WSTransactionBuilder alloc] init];
    
#warning FIXME: transaction size not capped, split sweep operation into several transactions

    // XXX: unspent outputs may be _A LOT_
    //
    // https://api.biteasy.com/testnet/v1/addresses/muyDoehpBExCbRRXLtDUpw5DaTb33UZeyG/unspent-outputs
    
    [self fetchUnspentInputsForAddress:fromAddress page:1 handler:^(WSSignableTransactionInput *input) {
        [builder addSignableInput:input];
    } completion:^{
        DDLogVerbose(@"Sweep inputs (%u): %@", builder.signableInputs.count, builder.signableInputs);
        DDLogVerbose(@"Sweep input value: %llu", [builder inputValue]);

        if (![builder addSweepOutputAddress:toAddress fee:fee]) {
            failure(WSErrorMake(WSErrorCodeInsufficientFunds, @"Unspent balance is less than fee + min output value"));
            return;
        }

        DDLogVerbose(@"Sweep output value: %llu", [builder outputValue]);
        DDLogVerbose(@"Sweep fee: %llu", [builder fee]);

        NSError *error;
        NSDictionary *keys = @{fromAddress: fromKey};
        WSSignedTransaction *transaction = [builder signedTransactionWithInputKeys:keys error:&error];
        if (!transaction) {
            failure(error);
            return;
        }

        DDLogVerbose(@"Sweep transaction: %@", transaction);
        success(transaction);

    } failure:failure];
}

- (void)fetchUnspentInputsForAddress:(WSAddress *)address
                                page:(NSUInteger)page
                             handler:(void (^)(WSSignableTransactionInput *))handler
                          completion:(void (^)())completion
                             failure:(void (^)(NSError *))failure
{
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:WSWebUtilsBiteasyBaseURLFormat, [self networkName]]];
    NSString *path = [NSString stringWithFormat:WSWebUtilsBiteasyUnspentFormat, address, page, WSWebUtilsBiteasyUnspentPerPage];
    
    [[WSJSONClient sharedInstance] asynchronousRequestWithBaseURL:baseURL path:path success:^(int statusCode, id object) {
        NSDictionary *jsonData = object[@"data"];
        NSArray *jsonOutputs = jsonData[@"outputs"];
        NSDictionary *jsonPagination = jsonData[@"pagination"];
        
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
            
            handler(input);
        }
        
        const NSUInteger nextPage = [jsonPagination[@"next_page"] unsignedIntegerValue];
        if (nextPage > 0) {
            
            // yield to avoid rate limiting
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, WSWebUtilsBiteasyYieldInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self fetchUnspentInputsForAddress:address page:nextPage handler:handler completion:completion failure:failure];
            });
        }
        else {
            completion();
        }
    } failure:^(int statusCode, NSError *error) {
        failure(error);
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
