//
//  WSJSONClient.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 07/12/14.
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

#import "WSJSONClient.h"
#import "WSConfig.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"

@implementation WSJSONClient

+ (instancetype)sharedInstance
{
    static WSJSONClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)asynchronousRequestWithBaseURL:(NSURL *)baseURL path:(NSString *)path success:(void (^)(NSInteger, id))success failure:(void (^)(NSInteger, NSError *))failure
{
    [self asynchronousRequestWithBaseURL:baseURL path:path timeout:WSJSONClientDefaultTimeout success:success failure:failure];
}

- (void)asynchronousRequestWithBaseURL:(NSURL *)baseURL path:(NSString *)path timeout:(NSTimeInterval)timeout success:(void (^)(NSInteger, id))success failure:(void (^)(NSInteger, NSError *))failure
{
    NSParameterAssert(baseURL);
    NSParameterAssert(path);
    NSParameterAssert(success);
    NSParameterAssert(failure);
    
    NSURL *url = [NSURL URLWithString:path relativeToURL:baseURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:timeout];

    DDLogVerbose(@"%@ -> Sending request", request.URL);

    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            DDLogVerbose(@"%@ -> Connection error: %@", request.URL, connectionError);
            failure(0, connectionError);
            return;
        }
        
        NSInteger statusCode = 0;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            statusCode = httpResponse.statusCode;
            DDLogVerbose(@"%@ -> Status %ld", request.URL, (long)statusCode);
        }
        if (ddLogLevel == LOG_LEVEL_VERBOSE) {
            DDLogVerbose(@"%@ -> Response string: %@", request.URL, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        }
        if (statusCode >= 400) {
            failure(statusCode, nil);
            return;
        }

        NSError *error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!json) {
            DDLogVerbose(@"%@ -> Malformed JSON: %@", request.URL, error);
            failure(statusCode, error);
        }

        DDLogVerbose(@"%@ -> JSON (%lu bytes)", request.URL, (unsigned long)data.length);
        DDLogVerbose(@"%@", json);
        success(statusCode, json);
    }];
}

@end
