//
//  WSBIP39.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 13/06/14.
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

//
// Mnemonic code for HD wallets
//
// https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
//

extern NSString *const          WSBIP39WordsResource;
extern NSString *const          WSBIP39WordsType;
extern const CFStringRef        WSBIP39SaltPrefix;
extern const NSUInteger         WSBIP39SaltPrefixLength;

#pragma mark -

@interface WSBIP39 : NSObject

- (instancetype)initWithWordListNoCopy:(NSArray *)wordList;
- (NSArray *)wordList;

- (NSString *)generateRandomMnemonicWithEntropyLength:(uint32_t)entropyLength;
- (NSString *)mnemonicFromData:(NSData *)data error:(NSError **)error;
- (NSData *)dataFromMnemonic:(NSString *)mnemonic error:(NSError **)error;
- (NSData *)deriveKeyDataFromMnemonic:(NSString *)mnemonic;
- (NSData *)deriveKeyDataFromMnemonic:(NSString *)mnemonic passphrase:(NSString *)passphrase;

@end
