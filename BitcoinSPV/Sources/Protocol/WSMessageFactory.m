//
//  WSMessageFactory.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 06/07/14.
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

#import "WSMessageFactory.h"
#import "WSErrors.h"

@interface WSMessageFactory ()

@property (nonatomic, strong) WSParameters *parameters;

@end

@implementation WSMessageFactory

- (instancetype)initWithParameters:(WSParameters *)parameters
{
    WSExceptionCheckIllegal(parameters);
    
    if ((self = [super init])) {
        self.parameters = parameters;
    }
    return self;
}

- (id<WSMessage>)messageFromType:(NSString *)type payload:(WSBuffer *)payload error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(type);
    WSExceptionCheckIllegal(payload);
    
#warning XXX: would not handle messages of type "factory" in the future (rename class?)
    
    NSString *className = [NSString stringWithFormat:@"WSMessage%@", [type capitalizedString]];
    Class clazz = NSClassFromString(className);
    if (!clazz || (clazz == [self class])) {
        WSErrorSetUserInfo(error, WSErrorCodeUnknownMessage, @{WSErrorMessageTypeKey: type}, @"Unknown message '%@'", type);
        return nil;
    }
    if (![clazz conformsToProtocol:@protocol(WSBufferDecoder)]) {
        WSErrorSet(error, WSErrorCodeUndecodableMessage, @"Undecodable message '%@'", type);
        return nil;
    }
    id<WSMessage> message = [[clazz alloc] initWithParameters:self.parameters buffer:payload from:0 available:payload.length error:error];
//    if (message) {
//        NSAssert(message.originalPayload, @"Decoded messages should retain original payload");
//    }
    return message;
}

@end
