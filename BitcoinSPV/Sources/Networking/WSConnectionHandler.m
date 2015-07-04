//
//  WSConnectionHandler.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 26/03/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
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

#import "WSConnectionHandler.h"
#import "WSConnection.h"
#import "WSProtocolDeserializer.h"
#import "WSLogging.h"
#import "WSErrors.h"
#import "WSMacrosCore.h"

@interface WSConnectionHandler ()

@property (nonatomic, strong) id<WSParameters> parameters;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, weak) id<WSConnectionProcessor> processor;
@property (nonatomic, strong) NSString *identifier;

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSRunLoop *runLoop;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) WSProtocolDeserializer *inputDeserializer;
@property (nonatomic, strong) NSMutableData *outputBuffer;

@end

@implementation WSConnectionHandler

- (instancetype)initWithParameters:(id<WSParameters>)parameters host:(NSString *)host port:(uint16_t)port processor:(id<WSConnectionProcessor>)processor
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(host);
    WSExceptionCheckIllegal(port > 0);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        self.host = host;
        self.port = port;
        self.processor = processor;
        self.identifier = [NSString stringWithFormat:@"%@:%u", self.host, self.port];
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
    
    NSString *label = [NSString stringWithFormat:@"%@-%@", [self class], self.identifier];
    
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

- (BOOL)isConnected
{
    return (self.queue != NULL);
}

- (void)disconnectWithError:(NSError *)error
{
    [self runBlock:^{
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

- (void)runBlock:(void (^)())block
{
    NSParameterAssert(block);
    
    CFRunLoopPerformBlock([self.runLoop getCFRunLoop], kCFRunLoopCommonModes, ^{
        block();
        
        CFRunLoopStop([self.runLoop getCFRunLoop]);
    });
    CFRunLoopWakeUp([self.runLoop getCFRunLoop]);
}

- (NSString *)description
{
    return self.identifier;
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

#pragma mark NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
//            DDLogDebug(@"Connected to %@", self);
            
            if (aStream == self.outputStream) {
                [NSObject cancelPreviousPerformRequestsWithTarget:self];

                [self.delegate connectionHandlerDidConnect:self];
                [self.processor openedConnectionToHost:self.host port:self.port queue:self.queue];
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
            DDLogError(@"Unknown network stream eventCode %u from %@", (int)eventCode, self);
            break;
        }
    }
}

@end
