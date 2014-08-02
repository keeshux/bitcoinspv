//
//  WSConnectionPool.m
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

#import <arpa/inet.h>
#import "DDLog.h"

#import "WSConnectionPool.h"
#import "WSConfig.h"
#import "WSErrors.h"

//
// NOTE: GCDAsyncSocket is thread-safe.
//

@class WSConnectionHandler;

@interface WSConnectionHandler : NSObject

@property (nonatomic, readonly, strong) dispatch_queue_t queue;
@property (nonatomic, readonly, strong) GCDAsyncSocket *socket;
@property (nonatomic, readonly, strong) NSString *host;
@property (nonatomic, readonly, assign) uint16_t port;
@property (nonatomic, readonly, weak) id<WSConnectionProcessor> processor;
@property (atomic, strong) NSError *error;

- (instancetype)initWithPool:(WSConnectionPool *)pool host:(NSString *)host port:(uint16_t)port processor:(id<WSConnectionProcessor>)processor;
- (NSString *)identifier;
- (BOOL)connectWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;

@end

@interface WSSocketConnectionWriter : NSObject <WSConnectionWriter>

@property (nonatomic, readonly, strong) GCDAsyncSocket *socket;

- (instancetype)initWithSocket:(GCDAsyncSocket *)socket;

@end

@interface GCDAsyncSocket (Handler)

- (WSConnectionHandler *)handler;
- (void)setHandler:(WSConnectionHandler *)handler;
- (NSString *)identifier;

@end

#pragma mark -

@interface WSConnectionPool ()

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableArray *handlers;                     // WSConnectionHandler
@property (nonatomic, strong) NSMutableDictionary *handlersByIdentifier;    // NSString -> WSConnectionHandler

- (WSConnectionHandler *)handlerForProcessor:(id<WSConnectionProcessor>)processor;
- (void)delayRemoveHandler:(WSConnectionHandler *)handler;
- (void)removeHandler:(WSConnectionHandler *)handler;

@end

@implementation WSConnectionPool

- (instancetype)init
{
    return [self initWithLabel:nil];
}

- (instancetype)initWithLabel:(NSString *)label
{
    if ((self = [super init])) {
        if (!label) {
            label = [[self class] description];
        }
        self.queue = dispatch_queue_create(label.UTF8String, NULL);
        self.handlers = [[NSMutableArray alloc] init];
        self.handlersByIdentifier = [[NSMutableDictionary alloc] init];
        self.connectionTimeout = 5.0;
    }
    return self;
}

- (BOOL)openConnectionToHost:(NSString *)host port:(uint16_t)port processor:(id<WSConnectionProcessor>)processor
{
    WSExceptionCheckIllegal(host != nil, @"Nil host");
//    WSExceptionCheckIllegal(processor != nil, @"Nil processor");

    @synchronized (self.handlers) {
        for (WSConnectionHandler *handler in self.handlers) {
            if ([handler.host isEqualToString:host] && (handler.port == port)) {
                return NO;
            }
        }
        
        WSConnectionHandler *handler = [[WSConnectionHandler alloc] initWithPool:self host:host port:port processor:processor];
        if (![handler connectWithTimeout:self.connectionTimeout error:NULL]) {
            return NO;
        }
        [self.handlers addObject:handler];
        self.handlersByIdentifier[handler.identifier] = handler;
        DDLogDebug(@"Added %@ to pool (current: %u)", handler, self.handlers.count);
        return YES;
    }
}

- (void)closeConnectionForProcessor:(id<WSConnectionProcessor>)processor
{
    [self closeConnectionForProcessor:processor error:nil];
}

- (void)closeConnectionForProcessor:(id<WSConnectionProcessor>)processor error:(NSError *)error
{
    WSExceptionCheckIllegal(processor != nil, @"Nil processor");
    
    @synchronized (self.handlers) {
        WSConnectionHandler *handler = [self handlerForProcessor:processor];
        if (handler) {
            handler.error = error;
            [self delayRemoveHandler:handler];
        }
    }
}

- (void)closeConnections:(NSUInteger)connections
{
    [self closeConnections:connections error:nil];
}

- (void)closeConnections:(NSUInteger)connections error:(NSError *)error
{
    @synchronized (self.handlers) {
        const NSUInteger finalConnections = self.handlers.count - connections;
        
        NSUInteger i = 0;
        while ((self.handlers.count >= finalConnections) && (i < connections)) {
            WSConnectionHandler *handler = self.handlers[i];
            handler.error = error;
            [handler.socket disconnect];
            ++i;
        }
    }
}

