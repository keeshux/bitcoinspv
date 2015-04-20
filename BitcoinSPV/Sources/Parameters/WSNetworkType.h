//
//  WSNetworkType.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 04/01/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    WSNetworkTypeMain = 1,
    WSNetworkTypeTestnet3,
    WSNetworkTypeRegtest
} WSNetworkType;

NSString *WSNetworkTypeString(WSNetworkType type);
