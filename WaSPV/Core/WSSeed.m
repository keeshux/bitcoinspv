//
//  WSSeed.m
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

#import "WSSeed.h"
#import "WSSeedGenerator.h"

@interface WSSeed ()

@property (nonatomic, copy) NSString *seedPhrase;
@property (nonatomic, assign) NSTimeInterval creationTime;

@end

@implementation WSSeed

- (instancetype)initWithSeedPhrase:(NSString *)seedPhrase
{
    return [self initWithSeedPhrase:seedPhrase creationTime:[NSDate timeIntervalSinceReferenceDate]];
}

- (instancetype)initWithSeedPhrase:(NSString *)seedPhrase creationTime:(NSTimeInterval)creationTime
{
    WSExceptionCheckIllegal(seedPhrase != nil, @"Nil seedPhrase");
//    WSExceptionCheckIllegal(creationTime >= 0.0, @"creationTime must be positive");

    if ((self = [super init])) {
        WSSeedGenerator *bip = [WSSeedGenerator sharedInstance];

        NSData *seedData = [bip dataFromMnemonic:seedPhrase error:nil];
        if (!seedData) {
            return nil;
        }
        NSAssert1([[bip mnemonicFromData:seedData error:nil] isEqualToString:seedPhrase],
                  @"Seedphrase reencoding test failed: '%@'", seedPhrase);

        self.seedPhrase = seedPhrase;
        self.creationTime = creationTime;
    }
    return self;
}

- (NSData *)derivedKeyData
{
    return [[WSSeedGenerator sharedInstance] deriveKeyDataFromMnemonic:self.seedPhrase passphrase:nil];
}

@end
