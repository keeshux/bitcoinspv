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

#import "WSConnectionPool.h"
#import "WSProtocolDeserializer.h"
#import "WSBuffer.h"
#import "WSMessage.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "NSData+Binary.h"

@interface WSStreamConnectionHandler : NSObject <WSConnectionHandler, NSStreamDelegate>

@property (nonatomic, weak) id<WSConnectionHandlerDelegate> delegate;

- (instancetype)initWithParameters:(WSParameters *)parameters host:(NSString *)host port:(uint16_t)port processor:(id<WSConnectionProcessor>)processor;
- (void)connectWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;

@end

#pragma mark -

@interface WSConnectionPool ()

@property (nonatomic, strong) WSParameters *parameters;
@property (nonatomic, strong) NSMutableDictionary *handlers;    // NSString -> WSConnectionHandler

- (id<WSConnectionHandler>)unsafeHandlerForProcessor:(id<WSConnectionProcessor>)processor;
- (void)unsafeTryDisconnectHandler:(id<WSConnectionHandler>)handler error:(NSError *)error;
- (void)unsafeRemoveHandler:(id<WSConnectionHandler>)handler;

@end

@implementation WSConnectionPool

- (instancetype)init
{
    WSExceptionRaiseUnsupported(@"Use initWithParameters:");
    return nil;
}

- (instancetype)initWithParameters:(WSParameters *)parameters
{
    WSExceptionCheckIllegal(parameters);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        self.handlers = [[NSMutableDictionary alloc] init];
        self.connectionTimeout = 5.0;
    }
    return self;
}

- (BOOL)openConnectionToHost:(NSString *)host port:(uint16_t)port processor:(id<WSConnectionProcessor>)processor
{
    WSExceptionCheckIllegal(host);

    WSStreamConnectionHandler *handler;

    @synchronized (self.handlers) {
        for (handler in [self.handlers allValues]) {
            if ([handler.host isEqualToString:host] && (handler.port == port)) {
                return NO;
            }
        }
        
        handler = [[WSStreamConnectionHandler alloc] initWithParameters:self.parameters host:host port:port processor:processor];
        handler.delegate = self;
        self.handlers[handler.identifier] = handler;

        DDLogDebug(@"%@ Added to pool (current: %lu)", handler, (unsigned long)self.handlers.count);

        [handler connectWithTimeout:self.connectionTimeout error:NULL];
    }

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
        id<WSConnectionHandler> handler = [self unsafeHandlerForProcessor:processor];
        if (handler) {
            [self unsafeTryDisconnectHandler:handler error:error];
        }
    }
}

