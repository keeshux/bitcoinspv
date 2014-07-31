//
//  WSConnectionPool.h
//  WaSPV
//
//  Created by Davide De Rosa on 07/07/14.
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

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

#pragma mark -

//
// must be thread-safe
//
@protocol WSConnectionWriter <NSObject>

- (void)writeData:(NSData *)data timeout:(NSTimeInterval)timeout;
- (void)disconnectWithError:(NSError *)error;

@end

@protocol WSConnectionProcessor <NSObject>

- (void)setWriter:(id<WSConnectionWriter>)writer;
- (void)openedConnectionToHost:(NSString *)host port:(uint16_t)port queue:(dispatch_queue_t)queue;
- (void)processData:(NSData *)data;
- (void)closedConnectionWithError:(NSError *)error;

@end

#pragma mark -

//
// thread-safe
//
@interface WSConnectionPool : NSObject <GCDAsyncSocketDelegate>

@property (atomic, assign) NSTimeInterval connectionTimeout;

- (instancetype)init;
- (instancetype)initWithLabel:(NSString *)label;
- (dispatch_queue_t)queue;

- (BOOL)openConnectionToHost:(NSString *)host port:(uint16_t)port processor:(id<WSConnectionProcessor>)processor;
- (void)closeConnectionForProcessor:(id<WSConnectionProcessor>)processor;
- (void)closeConnectionForProcessor:(id<WSConnectionProcessor>)processor error:(NSError *)error;
- (void)closeConnections:(NSUInteger)connections;
- (void)closeConnections:(NSUInteger)connections error:(NSError *)error;
- (void)closeAllConnections;

- (NSUInteger)numberOfConnections;

// execute in pool thread
- (void)runBlock:(void (^)())block;

@end
