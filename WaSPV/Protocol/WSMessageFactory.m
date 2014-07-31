//
//  WSMessageFactory.m
//  WaSPV
//
//  Created by Davide De Rosa on 06/07/14.
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

#import "WSMessageFactory.h"

@implementation WSMessageFactory

+ (instancetype)sharedInstance
{
    static WSMessageFactory *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id<WSMessage>)messageFromType:(NSString *)type payload:(WSBuffer *)payload error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(type != nil, @"Nil type");
    WSExceptionCheckIllegal(payload != nil, @"Nil payload");
    
#warning XXX: would not handle messages of type "factory" in the future (rename class?)
    
    NSString *className = [NSString stringWithFormat:@"WSMessage%@", [type capitalizedString]];
    Class clazz = NSClassFromString(className);
    if (!clazz) {
        WSErrorSet(error, WSErrorCodeUnknownMessage, @"Unknown message '%@'", type);
        return nil;
    }
    if (![clazz conformsToProtocol:@protocol(WSBufferDecoder)]) {
        WSErrorSet(error, WSErrorCodeUndecodableMessage, @"Undecodable message '%@'", type);
        return nil;
    }
    id<WSMessage> message = [[clazz alloc] initWithBuffer:payload from:0 available:payload.length error:error];
    if (message) {
        NSAssert(message.originalPayload, @"Decoded messages should retain original payload");
    }
    return message;
}

@end
