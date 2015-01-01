//
//  WSWebExplorer.m
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

#import "WSWebExplorer.h"
#import "WSWebExplorerBiteasy.h"
#import "WSWebExplorerBlockExplorer.h"
#import "WSWebExplorerBlockr.h"
#import "WSWebExplorerBlockchain.h"
#import "WSErrors.h"

NSString *const WSWebExplorerProviderBiteasy           = @"WSWebExplorerBiteasy";
NSString *const WSWebExplorerProviderBlockExplorer     = @"WSWebExplorerBlockExplorer";
NSString *const WSWebExplorerProviderBlockr            = @"WSWebExplorerBlockr";
NSString *const WSWebExplorerProviderBlockchain        = @"WSWebExplorerBlockchain";

@implementation WSWebExplorerFactory

+ (id<WSWebExplorer>)explorerForProvider:(NSString *)provider
{
    WSExceptionCheckIllegal(provider.length > 0, @"Empty provider");
    
    Class clazz = NSClassFromString(provider);
    WSExceptionCheckIllegal(clazz != nil, @"Unknown provider (%@)", provider);
    return [[clazz alloc] init];
}

@end
