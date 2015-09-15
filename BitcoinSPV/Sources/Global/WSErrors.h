//
//  WSErrors.h
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

#import <Foundation/Foundation.h>

#pragma mark - Exceptions

extern NSString *const          WSExceptionIllegalArgument;
extern NSString *const          WSExceptionUnsupported;

#pragma mark - Errors

extern NSString *const          WSErrorDomain;

typedef enum {
    WSErrorCodeMaskGeneric              = 0x0100,
    WSErrorCodeMalformed,
    WSErrorCodeUnknownMessage,
    WSErrorCodeUndecodableMessage,
    WSErrorCodeNetworking,
    WSErrorCodeConnectionTimeout,
    WSErrorCodeWebService,
    //
    WSErrorCodeMaskPeerGroup            = 0x0200,
    WSErrorCodePeerGroupTimeout,
    WSErrorCodePeerGroupDownload,
    WSErrorCodePeerGroupStop,
    WSErrorCodePeerGroupRescan,
    //
    WSErrorCodeMaskInvalid              = 0x0400,
    WSErrorCodeInvalidBlock,
    WSErrorCodeInvalidPartialMerkleTree,
    WSErrorCodeInvalidTransaction,
    //
    WSErrorCodeMaskWallet               = 0x0800,
    WSErrorCodeInsufficientFunds,
    WSErrorCodeSignature,
    WSErrorCodeBIP39BadMnemonic
} WSErrorCode;

extern NSString *const          WSErrorMessageTypeKey;
extern NSString *const          WSErrorFeeKey;
extern NSString *const          WSErrorInputAddressKey;

#pragma mark - Macros

void WSExceptionRaiseUnsupported(NSString *format, ...);
void WSExceptionCheck(BOOL condition, NSString *name, NSString *format, ...);

//void WSExceptionCheckIllegal(BOOL condition, NSString *format, ...);
#define WSExceptionCheckIllegal(condition) \
    if (!(condition)) { \
        [NSException raise:WSExceptionIllegalArgument format:@"%s", #condition]; \
    }

NSError *WSErrorMake(WSErrorCode code, NSString *format, ...);
void WSErrorSet(NSError **error, WSErrorCode code, NSString *format, ...);
void WSErrorSetUserInfo(NSError **error, WSErrorCode code, NSDictionary *userInfo, NSString *format, ...);
void WSErrorSetNotEnoughBytes(NSError **error, Class bufferClass, NSUInteger found, NSUInteger expected);
void WSErrorSetNotEnoughMessageBytes(NSError **error, NSString *messageType, NSUInteger found, NSUInteger expected);

static inline BOOL WSErrorCodeIsMask(WSErrorCode code, WSErrorCode mask)
{
    return ((code & 0xff00) == mask);
}
