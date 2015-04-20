//
//  WSNetworkType.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 04/01/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
//

#import "WSNetworkType.h"

NSString *WSNetworkTypeString(WSNetworkType type)
{
    static dispatch_once_t onceToken;
    static NSMutableDictionary *strings;
    
    dispatch_once(&onceToken, ^{
        strings = [[NSMutableDictionary alloc] initWithCapacity:3];
        strings[@(WSNetworkTypeMain)] = @"Main";
        strings[@(WSNetworkTypeTestnet3)] = @"Testnet3";
        strings[@(WSNetworkTypeRegtest)] = @"Regtest";
    });
    
    return strings[@(type)];
}
