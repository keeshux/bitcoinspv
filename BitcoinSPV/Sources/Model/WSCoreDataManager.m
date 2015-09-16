//
//  WSCoreDataManager.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 12/07/14.
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

#import "WSCoreDataManager.h"
#import "WSConfig.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSCoreDataManager ()

@property (nonatomic, strong) NSManagedObjectModel *model;
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSPersistentStore *store;
@property (nonatomic, strong) NSManagedObjectContext *context;

+ (NSPersistentStore *)createPersistentStoreWithURL:(NSURL *)url forCoordinator:(NSPersistentStoreCoordinator *)coordinator error:(NSError *__autoreleasing *)error;

@end

@implementation WSCoreDataManager

- (instancetype)initWithPath:(NSString *)path error:(NSError *__autoreleasing *)error
{
    WSExceptionCheckIllegal(path);
    
    NSBundle *bundle = WSClientBundle([self class]);
    NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:@[bundle]];
    if (!model) {
        return nil;
    }
    
    NSArray *entities = [model entities];
    DDLogDebug(@"Loaded %lu entities from merged Core Data model", (unsigned long)entities.count);
    for (NSEntityDescription *entity in entities) {
        DDLogDebug(@"\t%@", entity.name);
    }
    
    NSURL *storeURL = [[NSURL fileURLWithPath:path] absoluteURL];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSPersistentStore *store = [[self class] createPersistentStoreWithURL:storeURL forCoordinator:coordinator error:error];
    if (!store) {
        return nil;
    }
                  
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    context.persistentStoreCoordinator = coordinator;
    context.undoManager = nil;

    if ((self = [super init])) {
        self.model = model;
        self.coordinator = coordinator;
        self.store = store;
        self.context = context;
    }
    return self;
}

- (NSURL *)storeURL
{
    return self.store.URL;
}

+ (NSPersistentStore *)createPersistentStoreWithURL:(NSURL *)url forCoordinator:(NSPersistentStoreCoordinator *)coordinator error:(NSError *__autoreleasing *)error
{
    NSError *localError;
    NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                         configuration:nil
                                                                   URL:url
                                                               options:@{NSMigratePersistentStoresAutomaticallyOption: @(YES),
                                                                         NSInferMappingModelAutomaticallyOption: @(YES)}
                                                                 error:&localError];

    if (!store) {
        DDLogError(@"Core Data error initializing persistent coordinator (%@)", localError);
        if (error) {
            *error = localError;
        }
    }
    return store;
}

- (void)truncate
{
    [self truncateWithError:NULL];
}

- (BOOL)truncateWithError:(NSError *__autoreleasing *)error
{
    NSError *localError;
    if (![self.coordinator removePersistentStore:self.store error:&localError] ||
        ![[NSFileManager defaultManager] removeItemAtURL:self.store.URL error:&localError]) {
    
        DDLogError(@"Core Data error while truncating store (%@)", localError);
        if (error) {
            *error = localError;
        }
        return NO;
    }

    self.store = [[self class] createPersistentStoreWithURL:self.store.URL forCoordinator:self.coordinator error:&localError];
    if (!self.store) {
        return NO;
    }

    self.context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.context.persistentStoreCoordinator = self.coordinator;
    self.context.undoManager = nil;

    return YES;
}

- (BOOL)saveWithError:(NSError *__autoreleasing *)error
{
    return [self.context save:error];
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
