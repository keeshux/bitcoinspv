//
//  WSSeed.m
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

#import "WSSeed.h"
#import "WSSeedGenerator.h"
#import "WSErrors.h"

@interface WSSeed ()

@property (nonatomic, copy) NSString *mnemonic;
@property (nonatomic, assign) NSTimeInterval creationTime;

@end

@implementation WSSeed

- (instancetype)initWithMnemonic:(NSString *)mnemonic
{
    return [self initWithMnemonic:mnemonic creationTime:[NSDate timeIntervalSinceReferenceDate]];
}

- (instancetype)initWithMnemonic:(NSString *)mnemonic creationTime:(NSTimeInterval)creationTime
{
    WSExceptionCheckIllegal(mnemonic);
//    WSExceptionCheckIllegal(creationTime >= 0.0);

    if ((self = [super init])) {
        WSSeedGenerator *generator = [WSSeedGenerator sharedInstance];

        NSData *mnemonicData = [generator dataFromMnemonic:mnemonic error:NULL];
        if (!mnemonicData) {
            return nil;
        }
        NSAssert([[generator mnemonicFromData:mnemonicData error:NULL] isEqualToString:mnemonic],
                 @"Mnemonic reencoding test failed: '%@'", mnemonic);

        self.mnemonic = mnemonic;
        self.creationTime = creationTime;
    }
    return self;
}

- (NSData *)derivedKeyData
{
    return [[WSSeedGenerator sharedInstance] deriveKeyDataFromMnemonic:self.mnemonic];
}

@end