- (void)closeAllConnections
{
    @synchronized (self.handlers) {
        for (WSConnectionHandler *handler in [self.handlers copy]) {
            [self delayRemoveHandler:handler];
        }
    }
}

- (NSUInteger)numberOfConnections
{
    @synchronized (self.handlers) {
        return self.handlers.count;
    }
}

- (void)runBlock:(void (^)())block
{
    dispatch_async(self.queue, block);
}

#pragma mark Private

- (WSConnectionHandler *)handlerForProcessor:(id<WSConnectionProcessor>)processor
{
    NSAssert(processor, @"Nil processor");

    @synchronized (self.handlers) {
        for (WSConnectionHandler *handler in self.handlers) {
            if (handler.processor == processor) {
                return handler;
            }
        }
    }
    return nil;
}

// unsafe
- (void)delayRemoveHandler:(WSConnectionHandler *)handler
{
    NSAssert(handler, @"Nil handler");

    if ([handler.socket isConnected]) {
        [handler.socket disconnect];
    }
    else {
        [self removeHandler:handler];
    }
}

// unsafe
- (void)removeHandler:(WSConnectionHandler *)handler
{
    NSAssert(handler, @"Nil handler");
    
    if (![self.handlersByIdentifier objectForKey:handler.identifier]) {
        DDLogVerbose(@"Removing nonexistent handler (%@)", handler);
        return;
    }
    [self.handlersByIdentifier removeObjectForKey:handler.identifier];
    [self.handlers removeObject:handler];

    DDLogDebug(@"Removed %@ from pool (current: %u)", handler, self.handlers.count);
}

#pragma mark GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    DDLogDebug(@"Connected to %@", sock);

    WSConnectionHandler *handler = sock.handler;
    [handler.processor openedConnectionToHost:host port:port queue:self.queue];
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
//    DDLogDebug(@"Data sent to %@", sock);
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
//    DDLogDebug(@"Partial data sent to %@ (%u bytes)", sock, partialLength);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
//    DDLogDebug(@"Data received from %@ (%u bytes)", sock, data.length);

    WSConnectionHandler *handler = sock.handler;
    [handler.processor processData:data];
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    DDLogDebug(@"Disconnected from %@", sock);

    WSConnectionHandler *handler = sock.handler;
    @synchronized (self.handlers) {
        [self removeHandler:handler];
    }

    if (handler.error) {
        [handler.processor closedConnectionWithError:handler.error];
        handler.error = nil;
    }
    else {
        [handler.processor closedConnectionWithError:err];
    }
}

@end

#pragma mark -

@implementation WSConnectionHandler

- (instancetype)initWithPool:(WSConnectionPool *)pool host:(NSString *)host port:(uint16_t)port processor:(id<WSConnectionProcessor>)processor
{
    if ((self = [super init])) {
        _host = host;
        _port = port;
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:pool delegateQueue:pool.queue];
        [_socket setHandler:self];
        _processor = processor;
        [_processor setWriter:[[WSSocketConnectionWriter alloc] initWithSocket:_socket]];
    }
    return self;
}

- (NSString *)identifier
{
    return [NSString stringWithFormat:@"%@:%u", _host, _port];
}

- (BOOL)connectWithTimeout:(NSTimeInterval)timeout error:(NSError *__autoreleasing *)error
{
    if ([_socket isConnected]) {
        return YES;
    }
    return [_socket connectToHost:_host onPort:_port withTimeout:timeout error:error];
}

- (NSString *)description
{
    return self.identifier;
}

@end

@implementation WSSocketConnectionWriter

- (instancetype)initWithSocket:(GCDAsyncSocket *)socket
{
    if ((self = [super init])) {
        _socket = socket;
    }
    return self;
}

#pragma mark WSConnectionWriter

- (void)writeData:(NSData *)data timeout:(NSTimeInterval)timeout
{
    [_socket writeData:data withTimeout:timeout tag:0];
}

- (void)disconnectWithError:(NSError *)error
{
    _socket.handler.error = error;
    [_socket disconnect];
}

@end

@implementation GCDAsyncSocket (Handler)

- (WSConnectionHandler *)handler
{
    WSConnectionHandler *handler = [self userData];
    NSAssert(handler, @"No handler attached to socket");
    return handler;
}

- (void)setHandler:(WSConnectionHandler *)handler
{
    [self setUserData:handler];
}

- (NSString *)identifier
{
    WSConnectionHandler *handler = [self userData];
    return handler.identifier;
}

- (NSString *)description
{
    return self.identifier;
}

@end
