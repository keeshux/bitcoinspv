//
//  WSParametersFactory.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 27/07/14.
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

#import "WSParametersFactory.h"
#import "WSParametersFactoryMain.h"
#import "WSParametersFactoryTestnet3.h"
#import "WSParametersFactoryRegtest.h"
#import "WSErrors.h"

@interface WSParametersFactory ()

@property (nonatomic, strong) id<WSParametersFactory> mainFactory;
@property (nonatomic, strong) id<WSParametersFactory> testnet3Factory;
@property (nonatomic, strong) id<WSParametersFactory> regtestFactory;
@property (nonatomic, strong) NSDictionary *mapping;

@end

@implementation WSParametersFactory

+ (instancetype)sharedInstance
{
    static WSParametersFactory *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if ((self = [super init])) {
        self.mainFactory = [[WSParametersFactoryMain alloc] init];
        self.testnet3Factory = [[WSParametersFactoryTestnet3 alloc] init];
        self.regtestFactory = [[WSParametersFactoryRegtest alloc] init];

        self.mapping = @{@(WSNetworkTypeMain): [self.mainFactory parameters],
                         @(WSNetworkTypeTestnet3): [self.testnet3Factory parameters],
                         @(WSNetworkTypeRegtest): [self.regtestFactory parameters]};
    }
    return self;
}

- (WSParameters *)parametersForNetworkType:(WSNetworkType)networkType
{
    WSParameters *parameters = self.mapping[@(networkType)];
    WSExceptionCheck(parameters != nil, WSExceptionIllegalArgument, @"Unhandled parameters type: %d", networkType);
    return parameters;
}

@end
