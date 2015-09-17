//
//  WSMessageVersion.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 26/06/14.
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

#import "WSMessageVersion.h"
#import "WSNetworkAddress.h"
#import "WSConfig.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSMessageVersion ()

@property (nonatomic, assign) uint32_t version;
@property (nonatomic, assign) uint64_t services;
@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, strong) WSNetworkAddress *remoteNetworkAddress;
@property (nonatomic, strong) WSNetworkAddress *localNetworkAddress;
@property (nonatomic, assign) uint64_t nonce;
@property (nonatomic, copy) NSString *userAgent;
@property (nonatomic, assign) uint32_t lastBlockHeight;
@property (nonatomic, assign) uint8_t relayTransactions;

- (instancetype)initWithParameters:(WSParameters *)parameters
                           version:(uint32_t)version
                          services:(uint64_t)services
              remoteNetworkAddress:(WSNetworkAddress *)remoteNetworkAddress
                         localPort:(uint16_t)localPort
                 relayTransactions:(uint8_t)relayTransactions;

+ (NSString *)userAgent;

@end

@implementation WSMessageVersion

+ (instancetype)messageWithParameters:(WSParameters *)parameters
                              version:(uint32_t)version
                             services:(uint64_t)services
                 remoteNetworkAddress:(WSNetworkAddress *)remoteNetworkAddress
                            localPort:(uint16_t)localPort
                    relayTransactions:(uint8_t)relayTransactions
{
    return [[self alloc] initWithParameters:parameters version:version services:services remoteNetworkAddress:remoteNetworkAddress localPort:localPort relayTransactions:relayTransactions];
}

- (instancetype)initWithParameters:(WSParameters *)parameters
                           version:(uint32_t)version
                          services:(uint64_t)services
              remoteNetworkAddress:(WSNetworkAddress *)remoteNetworkAddress
                         localPort:(uint16_t)localPort
                 relayTransactions:(uint8_t)relayTransactions
{
    WSExceptionCheckIllegal(remoteNetworkAddress);

    if ((self = [super initWithParameters:parameters])) {
        self.version = version;
        self.services = services;
        self.timestamp = WSCurrentTimestamp();
        self.remoteNetworkAddress = remoteNetworkAddress;
        self.localNetworkAddress = WSNetworkAddressMake(WSMessageVersionLocalhost, localPort, self.services, 0);
        self.nonce = ((uint64_t)arc4random() << 32) | (uint32_t)arc4random(); // random nonce
        self.userAgent = [[self class] userAgent];
        self.lastBlockHeight = 0;

        //
        // BIP37: (fRelay) if false then broadcast transactions will not be
        // announced until a filter{load,add,clear} command is received
        //
        // https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki
        //
        self.relayTransactions = relayTransactions;
    }
    return self;
}

+ (NSString *)userAgent
{
    return [NSString stringWithFormat:@"/%@:%@/", WSClientName, WSClientVersion];
}

#pragma mark WSMessage

- (NSString *)messageType
{
    return WSMessageType_VERSION;
}

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];
    [tokens addObject:[NSString stringWithFormat:@"version = %u", self.version]];
    [tokens addObject:[NSString stringWithFormat:@"timestamp = %llu", self.timestamp]];
    [tokens addObject:[NSString stringWithFormat:@"endpoint = %@", self.localNetworkAddress]];
    [tokens addObject:[NSString stringWithFormat:@"userAgent = '%@'", self.userAgent]];
    [tokens addObject:[NSString stringWithFormat:@"lastBlockHeight = %u", self.lastBlockHeight]];
    return [NSString stringWithFormat:@"{%@}", WSStringDescriptionFromTokens(tokens, indent)];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendUint32:self.version];
    [buffer appendUint64:self.services];
    [buffer appendUint64:self.timestamp];
    [buffer appendNetworkAddress:self.remoteNetworkAddress];
    [buffer appendNetworkAddress:self.localNetworkAddress];
    [buffer appendUint64:self.nonce];
    [buffer appendString:self.userAgent];
    [buffer appendUint32:self.lastBlockHeight];
    [buffer appendUint8:self.relayTransactions];
}

- (WSBuffer *)toBuffer
{
    // approximate
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:100];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if (available < 85) {
        WSErrorSetNotEnoughMessageBytes(error, self.messageType, available, 85);
        return nil;
    }
    
    NSUInteger offset = from;
    if ((self = [super initWithParameters:parameters originalLength:buffer.length])) {
        self.version = [buffer uint32AtOffset:offset];
        offset += sizeof(uint32_t);

        self.services = [buffer uint64AtOffset:offset];
        offset += sizeof(uint64_t);

        self.timestamp = [buffer uint64AtOffset:offset];
        offset += sizeof(uint64_t);
        
        // https://en.bitcoin.it/wiki/Protocol_documentation#Network_address
        //
        // the Time (version >= 31402). Not present in version message.
        //
        // will have to parse manually

        self.remoteNetworkAddress = [buffer legacyNetworkAddressAtOffset:offset];
        offset += WSNetworkAddressLegacyLength;

        self.localNetworkAddress = [buffer legacyNetworkAddressAtOffset:offset];
        offset += WSNetworkAddressLegacyLength;

        self.nonce = [buffer uint64AtOffset:offset];
        offset += sizeof(uint64_t);
        
        NSUInteger userAgentLength;
        self.userAgent = [buffer stringAtOffset:offset length:&userAgentLength];
        offset += userAgentLength;
        
        const NSUInteger expectedLength = offset + sizeof(uint32_t);
        if (available < expectedLength) {
            WSErrorSetNotEnoughMessageBytes(error, self.messageType, available, expectedLength);
            return nil;
        }
        
        self.lastBlockHeight = [buffer uint32AtOffset:offset];
        offset += sizeof(self.lastBlockHeight);

        if (offset < available) {
           self.relayTransactions = [buffer uint8AtOffset:offset];
        }
    }
    return self;
}

@end
