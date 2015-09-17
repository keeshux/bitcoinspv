//
//  WSMessageBlock.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/12/14.
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

#import "WSMessageBlock.h"
#import "WSBlock.h"
#import "WSErrors.h"

@interface WSMessageBlock ()

@property (nonatomic, strong) WSBlock *block;

@end

@implementation WSMessageBlock

#pragma mark WSMessage

- (NSString *)messageType
{
    return WSMessageType_BLOCK;
}

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    return [self.block descriptionWithIndent:indent];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    WSExceptionRaiseUnsupported(@"%@ is not encodable", [self class]);
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithParameters:parameters originalLength:buffer.length])) {
        self.block = [[WSBlock alloc] initWithParameters:parameters buffer:buffer from:from available:available error:error];
        if (!self.block) {
            return nil;
        }
    }
    return self;
}

@end
