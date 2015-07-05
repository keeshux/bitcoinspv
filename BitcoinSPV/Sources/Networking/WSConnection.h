//
//  WSConnection.h
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

#import <Foundation/Foundation.h>

@protocol WSMessage;
@protocol WSConnectionProcessor;

//
// thread-safety: required
//
@protocol WSConnectionHandler <NSObject>

- (NSString *)host;
- (uint16_t)port;
- (NSString *)identifier;
- (id<WSConnectionProcessor>)processor;

- (BOOL)isConnected;
- (void)submitBlock:(void (^)())block;
- (void)writeMessage:(id<WSMessage>)message; // MUST be executed from within submitBlock:
- (void)disconnectWithError:(NSError *)error;

@end

@protocol WSConnectionHandlerDelegate <NSObject>

- (void)connectionHandlerDidConnect:(id<WSConnectionHandler>)connectionHandler;
- (void)connectionHandler:(id<WSConnectionHandler>)connectionHandler didDisconnectWithError:(NSError *)error;

@end

@protocol WSConnectionProcessor <NSObject>

- (void)openedConnectionToHost:(NSString *)host port:(uint16_t)port handler:(id<WSConnectionHandler>)handler;
- (void)processMessage:(id<WSMessage>)message;
- (void)closedConnectionWithError:(NSError *)error;

@end
