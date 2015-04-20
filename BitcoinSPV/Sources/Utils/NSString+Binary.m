//
//  NSString+Binary.m
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

#import "NSString+Binary.h"

@implementation NSString (Binary)

- (NSData *)dataFromHex
{
    if (self.length & 1) {
        return nil;
    }
    
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:(self.length / 2)];
    uint8_t byte = 0;
    for (NSUInteger i = 0; i < self.length; i++) {
        uint8_t c = [self characterAtIndex:i];
        
        if ((c >= '0') && (c <= '9')) {
            byte += c - '0';
        }
        else {
            c &= ~(1 << 5); // uppercase

            if ((c >= 'A') && (c <= 'F')) {
                byte += c + 10 - 'A';
            }
            else {
                return data;
            }
        }
        
        if (i % 2) {
            [data appendBytes:&byte length:1];
            byte = 0;
        }
        else {
            byte *= 16;
        }
    }
    
    return data;
}

@end