- (void)closeAllConnections
{
    @synchronized (self.handlers) {
        for (id<WSConnectionHandler> handler in [self.handlers allValues]) {
            [self unsafeTryDisconnectHandler:handler error:nil];
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

- (void)connectionHandlerDidConnect:(id<WSConnectionHandler>)connectionHandler
{
    DDLogDebug(@"%@ Handler connected", connectionHandler);
}

- (void)connectionHandler:(id<WSConnectionHandler>)connectionHandler didDisconnectWithError:(NSError *)error
{
    DDLogDebug(@"%@ Handler disconnected%@", connectionHandler, WSStringOptional(error, @" (%@)"));

    @synchronized (self.handlers) {
        [self unsafeRemoveHandler:connectionHandler];
    }
}

#pragma mark Helpers (unsafe)

- (id<WSConnectionHandler>)unsafeHandlerForProcessor:(id<WSConnectionProcessor>)processor
{
    NSParameterAssert(processor);

    for (id<WSConnectionHandler> handler in [self.handlers allValues]) {
        if (handler.processor == processor) {
            return handler;
        }
    }
    return nil;
}

- (void)unsafeTryDisconnectHandler:(id<WSConnectionHandler>)handler error:(NSError *)error
{
    NSParameterAssert(handler);

    if ([handler isConnected]) {
        [handler disconnectWithError:error];
    }
    else {
        [self unsafeRemoveHandler:handler];
    }
}

- (void)unsafeRemoveHandler:(id<WSConnectionHandler>)handler
{
    NSParameterAssert(handler);
    
    if (!self.handlers[handler.identifier]) {
        DDLogDebug(@"%@ Removing nonexistent handler", handler);
        return;
    }
    [self.handlers removeObjectForKey:handler.identifier];

    DDLogDebug(@"%@ Removed from pool (current: %lu)", handler, (unsigned long)self.handlers.count);
}

@end

#pragma mark -

@interface WSStreamConnectionHandler ()

@property (nonatomic, strong) WSParameters *parameters;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, weak) id<WSConnectionProcessor> processor;

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSRunLoop *runLoop;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) WSProtocolDeserializer *inputDeserializer;
@property (nonatomic, strong) NSMutableData *outputBuffer;

- (void)unsafeEnqueueData:(NSData *)data;
- (void)unsafeFlush;

@end

@implementation WSStreamConnectionHandler

- (instancetype)initWithParameters:(WSParameters *)parameters host:(NSString *)host port:(uint16_t)port processor:(id<WSConnectionProcessor>)processor
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(host);
    WSExceptionCheckIllegal(port > 0);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        self.host = host;
        self.port = port;
        self.identifier = [NSString stringWithFormat:@"(%@:%u)", self.host, self.port];
        self.processor = processor;
    }
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)connectWithTimeout:(NSTimeInterval)timeout error:(NSError *__autoreleasing *)error
{
    if (self.queue) {
        return;
    }
    
//    NSString *label = [NSString stringWithFormat:@"%@-%@", [self class], self.identifier];
    NSString *label = [NSString stringWithFormat:@"%@", self.identifier];
    
    self.queue = dispatch_queue_create(label.UTF8String, NULL);
    self.inputDeserializer = [[WSProtocolDeserializer alloc] initWithParameters:self.parameters host:self.host port:self.port];
    self.outputBuffer = [[NSMutableData alloc] initWithCapacity:10240];
    
    dispatch_async(self.queue, ^{
        self.runLoop = [NSRunLoop currentRunLoop];
        
        NSInputStream *inputStream;
        NSOutputStream *outputStream;
        [NSStream getStreamsToHostWithName:self.host port:self.port inputStream:&inputStream outputStream:&outputStream];
        
        self.inputStream = inputStream;
        self.outputStream = outputStream;
        self.inputStream.delegate = self;
        self.outputStream.delegate = self;
        
        [self.inputStream scheduleInRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
        [self.outputStream scheduleInRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
        
        [self performSelector:@selector(disconnectWithError:) withObject:WSErrorMake(WSErrorCodeConnectionTimeout, @"Connection timed out") afterDelay:timeout];
        
        [self.inputStream open];
        [self.outputStream open];
        
        [self.runLoop run];
    });
}

- (NSString *)description
{
    return self.identifier;
}

#pragma mark WSConnectionHandler (any queue)

- (BOOL)isConnected
{
    return (self.queue != NULL);
}

- (void)submitBlock:(void (^)())block
{
    WSExceptionCheckIllegal(block);
    
    CFRunLoopPerformBlock([self.runLoop getCFRunLoop], kCFRunLoopCommonModes, ^{
        block();
        
        CFRunLoopStop([self.runLoop getCFRunLoop]);
    });
    CFRunLoopWakeUp([self.runLoop getCFRunLoop]);
}

// unsafe
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
        DDLogError(@"%@ Error sending '%@', message is too long (%lu > %lu)", self, message.messageType,
                   (unsigned long)buffer.length, (unsigned long)WSMessageMaxLength);
        return;
    }
    
    DDLogVerbose(@"%@ Sending %@ (%lu+%lu bytes)", self, message,
                 (unsigned long)headerLength, (unsigned long)(buffer.length - headerLength));

    DDLogVerbose(@"%@ Sending data: %@", self, [buffer.data hexString]);
    
    [self unsafeEnqueueData:buffer.data];
    [self unsafeFlush];
}

- (void)disconnectWithError:(NSError *)error
{
    [self submitBlock:^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        
        [self.inputStream close];
        [self.outputStream close];
        [self.inputStream removeFromRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
        [self.outputStream removeFromRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
        
        [self.delegate connectionHandler:self didDisconnectWithError:error];
        [self.processor closedConnectionWithError:error];
        self.queue = NULL;
    }];
}

#pragma mark NSStreamDelegate (handler queue)

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
//            DDLogDebug(@"%@ Connected", self);
            
            if (aStream == self.outputStream) {
                [NSObject cancelPreviousPerformRequestsWithTarget:self];
                
                [self.delegate connectionHandlerDidConnect:self];
                [self.processor openedConnectionToHost:self.host port:self.port handler:self];
                [self unsafeFlush];
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable: {
            if (aStream != self.outputStream) {
                return;
            }
            [self unsafeFlush];
            break;
        }
        case NSStreamEventHasBytesAvailable: {
            if (aStream != self.inputStream) {
                return;
            }
            while ([self.inputStream hasBytesAvailable]) {
                NSError *error;
                id<WSMessage> message = [self.inputDeserializer parseMessageFromStream:self.inputStream error:&error];
                if (message) {
                    [self.processor processMessage:message];
                }
                else {
                    if (error) {
                        DDLogError(@"%@ Error deserializing message: %@", self, error);
                        if (error.code == WSErrorCodeMalformed) {
                            [self disconnectWithError:error];
                        }
                        return;
                    }
                }
            }
            break;
        }
        case NSStreamEventErrorOccurred: {
            [self disconnectWithError:aStream.streamError];
            break;
        }
        case NSStreamEventEndEncountered: {
            [self disconnectWithError:nil];
            break;
        }
        default: {
            DDLogError(@"%@ Unknown network stream eventCode %lu", self, (unsigned long)eventCode);
            break;
        }
    }
}

#pragma mark Helpers (unsafe)

- (void)unsafeEnqueueData:(NSData *)data
{
    NSParameterAssert(data);
    
    [self.outputBuffer appendData:data];
}

- (void)unsafeFlush
{
    while ((self.outputBuffer.length > 0) && [self.outputStream hasSpaceAvailable]) {
        const NSInteger written = [self.outputStream write:self.outputBuffer.bytes maxLength:self.outputBuffer.length];
        if (written > 0) {
            [self.outputBuffer replaceBytesInRange:NSMakeRange(0, written) withBytes:NULL length:0];
        }
    }
}

@end
