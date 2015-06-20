//
//  WSErrors.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 24/06/14.
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

#import "WSErrors.h"

#pragma mark - Exceptions

NSString *const         WSExceptionIllegalArgument                  = @"IllegalArgument";
NSString *const         WSExceptionUnsupported                      = @"Unsupported";

#pragma mark - Errors

NSString *const         WSErrorDomain                               = @"BitcoinSPV";

NSString *const         WSErrorMessageTypeKey                       = @"MessageType";
NSString *const         WSErrorInputAddressKey                      = @"InputAddress";
NSString *const         WSErrorFeeKey                               = @"Fee";

#pragma mark - Macros

#warning XXX: redundant, strange things happen forwarding varargs

void WSExceptionRaiseUnsupported(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    [NSException raise:WSExceptionUnsupported format:format arguments:args];
    va_end(args);
}

void WSExceptionCheck(BOOL condition, NSString *name, NSString *format, ...)
{
    if (!condition) {
        va_list args;
        va_start(args, format);
        [NSException raise:name format:format arguments:args];
        va_end(args);
    }
}

NSError *WSErrorMake(WSErrorCode code, NSString *format, ...)
{
    NSString *description = nil;
    if (format) {
        va_list args;
        va_start(args, format);
        description = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
    }
    NSDictionary *userInfo = nil;
    if (description) {
        userInfo = @{NSLocalizedDescriptionKey: description};
    }
    return [NSError errorWithDomain:WSErrorDomain code:code userInfo:userInfo];
}

void WSErrorSet(NSError **error, WSErrorCode code, NSString *format, ...)
{
    if (error) {
        NSString *description = nil;
        if (format) {
            va_list args;
            va_start(args, format);
            description = [[NSString alloc] initWithFormat:format arguments:args];
            va_end(args);
        }
        NSDictionary *userInfo = nil;
        if (description) {
            userInfo = @{NSLocalizedDescriptionKey: description};
        }
        *error = [NSError errorWithDomain:WSErrorDomain code:code userInfo:userInfo];
    }
}

void WSErrorSetUserInfo(NSError **error, WSErrorCode code, NSDictionary *userInfo, NSString *format, ...)
{
    if (error) {
        NSString *description = nil;
        if (format) {
            va_list args;
            va_start(args, format);
            description = [[NSString alloc] initWithFormat:format arguments:args];
            va_end(args);
        }
        if (description) {
            NSMutableDictionary *descUserInfo = [userInfo mutableCopy];
            descUserInfo[NSLocalizedDescriptionKey] = description;
            userInfo = descUserInfo;
        }
        *error = [NSError errorWithDomain:WSErrorDomain code:code userInfo:userInfo];
    }
}

inline void WSErrorSetNotEnoughBytes(NSError **error, Class clazz, NSUInteger found, NSUInteger expected)
{
    WSErrorSet(error, WSErrorCodeMalformed, @"Premature end of %@ buffer (length: %u < %u)", clazz, found, expected);
}

inline void WSErrorSetNotEnoughMessageBytes(NSError **error, NSString *messageType, NSUInteger found, NSUInteger expected)
{
    WSErrorSet(error, WSErrorCodeMalformed, @"Premature end of '%@' message (length: %u < %u)", messageType, found, expected);
}
