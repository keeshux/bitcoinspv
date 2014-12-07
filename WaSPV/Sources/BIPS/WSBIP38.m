//
//  WSBIP38.m
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

#import "WSBIP38.h"
#import "WSErrors.h"
#import "NSString+Base58.h"
#import "NSData+Base58.h"

const NSUInteger                WSBIP38KeyLength            = 39;
const NSUInteger                WSBIP38KeyNonECPrefix       = 0x0142;
const NSUInteger                WSBIP38KeyECPrefix          = 0x0143;

@interface WSBIP38Key ()

@property (nonatomic, assign) BOOL isEC;
@property (nonatomic, copy) NSData *encryptedData;

@end

@implementation WSBIP38Key

- (instancetype)initWithEncrypted:(NSString *)encrypted
{
    WSExceptionCheckIllegal(encrypted != nil, @"Nil encrypted");

    NSData *encryptedData = [encrypted dataFromBase58Check];
    WSExceptionCheckIllegal(encryptedData.length == WSBIP38KeyLength,
                            @"Incorrect BIP38 key length (%u != %u)",
                            encryptedData.length, WSBIP38KeyLength);
    
    const uint16_t prefix = CFSwapInt16BigToHost(*(const uint16_t *)encryptedData.bytes);
    WSExceptionCheckIllegal((prefix == WSBIP38KeyNonECPrefix) || (prefix == WSBIP38KeyECPrefix),
                            @"Illegal BIP38 key prefix (%x != %x | %x)",
                            prefix, WSBIP38KeyNonECPrefix, WSBIP38KeyECPrefix);

    if ((self = [super init])) {
        self.encryptedData = encryptedData;
        self.isEC = (prefix == WSBIP38KeyECPrefix);
    }
    return self;
}

- (instancetype)initWithKey:(WSKey *)key passphrase:(NSString *)passphrase
{
    WSExceptionCheckIllegal(key != nil, @"Nil key");
    WSExceptionCheckIllegal(passphrase != nil, @"Nil passphrase");

    if ((self = [super init])) {
#warning TODO: BIP38 encryption
    }
    return self;
}

- (NSString *)encrypted
{
    return [self.encryptedData base58CheckString];
}

@end

#pragma mark -

@implementation WSKey (BIP38)

- (instancetype)initWithBIP38Key:(WSBIP38Key *)key passphrase:(NSString *)passphrase
{
    WSExceptionCheckIllegal(key != nil, @"Nil key");
    WSExceptionCheckIllegal(passphrase != nil, @"Nil passphrase");

    if ((self = [super init])) {
#warning TODO: BIP38 decryption
    }
    return self;
}

@end
