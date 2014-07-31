//
//  WSMessageHeaders.m
//  WaSPV
//
//  Created by Davide De Rosa on 08/07/14.
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

#import "WSMessageHeaders.h"
#import "WSBlockHeader.h"

@interface WSMessageHeaders ()

@property (nonatomic, strong) NSArray *headers;

@end

@implementation WSMessageHeaders

#pragma mark WSMessage

- (NSString *)messageType
{
    return WSMessageType_HEADERS;
}

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];
    for (WSBlockHeader *header in self.headers) {
        [tokens addObject:[header descriptionWithIndent:(indent + 1)]];
    }
    return [NSString stringWithFormat:@"{%@}", WSStringDescriptionFromTokens(tokens, indent)];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    WSExceptionRaiseUnsupported(@"%@ is not encodable", [self class]);
}

#pragma mark WSBufferDecoder

- (instancetype)initWithBuffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithOriginalPayload:buffer])) {
        NSUInteger offset = from;
        NSUInteger varIntLength;

        const NSUInteger count = (NSUInteger)[buffer varIntAtOffset:offset length:&varIntLength];
        if (count > WSMessageHeadersMaxCount) {
            WSErrorSet(error, WSErrorCodeMalformed, @"Too many headers (%u > %u)", count, WSMessageHeadersMaxCount);
            return nil;
        }
        offset += varIntLength;

        const NSUInteger expectedLength = varIntLength + count * WSBlockHeaderLength;
        if (available < expectedLength) {
            WSErrorSetNotEnoughBytes(error, [self class], available, expectedLength);
            return nil;
        }

        NSMutableArray *headers = [[NSMutableArray alloc] initWithCapacity:count];
        for (NSUInteger i = 0; i < count; ++i) {
            WSBlockHeader *header = [[WSBlockHeader alloc] initWithBuffer:buffer
                                                                     from:offset
                                                                available:(available - offset + from)
                                                                    error:error];
            if (!header) {
                return nil;
            }
            [headers addObject:header];
            offset += WSBlockHeaderLength;
        }
        self.headers = headers;
    }
    return self;
}

@end
