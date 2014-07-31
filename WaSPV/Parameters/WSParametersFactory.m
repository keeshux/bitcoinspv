//
//  WSParametersFactory.m
//  WaSPV
//
//  Created by Davide De Rosa on 27/07/14.
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

#import "WSParametersFactory.h"
#import "WSParametersFactoryMain.h"
#import "WSParametersFactoryTestnet3.h"
#import "WSParametersFactoryRegtest.h"

@interface WSParametersFactory ()

@property (nonatomic, strong) id<WSParametersFactory> currentFactory;
@property (nonatomic, strong) id<WSParametersFactory> mainFactory;
@property (nonatomic, strong) id<WSParametersFactory> testnet3Factory;
@property (nonatomic, strong) id<WSParametersFactory> regtestFactory;

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

        // default to testnet3
        self.parametersType = WSParametersTypeTestnet3;
    }
    return self;
}

- (void)setParametersType:(WSParametersType)parametersType
{
    _parametersType = parametersType;
    
    switch (parametersType) {
        case WSParametersTypeMain: {
            self.currentFactory = self.mainFactory;
            break;
        }
        case WSParametersTypeTestnet3: {
            self.currentFactory = self.testnet3Factory;
            break;
        }
        case WSParametersTypeRegtest: {
            self.currentFactory = self.regtestFactory;
            break;
        }
        default: {
            WSExceptionCheckIllegal(NO, @"Unhandled parameters type: %d", parametersType);
            break;
        }
    }
}

#pragma mark WSParametersFactory

- (id<WSParameters>)parameters
{
    return [self.currentFactory parameters];
}

@end

NSString *WSParametersTypeString(WSParametersType type)
{
    static dispatch_once_t onceToken;
    static NSMutableDictionary *strings;
    
    dispatch_once(&onceToken, ^{
        strings = [[NSMutableDictionary alloc] initWithCapacity:3];
        strings[@(WSParametersTypeMain)] = @"Main";
        strings[@(WSParametersTypeTestnet3)] = @"Testnet3";
        strings[@(WSParametersTypeRegtest)] = @"Regtest";
    });
    
    return strings[@(type)];
}
