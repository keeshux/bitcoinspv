//
//  WSBIP38.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 07/12/14.
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

#import "WSKey.h"

// WARNING: BIP38 makes no network distinction

extern const NSUInteger WSBIP38KeyLength;
extern const NSUInteger WSBIP38KeyHeaderLength;

extern const NSUInteger WSBIP38KeyPrefixNonEC;
extern const NSUInteger WSBIP38KeyPrefixEC;

extern const NSUInteger WSBIP38KeyFlagsNonEC;
extern const NSUInteger WSBIP38KeyFlagsCompressed;
extern const NSUInteger WSBIP38KeyFlagsLotSequence;
extern const NSUInteger WSBIP38KeyFlagsInvalid;

@interface WSBIP38Key : NSObject

- (instancetype)initWithEncrypted:(NSString *)encrypted;
- (instancetype)initWithParameters:(WSParameters *)parameters key:(WSKey *)key passphrase:(NSString *)passphrase; // ec = NO
//- (instancetype)initWithParameters:(WSParameters *)parameters key:(WSKey *)key passphrase:(NSString *)passphrase ec:(BOOL)ec;

- (NSString *)encrypted;
- (NSData *)encryptedData;
- (uint16_t)prefix;
- (uint8_t)flags;
- (uint32_t)addressHash;
- (BOOL)isEC;
- (BOOL)isCompressed;

- (WSKey *)decryptedKeyWithPassphrase:(NSString *)passphrase;

@end

#pragma mark -

@interface WSKey (BIP38)

- (WSBIP38Key *)encryptedBIP38KeyWithParameters:(WSParameters *)parameters passphrase:(NSString *)passphrase; // ec = NO
//- (WSBIP38Key *)encryptedBIP38KeyWithParameters:(WSParameters *)parameters passphrase:(NSString *)passphrase ec:(BOOL)ec;

@end
