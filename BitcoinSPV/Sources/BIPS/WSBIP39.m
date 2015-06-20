//
//  WSBIP39.m
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

#import <openssl/crypto.h>
#import <CommonCrypto/CommonCrypto.h>

#import "WSBIP39.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "NSData+Hash.h"

NSString *const         WSBIP39WordsResource                    = @"WSBIP39Words";
NSString *const         WSBIP39WordsType                        = @"txt";
const CFStringRef       WSBIP39SaltPrefix                       = CFSTR("mnemonic");
const NSUInteger        WSBIP39SaltPrefixLength                 = 8;

// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRBIP39Mnemonic.m

@interface WSBIP39 ()

@property (nonatomic, strong) NSArray *wordList;

@end

@implementation WSBIP39

- (instancetype)initWithWordListNoCopy:(NSArray *)wordList
{
    WSExceptionCheckIllegal(wordList.count > 0);
    
    if ((self = [super init])) {
        self.wordList = wordList;
    }
    return self;
}

- (NSString *)generateRandomMnemonicWithEntropyLength:(uint32_t)entropyLength
{
    const NSUInteger entropyBytesLength = entropyLength / 8;
    NSMutableData *entropy = [[NSMutableData alloc] initWithLength:entropyBytesLength];
    SecRandomCopyBytes(kSecRandomDefault, entropy.length, entropy.mutableBytes);
    return [self mnemonicFromData:entropy error:nil];
}

- (NSString *)mnemonicFromData:(NSData *)data error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal((data.length > 0) && (data.length % 4 == 0));
    
    const NSUInteger mnemLength = data.length * 3 / 4;
    NSMutableArray *mnemWords = [[NSMutableArray alloc] initWithCapacity:mnemLength];
    NSMutableData *mnemData = [data mutableCopy];
    [mnemData appendData:[data SHA256]]; // checksum
    
    const uint32_t n = (uint32_t)self.wordList.count;
    uint32_t x;
    for (int i = 0; i < mnemLength; ++i) {
        x = CFSwapInt32BigToHost(*(const uint32_t *)((const uint8_t *)mnemData.bytes + i * 11 / 8));
        const int wi = (x >> (sizeof(x) * 8 - (11 + ((i * 11) % 8)))) % n;
        
        NSString *word = self.wordList[wi];
        [mnemWords addObject:word];
    }
    OPENSSL_cleanse(&x, sizeof(x));
    
    return [mnemWords componentsJoinedByString:@" "];
}

- (NSData *)dataFromMnemonic:(NSString *)mnemonic error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(mnemonic);
    
    NSArray *mnemWords = [mnemonic componentsSeparatedByString:@" "];
    NSMutableData *mnemData = [[NSMutableData alloc] initWithCapacity:(mnemWords.count * 11 + 7) / 8];
    uint32_t x, y;
    uint8_t b;
    
    if ((mnemWords.count % 3 != 0) || (mnemWords.count > 24)) {
        WSErrorSet(error, WSErrorCodeBIP39BadMnemonic, @"Word count %u is not a multiple of 3 up to 24",
                   mnemWords.count);
        
        return nil;
    }
    
    const uint32_t n = (uint32_t)self.wordList.count;
    const NSUInteger count = (mnemWords.count * 11 + 7) / 8;
    
    for (NSUInteger i = 0; i < count; ++i) {
        const NSUInteger wi = i * 8 / 11;
        x = (uint32_t)[self.wordList indexOfObject:mnemWords[wi]];
        
        if (wi + 1 < mnemWords.count) {
            y = (uint32_t)[self.wordList indexOfObject:mnemWords[wi + 1]];
        }
        else {
            y = 0;
        }
        
        if (x == (uint32_t)NSNotFound) {
            WSErrorSet(error, WSErrorCodeBIP39BadMnemonic, @"Unknown word: '%@'", mnemWords[wi]);
            return nil;
        }
        if (y == (uint32_t)NSNotFound) {
            WSErrorSet(error, WSErrorCodeBIP39BadMnemonic, @"Unknown word: '%@'", mnemWords[wi + 1]);
            return nil;
        }
        
        b = ((x * n + y) >> ((wi + 2) * 11 - (i + 1) * 8)) & 0xff;
        
        [mnemData appendBytes:&b length:1];
    }
    
    b = *((const uint8_t *)mnemData.bytes + mnemWords.count * 4 / 3) >> (8 - mnemWords.count / 3);
    mnemData.length = mnemWords.count * 4 / 3;
    
    if (b != (*(const uint8_t *)[mnemData SHA256].bytes >> (8 - mnemWords.count / 3))) {
        WSErrorSet(error, WSErrorCodeMalformed, nil);
        return nil;
    }
    
    OPENSSL_cleanse(&x, sizeof(x));
    OPENSSL_cleanse(&y, sizeof(y));
    OPENSSL_cleanse(&b, sizeof(b));
    return mnemData;
}

- (NSData *)deriveKeyDataFromMnemonic:(NSString *)mnemonic
{
    return [self deriveKeyDataFromMnemonic:mnemonic passphrase:nil];
}

- (NSData *)deriveKeyDataFromMnemonic:(NSString *)mnemonic passphrase:(NSString *)passphrase
{
    WSExceptionCheckIllegal(mnemonic.length > 0);
    WSExceptionCheckIllegal(!passphrase || (passphrase.length > 0));
    
    NSMutableData *key = [[NSMutableData alloc] initWithLength:CC_SHA512_DIGEST_LENGTH];
    CFMutableStringRef password = CFStringCreateMutableCopy(NULL, mnemonic.length, (CFStringRef)mnemonic);
    CFMutableStringRef salt = CFStringCreateMutableCopy(NULL, WSBIP39SaltPrefixLength + passphrase.length, WSBIP39SaltPrefix);
    if (passphrase) {
        CFStringAppend(salt, (CFStringRef)passphrase);
    }
    CFStringNormalize(password, kCFStringNormalizationFormKD);
    CFStringNormalize(salt, kCFStringNormalizationFormKD);
    
    NSData *passwordData = CFBridgingRelease(CFStringCreateExternalRepresentation(NULL, password, kCFStringEncodingUTF8, 0));
    NSData *saltData = CFBridgingRelease(CFStringCreateExternalRepresentation(NULL, salt, kCFStringEncodingUTF8, 0));
    CFRelease(password);
    CFRelease(salt);
    
    CCKeyDerivationPBKDF(kCCPBKDF2, passwordData.bytes, passwordData.length, saltData.bytes, saltData.length,
                         kCCPRFHmacAlgSHA512, 2048, key.mutableBytes, key.length);
    
    return key;
}

@end
