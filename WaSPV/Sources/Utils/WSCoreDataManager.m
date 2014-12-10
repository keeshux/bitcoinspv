//
//  WSCoreDataManager.m
//  WaSPV
//
//  Created by Davide De Rosa on 12/07/14.
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

#import "DDLog.h"

#import "WSCoreDataManager.h"
#import "WSConfig.h"
#import "WSErrors.h"

@interface WSCoreDataManager ()

@property (nonatomic, strong) NSManagedObjectModel *model;
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSPersistentStore *store;
@property (nonatomic, strong) NSManagedObjectContext *context;

- (BOOL)createPersistentStoreWithURL:(NSURL *)url error:(NSError **)error;

@end

@implementation WSCoreDataManager

- (instancetype)initWithPath:(NSString *)path error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(path != nil, @"Nil path");
    
    if ((self = [super init])) {
        NSBundle *bundle = WSClientBundle([self class]);
        self.model = [NSManagedObjectModel mergedModelFromBundles:@[bundle]];
        if (!self.model) {
            return nil;
        }

        NSArray *entities = [self.model entities];
        DDLogDebug(@"Loaded %u entities from merged Core Data model", entities.count);
        for (NSEntityDescription *entity in entities) {
            DDLogDebug(@"\t%@", entity.name);
        }
        
        self.coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.model];
        if (![self createPersistentStoreWithURL:[NSURL fileURLWithPath:path] error:error]) {
            return nil;
        }
        
        self.context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        self.context.persistentStoreCoordinator = self.coordinator;
        self.context.undoManager = nil;
    }
    return self;
}

- (NSURL *)storeURL
{
    return self.store.URL;
}

- (BOOL)createPersistentStoreWithURL:(NSURL *)url error:(NSError *__autoreleasing *)error
{
    NSError *localError;
    self.store = [self.coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                configuration:nil
                                                          URL:url
                                                      options:@{NSMigratePersistentStoresAutomaticallyOption:@(YES),
                                                                NSInferMappingModelAutomaticallyOption:@(YES)}
                                                        error:&localError];

    if (!self.store) {
        DDLogError(@"Core Data error initializing persistent coordinator (%@)", localError);
        if (error) {
            *error = localError;
        }
    }
    
    return (self.store != nil);
}

- (void)truncate
{
    [self truncateWithError:NULL];
}

- (BOOL)truncateWithError:(NSError *__autoreleasing *)error
{
    NSError *localError;
    const BOOL result = ([self.coordinator removePersistentStore:self.store error:&localError] &&
                         [[NSFileManager defaultManager] removeItemAtURL:self.store.URL error:&localError] &&
                         [self createPersistentStoreWithURL:self.store.URL error:&localError]);
    
    if (!result) {
        DDLogError(@"Core Data error while truncating store (%@)", localError);
        if (error) {
            *error = localError;
        }
    }
    return result;
}

@end

#pragma mark -

@implementation NSManagedObject (CoreData)

- (instancetype)initWithContext:(NSManagedObjectContext *)context
{
    NSEntityDescription *entity = [NSEntityDescription entityForName:[[self class] entityName] inManagedObjectContext:context];
    return [self initWithEntity:entity insertIntoManagedObjectContext:context];
}

+ (NSString *)entityName
{
    return [self description];
}

@end
