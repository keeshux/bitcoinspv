//
//  WSSeedGenerator.m
//  WaSPV
//
//  Created by Davide De Rosa on 08/06/14.
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

#import <openssl/crypto.h>
#import <CommonCrypto/CommonCrypto.h>
#import "DDLog.h"

#import "WSSeedGenerator.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"
#import "NSData+Hash.h"

// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRBIP39Mnemonic.m

@interface WSSeedGenerator ()

@property (nonatomic, assign) uint32_t defaultEntropyLength;
@property (nonatomic, strong) NSArray *wordList;

@end

@implementation WSSeedGenerator

+ (instancetype)sharedInstance
{
    static WSSeedGenerator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if ((self = [super init])) {
        self.defaultEntropyLength = WSSeedGeneratorDefaultEntropyBits;
        self.wordsPath = [[NSBundle bundleForClass:[self class]] pathForResource:WSBIP39WordsResource ofType:WSBIP39WordsType];
    }
    return self;
}

- (NSArray *)wordList
{
    WSExceptionCheckIllegal(self.wordsPath != nil, @"No wordsPath was set");

    if (!_wordList) {
        DDLogInfo(@"No loaded wordList, reloading from: %@", self.wordsPath);
        NSString *wordListString = [NSString stringWithContentsOfFile:self.wordsPath encoding:NSUTF8StringEncoding error:NULL];
        self.wordList = [wordListString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        DDLogInfo(@"Loaded mnemonic wordList (%d words)", self.wordList.count);
//        DDLogVerbose(@"All words: %@", self.wordList);
    }
    return _wordList;
}

- (void)unloadWords
{
    DDLogInfo(@"Unloading mnemonic wordList");
    
    self.wordList = nil;
}

- (WSSeed *)generateRandomSeed
{
    NSString *seedPhrase = [self generateRandomMnemonic];
    return WSSeedMakeNow(seedPhrase);
}

#pragma mark WSBIP39

- (NSString *)generateRandomMnemonic
{
    return [self generateRandomMnemonicWithEntropyLength:self.defaultEntropyLength];
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
    WSExceptionCheckIllegal((data.length > 0) && (data.length % 4 == 0),
                            @"Data length %u is not a positive multiple of 4", data.length);
    
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
    WSExceptionCheckIllegal(mnemonic != nil, @"Nil mnemonic");
    
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
    const int count = (mnemWords.count * 11 + 7) / 8;
    
    for (int i = 0; i < count; ++i) {
        const int wi = i * 8 / 11;
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
    WSExceptionCheckIllegal(mnemonic != nil, @"Nil mnemonic");

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
