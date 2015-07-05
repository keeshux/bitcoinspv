//
//  WSMessageTests.m
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

#import "XCTestCase+BitcoinSPV.h"
#import "WSNetworkAddress.h"
#import "WSProtocolDeserializer.h"

@interface WSMessageTests : XCTestCase

@end

@implementation WSMessageTests

- (void)setUp
{
    [super setUp];

    self.networkType = WSNetworkTypeTestnet3;
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//- (void)testVersion
//{
//    WSNetworkAddress *address = WSNetworkAddressMake(0x10203040, WSPeerEnabledServices);
//    WSMessageVersion *message = [WSMessageVersion messageWithVersion:WSPeerProtocol services:WSPeerEnabledServices remoteNetworkAddress:address relayTransactions:0];
//    const uint64_t timestamp = message.timestamp;
//    const uint64_t nonce = message.nonce;
//
//    NSMutableData *expData = [[@"721101000000000000000000ffffffffffffffff000000000000000000000000000000000000ffff40302010479d000000000000000000000000000000000000ffff7f000001479dffffffffffffffff0b2f57615350563a302e322f0000000000" dataFromHex] mutableCopy];
//    const NSRange timestampRange = NSMakeRange(12, 8);
//    const NSRange nonceRange = NSMakeRange(72, 8);
//    [expData replaceBytesInRange:timestampRange withBytes:&timestamp];
//    [expData replaceBytesInRange:nonceRange withBytes:&nonce];
//
//    NSString *hex = [[message toBuffer] hexString];
//    NSString *expHex = [expData hexString];
//    DDLogInfo(@"Version: %@", hex);
//    XCTAssertEqualObjects(hex, expHex);
//}

- (void)testDeserializer
{
    NSError *error;
    WSProtocolDeserializer *deserializer = [[WSProtocolDeserializer alloc] initWithParameters:self.networkParameters host:@"0.0.0.0" port:10000];
    NSArray *parts = @[[@"0b11" dataFromHex],
                       [@"090776" dataFromHex],
                       [@"657261636b000000000000" dataFromHex],
                       [@"000000005df6e0e2" dataFromHex],
                       [@"657261636b000000000000" dataFromHex],
                       [@"657261636b000000000000" dataFromHex],
                       [@"657261636b000000000000" dataFromHex],
                       [@"657261636b000000000000" dataFromHex]];

    NSMutableData *data = [[NSMutableData alloc] init];
    for (NSData *d in parts) {
        [data appendData:d];
    }

    NSInputStream *streamFull = [[NSInputStream alloc] initWithData:data];
    [streamFull open];
    
    id<WSMessage> messageFull = [deserializer parseMessageFromStream:streamFull error:&error];
    XCTAssertNotNil(messageFull);
    DDLogInfo(@"Message (full, %u bytes): %@", messageFull.length, messageFull);
    XCTAssertNil(error, @"Error: %@", error);

//    id<WSMessage> messagePartial = nil;
//    [deserializer resetBuffers];
//    while (!messagePartial) {
//        [deserializer appendData:data];
//        messagePartial = [deserializer parseMessageWithError:&error];
//        
//        if (messagePartial) {
//            DDLogInfo(@"Message (parts): %@", messagePartial);
//        }
//        XCTAssertNil(error, @"Error: %@", error);
//    }
//
//    XCTAssertEqualObjects([messageFull toBuffer], [messagePartial toBuffer]);
}

- (void)testVarInt
{
    WSBuffer *buffer = WSBufferFromHex(@"fd22040200000041886e01c7d01099b89e280c46cf134fad34d77ab55f61dd223829b600000000");
    NSUInteger varIntLength;
    const NSUInteger length = (NSUInteger)[buffer varIntAtOffset:0 length:&varIntLength];

    XCTAssertEqual(varIntLength, 3);
    XCTAssertEqual(length, 1058);
}

- (void)testNetworkAddress
{
    WSBuffer *buffer = WSBufferFromHex(@"010000000000000000000000000000000000ffffbdfbda11479d");
    NSError *error;
    WSNetworkAddress *address = [[WSNetworkAddress alloc] initWithParameters:self.networkParameters buffer:buffer from:0 available:buffer.length error:&error];
    XCTAssertNotNil(address, @"Error parsing address: %@", error);

    DDLogInfo(@"Address: %@", address);
    XCTAssertEqualObjects([address host], @"189.251.218.17");
    XCTAssertEqual([address port], 18333);
}

- (void)testEndianness
{
    for (NSUInteger i = 0; i < 50; ++i) {
        struct in_addr addr;

        const uint32_t address = (uint32_t)mrand48();
        addr.s_addr = address;
        NSString *host1 = [NSString stringWithUTF8String:inet_ntoa(addr)];
        NSString *host2 = WSNetworkHostFromIPv4(addr.s_addr);

        XCTAssertEqualObjects(host1, host2, @"Addresss -> Host");

        inet_aton(host1.UTF8String, &addr);
        const uint32_t address1 = addr.s_addr;
        const uint32_t address2 = WSNetworkIPv4FromHost(host2);

        XCTAssertEqual(address1, address2, @"Host -> Address");
    }
}

- (void)testIPv4
{
    NSString *expIPv4Host = @"189.251.218.17";
    const uint32_t expIPv4 = 0x11dafbbd;
    
    const uint32_t ipv4 = WSNetworkIPv4FromHost(expIPv4Host);
    XCTAssertEqual(ipv4, expIPv4);
    
    NSString *ipv4Host = WSNetworkHostFromIPv4(ipv4);
    XCTAssertEqualObjects(ipv4Host, expIPv4Host);
}

- (void)testIPv6
{
    NSString *expIPv6Host = @"0000:0000:0000:0000:0000:ffff:bdfb:da11";
    NSString *expIPv6Hex = @"00000000000000000000ffffbdfbda11";

    NSData *ipv6 = WSNetworkIPv6FromHost(expIPv6Host);
    XCTAssertEqualObjects([ipv6 hexString], expIPv6Hex);

    NSString *ipv6Host = WSNetworkHostFromIPv6(ipv6);
    XCTAssertEqualObjects(ipv6Host, expIPv6Host);
}

- (void)testIPv6To4
{
    NSString *ipv6Hex = @"00000000000000000000ffffbdfbda11";
    NSData *ipv6 = [ipv6Hex dataFromHex];

    const uint32_t ipv4 = WSNetworkIPv4FromIPv6(ipv6);
    NSString *ipv4Host = WSNetworkHostFromIPv4(ipv4);
    NSString *expIPv4Host = @"189.251.218.17";
    XCTAssertEqualObjects(ipv4Host, expIPv4Host);

    const uint32_t revIPv4 = WSNetworkIPv4FromHost(ipv4Host);

    NSData *revIPv6 = WSNetworkIPv6FromIPv4(revIPv4);
    NSString *revIPv6Hex = [revIPv6 hexString];
    XCTAssertEqualObjects(revIPv6Hex, ipv6Hex);
}

@end
