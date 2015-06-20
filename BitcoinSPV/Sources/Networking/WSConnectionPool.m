//
//  WSConnectionPool.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 07/07/14.
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

#import <arpa/inet.h>

#import "WSConnectionPool.h"
#import "WSConnection.h"
#import "WSBuffer.h"
#import "WSMessage.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "NSData+Binary.h"

@interface WSBasicConnection : NSObject <WSConnection>

@property (nonatomic, readonly, weak) WSConnectionHandler *handler;

- (instancetype)initWithHandler:(WSConnectionHandler *)handler;

@end

#pragma mark -

@interface WSConnectionPool ()

@property (nonatomic, strong) id<WSParameters> parameters;
@property (nonatomic, strong) NSMutableArray *handlers;                     // WSConnectionHandler
@property (nonatomic, strong) NSMutableDictionary *handlersByIdentifier;    // NSString -> WSConnectionHandler

- (WSConnectionHandler *)handlerForProcessor:(id<WSConnectionProcessor>)processor;
- (void)tryDisconnectHandler:(WSConnectionHandler *)handler error:(NSError *)error;
- (void)removeHandler:(WSConnectionHandler *)handler;

@end

@implementation WSConnectionPool

- (instancetype)init
{
    WSExceptionRaiseUnsupported(@"Use initWithParameters:");
    return nil;
}

- (instancetype)initWithParameters:(id<WSParameters>)parameters
{
    WSExceptionCheckIllegal(parameters);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        self.handlers = [[NSMutableArray alloc] init];
        self.handlersByIdentifier = [[NSMutableDictionary alloc] init];
        self.connectionTimeout = 5.0;
    }
    return self;
}

- (BOOL)openConnectionToHost:(NSString *)host port:(uint16_t)port processor:(id<WSConnectionProcessor>)processor
{
    WSExceptionCheckIllegal(host);
//    WSExceptionCheckIllegal(processor);

    WSConnectionHandler *handler;

    @synchronized (self.handlers) {
        for (handler in self.handlers) {
            if ([handler.host isEqualToString:host] && (handler.port == port)) {
                return NO;
            }
        }
        
        handler = [[WSConnectionHandler alloc] initWithParameters:self.parameters host:host port:port processor:processor];
        handler.delegate = self;
        [self.handlers addObject:handler];
        self.handlersByIdentifier[handler.identifier] = handler;

        DDLogDebug(@"Added %@ to pool (current: %u)", handler, self.handlers.count);
    }

    [handler connectWithTimeout:self.connectionTimeout error:NULL];

    return YES;
}

- (void)closeConnectionForProcessor:(id<WSConnectionProcessor>)processor
{
    [self closeConnectionForProcessor:processor error:nil];
}

- (void)closeConnectionForProcessor:(id<WSConnectionProcessor>)processor error:(NSError *)error
{
    WSExceptionCheckIllegal(processor);
    
    @synchronized (self.handlers) {
        WSConnectionHandler *handler = [self handlerForProcessor:processor];
        if (handler) {
            [self tryDisconnectHandler:handler error:error];
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
            [self tryDisconnectHandler:handler error:error];
            ++i;
        }
    }
}

- (void)closeAllConnections
{
    @synchronized (self.handlers) {
        for (WSConnectionHandler *handler in [self.handlers copy]) {
            [self tryDisconnectHandler:handler error:nil];
        }
    }
}

- (NSUInteger)numberOfConnections
{
    @synchronized (self.handlers) {
        return self.handlers.count;
    }
}

#pragma mark WSConnectionHandlerDelegate (handler queue)

- (void)connectionHandlerDidConnect:(WSConnectionHandler *)connectionHandler
{
    [connectionHandler.processor setConnection:[[WSBasicConnection alloc] initWithHandler:connectionHandler]];
}

- (void)connectionHandler:(WSConnectionHandler *)connectionHandler didDisconnectWithError:(NSError *)error
{
    @synchronized (self.handlers) {
        [self removeHandler:connectionHandler];
    }
}

#pragma mark Helpers

- (WSConnectionHandler *)handlerForProcessor:(id<WSConnectionProcessor>)processor
{
    NSParameterAssert(processor);

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
- (void)tryDisconnectHandler:(WSConnectionHandler *)handler error:(NSError *)error
{
    NSParameterAssert(handler);

    if ([handler isConnected]) {
        [handler disconnectWithError:error];
    }
    else {
        [self removeHandler:handler];
    }
}

// unsafe
- (void)removeHandler:(WSConnectionHandler *)handler
{
    NSParameterAssert(handler);
    
    if (!self.handlersByIdentifier[handler.identifier]) {
        DDLogVerbose(@"Removing nonexistent handler (%@)", handler);
        return;
    }
    [self.handlersByIdentifier removeObjectForKey:handler.identifier];
    [self.handlers removeObject:handler];

    DDLogDebug(@"Removed %@ from pool (current: %u)", handler, self.handlers.count);
}

@end

#pragma mark -

@implementation WSBasicConnection

- (instancetype)initWithHandler:(WSConnectionHandler *)handler
{
    NSParameterAssert(handler);
    
    if ((self = [super init])) {
        _handler = handler;
    }
    return self;
}

#pragma mark WSConnectionWriter

- (void)submitBlock:(void (^)())block
{
    [self.handler runBlock:block];
}

- (void)writeMessage:(id<WSMessage>)message
{
//    @synchronized (self) {
//        if (_peerStatus == WSPeerStatusDisconnected) {
//            DDLogWarn(@"%@ Not connected", self);
//            return;
//        }
//    }
    
    NSUInteger headerLength;
    WSBuffer *buffer = [message toNetworkBufferWithHeaderLength:&headerLength];
    if (buffer.length > WSMessageMaxLength) {
        DDLogError(@"%@ Error sending '%@', message is too long (%u > %u)", self.handler, message.messageType, buffer.length, WSMessageMaxLength);
        return;
    }
    
    DDLogVerbose(@"%@ Sending %@ (%u+%u bytes)", self.handler, message, headerLength, buffer.length - headerLength);
    DDLogVerbose(@"%@ Sending data: %@", self.handler, [buffer.data hexString]);
    
    [self.handler unsafeEnqueueData:buffer.data];
    [self.handler unsafeFlush];
}

- (void)disconnectWithError:(NSError *)error
{
    [self.handler disconnectWithError:error];
}

@end
