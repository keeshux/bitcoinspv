//
//  WSSeedGenerator.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/06/14.
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

#import "WSSeedGenerator.h"
#import "WSBIP39.h"
#import "WSConfig.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSSeedGenerator ()

@property (nonatomic, strong) WSBIP39 *bip39;
@property (nonatomic, assign) uint32_t defaultEntropyLength;

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
        NSBundle *bundle = WSClientBundle([self class]);

        self.defaultEntropyLength = WSSeedGeneratorDefaultEntropyBits;
        self.wordsPath = [bundle pathForResource:WSBIP39WordsResource ofType:WSBIP39WordsType];
    }
    return self;
}

- (WSBIP39 *)bip39
{
    if (!_bip39) {
        DDLogInfo(@"No loaded wordList, reloading from: %@", self.wordsPath);
        NSString *wordListString = [NSString stringWithContentsOfFile:self.wordsPath encoding:NSUTF8StringEncoding error:NULL];
        NSArray *wordList = [wordListString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        DDLogInfo(@"Loaded mnemonic wordList (%lu words)", (unsigned long)wordList.count);
//        DDLogVerbose(@"All words: %@", self.wordList);
        
        _bip39 = [[WSBIP39 alloc] initWithWordListNoCopy:wordList];
    }
    return _bip39;
}

- (NSArray *)wordList
{
    return [self.bip39 wordList];
}

- (void)unloadWords
{
    DDLogInfo(@"Unloading mnemonic wordList");
    
    self.bip39 = nil;
}

- (NSString *)generateRandomMnemonic
{
    return [self generateRandomMnemonicWithEntropyLength:self.defaultEntropyLength];
}

- (NSString *)generateRandomMnemonicWithEntropyLength:(uint32_t)entropyLength
{
    WSExceptionCheckIllegal(self.wordsPath);
    
    return [self.bip39 generateRandomMnemonicWithEntropyLength:entropyLength];
}

- (WSSeed *)generateRandomSeed
{
    NSString *seedPhrase = [self generateRandomMnemonic];
    return WSSeedMakeNow(seedPhrase);
}

- (NSString *)mnemonicFromData:(NSData *)data error:(NSError *__autoreleasing *)error
{
    return [self.bip39 mnemonicFromData:data error:error];
}

- (NSData *)dataFromMnemonic:(NSString *)mnemonic error:(NSError *__autoreleasing *)error
{
    return [self.bip39 dataFromMnemonic:mnemonic error:error];
}

- (NSData *)deriveKeyDataFromMnemonic:(NSString *)mnemonic
{
    return [self.bip39 deriveKeyDataFromMnemonic:mnemonic];
}

@end
