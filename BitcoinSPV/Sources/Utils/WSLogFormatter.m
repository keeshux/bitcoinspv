//
//  WSLogFormatter.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 10/07/14.
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

#import "WSLogFormatter.h"

@implementation WSLogFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    NSString *filename = [[NSString stringWithUTF8String:logMessage->file] lastPathComponent];
    
    return [NSString stringWithFormat:@"%@ %@:%d [%s] %@",
            logMessage->timestamp, filename, logMessage->lineNumber, logMessage->queueLabel, logMessage->logMsg];
}

@end
