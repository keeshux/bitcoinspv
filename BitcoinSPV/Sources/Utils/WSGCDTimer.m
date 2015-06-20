//
//  WSGCDTimer.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 25/07/14.
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

#import "WSErrors.h"

#import "WSGCDTimer.h"

// adapted from: https://gist.github.com/maicki/7622108

@interface WSGCDTimer ()

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) double interval;
@property (nonatomic, strong) dispatch_source_t timer;

@end

@implementation WSGCDTimer

- (instancetype)initWithQueue:(dispatch_queue_t)queue interval:(double)interval
{
    WSExceptionCheckIllegal(queue);
    WSExceptionCheckIllegal(interval > 0.0);
    
    if ((self = [super init])) {
        self.queue = queue;
        self.interval = interval;
    }
    return self;
}

- (void)dealloc
{
    [self cancel];
}

- (BOOL)startWithBlock:(dispatch_block_t)block
{
    WSExceptionCheckIllegal(block);

    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    if (!self.timer) {
        return NO;
    }

    const int64_t nanoInterval = self.interval * NSEC_PER_SEC;
    
    dispatch_source_set_timer(self.timer,
                              dispatch_time(DISPATCH_TIME_NOW, nanoInterval),
                              nanoInterval,
                              (1ULL * NSEC_PER_SEC) / 10);

    dispatch_source_set_event_handler(self.timer, block);
    dispatch_resume(self.timer);

    return YES;
}

- (void)cancel
{
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = NULL;
    }
}

@end
