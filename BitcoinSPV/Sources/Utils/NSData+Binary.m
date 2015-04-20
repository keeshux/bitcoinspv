//
//  NSData+Binary.m
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

#import "NSData+Binary.h"

@implementation NSData (Binary)

- (NSString *)hexString
{
    const uint8_t *bytes = self.bytes;
    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:(2 * self.length)];
    for (NSUInteger i = 0; i < self.length; ++i) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return hex;
}

- (NSData *)reverse
{
    const NSUInteger length = self.length;
    NSMutableData *data = [NSMutableData dataWithLength:length];

    uint8_t *b1 = data.mutableBytes;
    const uint8_t *b2 = self.bytes;
    
    for (NSUInteger i = 0; i < length; ++i) {
        b1[i] = b2[length - i - 1];
    }
    return data;
}

@end
