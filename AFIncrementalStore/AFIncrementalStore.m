// AFIncrementalStore.m
//
// Copyright (c) 2012 Mattt Thompson (http://mattt.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFIncrementalStore.h"
#import "AFHTTPClient.h"
#import <objc/runtime.h>

NSString * const AFIncrementalStoreUnimplementedMethodException = @"com.alamofire.incremental-store.exceptions.unimplemented-method";

NSString * const AFIncrementalStoreContextWillFetchRemoteValues = @"AFIncrementalStoreContextWillFetchRemoteValues";
NSString * const AFIncrementalStoreContextWillSaveRemoteValues = @"AFIncrementalStoreContextWillSaveRemoteValues";
NSString * const AFIncrementalStoreContextDidFetchRemoteValues = @"AFIncrementalStoreContextDidFetchRemoteValues";
NSString * const AFIncrementalStoreContextDidSaveRemoteValues = @"AFIncrementalStoreContextDidSaveRemoteValues";
NSString * const AFIncrementalStoreRequestOperationKey = @"AFIncrementalStoreRequestOperation";
NSString * const AFIncrementalStorePersistentStoreRequestKey = @"AFIncrementalStorePersistentStoreRequest";
NSString * const AFIncrementalStoreFetchedObjectsKey = @"AFIncrementalStoreFetchedObjectsKey";

static char kAFResourceIdentifierObjectKey;

static NSString * const kAFIncrementalStoreResourceIdentifierAttributeName = @"__af_resourceIdentifier";
static NSString * const kAFIncrementalStoreLastModifiedAttributeName = @"__af_lastModified";

static NSString * const kAFReferenceObjectPrefix = @"__af_";

inline NSString * AFReferenceObjectFromResourceIdentifier(NSString *resourceIdentifier) {
    if (!resourceIdentifier) {
        return nil;
    }
    
    return [kAFReferenceObjectPrefix stringByAppendingString:resourceIdentifier];    
}

inline NSString * AFResourceIdentifierFromReferenceObject(id referenceObject) {
    if (!referenceObject) {
        return nil;
    }
    
    NSString *string = [referenceObject description];
    return [string hasPrefix:kAFReferenceObjectPrefix] ? [string substringFromIndex:[kAFReferenceObjectPrefix length]] : string;
}

@interface NSManagedObject (_AFIncrementalStore)
@property (readwrite, nonatomic, copy, setter = af_setResourceIdentifier:) NSString *af_resourceIdentifier;
@end

@implementation NSManagedObject (_AFIncrementalStore)
@dynamic af_resourceIdentifier;

- (NSString *)af_resourceIdentifier {
    NSString *identifier = (NSString *)objc_getAssociatedObject(self, &kAFResourceIdentifierObjectKey);
    
    if (!identifier) {
        if ([self.objectID.persistentStore isKindOfClass:[AFIncrementalStore class]]) {
            id referenceObject = [(AFIncrementalStore *)self.objectID.persistentStore referenceObjectForObjectID:self.objectID];
            if ([referenceObject isKindOfClass:[NSString class]]) {
                return AFResourceIdentifierFromReferenceObject(referenceObject);
            }
        }
    }
    
    return identifier;
}

- (void)af_setResourceIdentifier:(NSString *)resourceIdentifier {
    objc_setAssociatedObject(self, &kAFResourceIdentifierObjectKey, resourceIdentifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

#pragma mark -

@implementation AFIncrementalStore {
@private
    NSCache *_backingObjectIDByObjectID;
    NSMutableDictionary *_registeredObjectIDsByEntityNameAndNestedResourceIdentifier;
    NSPersistentStoreCoordinator *_backingPersistentStoreCoordinator;
    NSManagedObjectContext *_backingManagedObjectContext;
}
@synthesize HTTPClient = _HTTPClient;
@synthesize backingPersistentStoreCoordinator = _backingPersistentStoreCoordinator;

+ (NSString *)type {
    @throw([NSException exceptionWithName:AFIncrementalStoreUnimplementedMethodException reason:NSLocalizedString(@"Unimplemented method: +type. Must be overridden in a subclass", nil) userInfo:nil]);
}

+ (NSManagedObjectModel *)model {
    @throw([NSException exceptionWithName:AFIncrementalStoreUnimplementedMethodException reason:NSLocalizedString(@"Unimplemented method: +model. Must be overridden in a subclass", nil) userInfo:nil]);
}

#pragma mark -

- (void)notifyManagedObjectContext:(NSManagedObjectContext *)context
             aboutRequestOperation:(AFHTTPRequestOperation *)operation
                   forFetchRequest:(NSFetchRequest *)fetchRequest
                    fetchedObjects:(NSArray *)fetchedObjects
{
    NSString *notificationName = [operation isFinished] ? AFIncrementalStoreContextDidFetchRemoteValues : AFIncrementalStoreContextWillFetchRemoteValues;
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:operation forKey:AFIncrementalStoreRequestOperationKey];
    [userInfo setObject:fetchRequest forKey:AFIncrementalStorePersistentStoreRequestKey];
    if ([operation isFinished] && fetchedObjects) {
        [userInfo setObject:fetchedObjects forKey:AFIncrementalStoreFetchedObjectsKey];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:context userInfo:userInfo];
    });
}

- (void)notifyManagedObjectContext:(NSManagedObjectContext *)context
            aboutRequestOperations:(NSArray *)operations
             forSaveChangesRequest:(NSSaveChangesRequest *)saveChangesRequest
{
    NSString *notificationName = [[operations lastObject] isFinished] ? AFIncrementalStoreContextDidSaveRemoteValues : AFIncrementalStoreContextWillSaveRemoteValues;
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:operations forKey:AFIncrementalStoreRequestOperationKey];
    [userInfo setObject:saveChangesRequest forKey:AFIncrementalStorePersistentStoreRequestKey];

    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:context userInfo:userInfo];
}

#pragma mark -

- (NSManagedObjectContext *)backingManagedObjectContext {
    if (!_backingManagedObjectContext) {
        _backingManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _backingManagedObjectContext.persistentStoreCoordinator = _backingPersistentStoreCoordinator;
        _backingManagedObjectContext.retainsRegisteredObjects = YES;
    }
    
    return _backingManagedObjectContext;
}

- (NSManagedObjectID *)objectIDForEntity:(NSEntityDescription *)entity
                  withResourceIdentifier:(NSString *)resourceIdentifier {
    if (!resourceIdentifier) {
        return nil;
    }
    
    NSManagedObjectID *objectID = nil;
    NSMutableDictionary *objectIDsByResourceIdentifier = [_registeredObjectIDsByEntityNameAndNestedResourceIdentifier objectForKey:objectID.entity.name];
    if (objectIDsByResourceIdentifier) {
        objectID = [objectIDsByResourceIdentifier objectForKey:resourceIdentifier];
    }
        
    if (objectID == nil) {
        objectID = [self newObjectIDForEntity:entity referenceObject:AFReferenceObjectFromResourceIdentifier(resourceIdentifier)];
    }
    
    NSParameterAssert([objectID.entity.name isEqualToString:entity.name]);
    
    return objectID;
}

- (NSManagedObjectID *)objectIDForBackingObjectForEntity:(NSEntityDescription *)entity
                                  withResourceIdentifier:(NSString *)resourceIdentifier
{
    if (!resourceIdentifier) {
        return nil;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[entity name]];
    fetchRequest.resultType = NSManagedObjectIDResultType;
    fetchRequest.fetchLimit = 1;
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K = %@", kAFIncrementalStoreResourceIdentifierAttributeName, resourceIdentifier];
    
    __block NSArray *results = nil;
    __block NSError *error = nil;
    
    [self.backingPersistentStoreCoordinator lock];
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    [backingContext performBlockAndWait:^{
        results = [backingContext executeFetchRequest:fetchRequest error:&error];
    }];
    [self.backingPersistentStoreCoordinator unlock];
    
    if (error) {
        NSLog(@"Error: %@", error);
        return nil;
    }
    
    return [results lastObject];
}

#pragma mark -

- (void)insertOrUpdateObjectsFromRepresentations:(id)representationOrArrayOfRepresentations
                                        ofEntity:(NSEntityDescription *)entity
                                    fromResponse:(NSHTTPURLResponse *)response
                                     withContext:(NSManagedObjectContext *)context
                                           error:(NSError *__autoreleasing *)error
                                 completionBlock:(void (^)(NSArray *managedObjects, NSArray *backingObjects))completionBlock
{
    NSParameterAssert([representationOrArrayOfRepresentations isKindOfClass:[NSArray class]] || [representationOrArrayOfRepresentations isKindOfClass:[NSDictionary class]]);
    
    if ([representationOrArrayOfRepresentations count] == 0) {
        if (completionBlock) {
            completionBlock([NSArray array], [NSArray array]);
        }
        
        return;
    }
    
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    NSString *lastModified = [[response allHeaderFields] valueForKey:@"Last-Modified"];

    NSArray *representations = nil;
    if ([representationOrArrayOfRepresentations isKindOfClass:[NSArray class]]) {
        representations = representationOrArrayOfRepresentations;
    } else if ([representationOrArrayOfRepresentations isKindOfClass:[NSDictionary class]]) {
        representations = [NSArray arrayWithObject:representationOrArrayOfRepresentations];
    }

    NSUInteger numberOfRepresentations = [representations count];
    NSMutableArray *mutableManagedObjects = [NSMutableArray arrayWithCapacity:numberOfRepresentations];
    NSMutableArray *mutableBackingObjects = [NSMutableArray arrayWithCapacity:numberOfRepresentations];
    
    for (NSDictionary *representation in representations) {
        NSString *resourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:representation ofEntity:entity fromResponse:response];
        NSDictionary *attributes = [self.HTTPClient attributesForRepresentation:representation ofEntity:entity fromResponse:response];
        
        __block NSManagedObject *managedObject = nil;
        [context performBlockAndWait:^{
            managedObject = [context existingObjectWithID:[self objectIDForEntity:entity withResourceIdentifier:resourceIdentifier] error:nil];
        }];
        
        [managedObject setValuesForKeysWithDictionary:attributes];
        
        NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:entity withResourceIdentifier:resourceIdentifier];
        __block NSManagedObject *backingObject = nil;
        [backingContext performBlockAndWait:^{
            if (backingObjectID) {
                backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
            } else {
                backingObject = [NSEntityDescription insertNewObjectForEntityForName:entity.name inManagedObjectContext:backingContext];
                [backingObject.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:backingObject] error:nil];
            }
        }];
        [backingObject setValue:resourceIdentifier forKey:kAFIncrementalStoreResourceIdentifierAttributeName];
        [backingObject setValue:lastModified forKey:kAFIncrementalStoreLastModifiedAttributeName];
        [backingObject setValuesForKeysWithDictionary:attributes];
        
        if (!backingObjectID) {
            [context insertObject:managedObject];
        }
        
        NSDictionary *relationshipRepresentations = [self.HTTPClient representationsForRelationshipsFromRepresentation:representation ofEntity:entity fromResponse:response];
        for (NSString *relationshipName in relationshipRepresentations) {
            NSRelationshipDescription *relationship = [[entity relationshipsByName] valueForKey:relationshipName];
            id relationshipRepresentation = [relationshipRepresentations objectForKey:relationshipName];
            if (!relationship || (relationship.isOptional && (!relationshipRepresentation || [relationshipRepresentation isEqual:[NSNull null]]))) {
                continue;
            }
                        
            if (!relationshipRepresentation || [relationshipRepresentation isEqual:[NSNull null]] || [relationshipRepresentation count] == 0) {
                [managedObject setValue:nil forKey:relationshipName];
                [backingObject setValue:nil forKey:relationshipName];
                continue;
            }
            
            [self insertOrUpdateObjectsFromRepresentations:relationshipRepresentation ofEntity:relationship.destinationEntity fromResponse:response withContext:context error:error completionBlock:^(NSArray *managedObjects, NSArray *backingObjects) {
                if ([relationship isToMany]) {
                    if ([relationship isOrdered]) {
                        [managedObject setValue:[NSOrderedSet orderedSetWithArray:managedObjects] forKey:relationship.name];
                        [backingObject setValue:[NSOrderedSet orderedSetWithArray:backingObjects] forKey:relationship.name];
                    } else {
                        [managedObject setValue:[NSSet setWithArray:managedObjects] forKey:relationship.name];
                        [backingObject setValue:[NSSet setWithArray:backingObjects] forKey:relationship.name];
                    }
                } else {
                    [managedObject setValue:[managedObjects lastObject] forKey:relationship.name];
                    [backingObject setValue:[backingObjects lastObject] forKey:relationship.name];
                }
            }];
        }
        
        [mutableManagedObjects addObject:managedObject];
        [mutableBackingObjects addObject:backingObject];
    }
    
    if (completionBlock) {
        completionBlock(mutableManagedObjects, mutableBackingObjects);
    }
}

- (id)executeFetchRequest:(NSFetchRequest *)fetchRequest
              withContext:(NSManagedObjectContext *)context
                    error:(NSError *__autoreleasing *)error
{
    NSURLRequest *request = [self.HTTPClient requestForFetchRequest:fetchRequest withContext:context];
    if ([request URL]) {
        AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
            id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsFromResponseObject:responseObject];
    
            NSManagedObjectContext *childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            childContext.parentContext = context;
            childContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
                        
            [childContext performBlockAndWait:^{
                [self insertOrUpdateObjectsFromRepresentations:representationOrArrayOfRepresentations ofEntity:fetchRequest.entity fromResponse:operation.response withContext:childContext error:error completionBlock:^(NSArray *managedObjects, NSArray *backingObjects) {
                
                    NSSet *childObjects = [childContext registeredObjects];
                    
                    if (![[self backingManagedObjectContext] save:error] || ![childContext save:error]) {
                        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[*error localizedFailureReason] userInfo:[NSDictionary dictionaryWithObject:*error forKey:NSUnderlyingErrorKey]];
                    }
                    
                    for (NSManagedObject *childObject in childObjects) {
                        NSManagedObject *parentObject = [context objectWithID:childObject.objectID];
                        [parentObject.managedObjectContext refreshObject:parentObject mergeChanges:NO];
                    }

                    [context performBlockAndWait:^{
                        for (NSManagedObject *childObject in childObjects) {
                            NSManagedObject *parentObject = [context objectWithID:childObject.objectID];
                            [parentObject willChangeValueForKey:@"self"];
                            [context refreshObject:parentObject mergeChanges:NO];
                            [parentObject didChangeValueForKey:@"self"];
                        }
                    }];

                    NSMutableArray *fetchedObjects = [[NSMutableArray alloc] initWithCapacity:[managedObjects count]];
                    for (NSManagedObject *managedObject in managedObjects) {
                        NSManagedObject *fetchedObject = [context existingObjectWithID:managedObject.objectID error:NULL];
                        if (fetchedObject) {
                            [fetchedObjects addObject:fetchedObject];
                        }
                    }
                    [fetchedObjects sortUsingDescriptors:fetchRequest.sortDescriptors];
                    
                    [self notifyManagedObjectContext:context aboutRequestOperation:operation forFetchRequest:fetchRequest fetchedObjects:fetchedObjects];
                }];
            }];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Error: %@", error);
            [self notifyManagedObjectContext:context aboutRequestOperation:operation forFetchRequest:fetchRequest fetchedObjects:nil];
        }];

        [self notifyManagedObjectContext:context aboutRequestOperation:operation forFetchRequest:fetchRequest fetchedObjects:nil];
        [self.HTTPClient enqueueHTTPRequestOperation:operation];
    }
    
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    NSArray *results = nil;
    
    NSFetchRequestResultType resultType = fetchRequest.resultType;
    switch (resultType) {
        case NSManagedObjectResultType: {
            fetchRequest = [fetchRequest copy];
            fetchRequest.entity = [NSEntityDescription entityForName:fetchRequest.entityName inManagedObjectContext:backingContext];
            fetchRequest.resultType = NSDictionaryResultType;
            fetchRequest.propertiesToFetch = [NSArray arrayWithObject:kAFIncrementalStoreResourceIdentifierAttributeName];
            results = [backingContext executeFetchRequest:fetchRequest error:error];
            NSMutableArray *mutableObjects = [NSMutableArray arrayWithCapacity:[results count]];
            for (NSString *resourceIdentifier in [results valueForKeyPath:kAFIncrementalStoreResourceIdentifierAttributeName]) {
                NSManagedObjectID *objectID = [self objectIDForEntity:fetchRequest.entity withResourceIdentifier:resourceIdentifier];
                NSManagedObject *object = [context objectWithID:objectID];
                object.af_resourceIdentifier = resourceIdentifier;
                [mutableObjects addObject:object];
            }
            
            return mutableObjects;
        }
        case NSManagedObjectIDResultType: {
            NSArray *backingObjectIDs = [backingContext executeFetchRequest:fetchRequest error:error];
            NSMutableArray *managedObjectIDs = [NSMutableArray arrayWithCapacity:[backingObjectIDs count]];
            
            for (NSManagedObjectID *backingObjectID in backingObjectIDs) {
                NSManagedObject *backingObject = [backingContext objectWithID:backingObjectID];
                NSString *resourceID = [backingObject valueForKey:kAFIncrementalStoreResourceIdentifierAttributeName];
                [managedObjectIDs addObject:[self objectIDForEntity:fetchRequest.entity withResourceIdentifier:resourceID]];
            }
            
            return managedObjectIDs;
        }
        case NSDictionaryResultType:
        case NSCountResultType:
            return [backingContext executeFetchRequest:fetchRequest error:error];
        default:
            return nil;
    }
}

- (id)executeSaveChangesRequest:(NSSaveChangesRequest *)saveChangesRequest
                    withContext:(NSManagedObjectContext *)context
                          error:(NSError *__autoreleasing *)error
{
    NSMutableArray *mutableOperations = [NSMutableArray array];
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];

    if ([self.HTTPClient respondsToSelector:@selector(requestForInsertedObject:)]) {
        for (NSManagedObject *insertedObject in [saveChangesRequest insertedObjects]) {
            NSURLRequest *request = [self.HTTPClient requestForInsertedObject:insertedObject];
            if (!request) {
                [backingContext performBlockAndWait:^{
                    CFUUIDRef UUID = CFUUIDCreate(NULL);
                    NSString *resourceIdentifier = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, UUID);
                    CFRelease(UUID);
                    
                    NSManagedObject *backingObject = [NSEntityDescription insertNewObjectForEntityForName:insertedObject.entity.name inManagedObjectContext:backingContext];
                    [backingObject.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:backingObject] error:nil];
                    [backingObject setValue:resourceIdentifier forKey:kAFIncrementalStoreResourceIdentifierAttributeName];
                    [backingObject setValuesForKeysWithDictionary:[insertedObject dictionaryWithValuesForKeys:nil]];
                    [backingContext save:nil];
                }];
                
                [insertedObject willChangeValueForKey:@"objectID"];
                [context obtainPermanentIDsForObjects:[NSArray arrayWithObject:insertedObject] error:nil];
                [insertedObject didChangeValueForKey:@"objectID"];
                continue;
            }
            
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                
                NSMutableArray *managedObjectsWithNewObjectsIds = [NSMutableArray array];
                
                NSString *resourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:responseObject ofEntity:[insertedObject entity] fromResponse:operation.response];
                NSManagedObjectID *objectID = [self objectIDForEntity:[insertedObject entity] withResourceIdentifier:resourceIdentifier];
                insertedObject.af_resourceIdentifier = resourceIdentifier;
                [insertedObject setValuesForKeysWithDictionary:[self.HTTPClient attributesForRepresentation:responseObject ofEntity:insertedObject.entity fromResponse:operation.response]];
                
                __block NSManagedObject *backingObject = nil;
                [backingContext performBlockAndWait:^{
                    
                    if (objectID) {
                        [backingContext performBlockAndWait:^{
                            backingObject = [backingContext existingObjectWithID:objectID error:nil];
                        }];
                    }
                    
                    if (!backingObject) {
                        backingObject = [NSEntityDescription insertNewObjectForEntityForName:insertedObject.entity.name inManagedObjectContext:backingContext];
                        [backingObject.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:backingObject] error:nil];
                    }
                    
                    [backingObject setValue:resourceIdentifier forKey:kAFIncrementalStoreResourceIdentifierAttributeName];
                    [backingObject setValuesForKeysWithDictionary:[insertedObject dictionaryWithValuesForKeys:insertedObject.entity.attributesByName.allKeys]];
                }];
                
                NSDictionary *relationshipRepresentations = [self.HTTPClient representationsForRelationshipsFromRepresentation:responseObject ofEntity:insertedObject.entity fromResponse:operation.response];
                
                for (NSString *relationshipName in relationshipRepresentations) {
                    NSRelationshipDescription *relationship = [[insertedObject.entity relationshipsByName] valueForKey:relationshipName];
                    id relationshipRepresentation = [relationshipRepresentations objectForKey:relationshipName];
                    if (!relationship || (relationship.isOptional && (!relationshipRepresentation || [relationshipRepresentation isEqual:[NSNull null]]))) {
                        continue;
                    }
                    
                    if (!relationshipRepresentation || [relationshipRepresentation isEqual:[NSNull null]] || [relationshipRepresentation count] == 0) {
                        [insertedObject setValue:nil forKey:relationshipName];
                        continue;
                    }
                    
                    NSManagedObject *relatedObject = [insertedObject valueForKey:relationshipName];
                    
                    NSString *resourceIdentifierForRelatedObject = [self.HTTPClient resourceIdentifierForRepresentation:relationshipRepresentation ofEntity:[relatedObject entity] fromResponse:operation.response];
                    NSManagedObjectID *objectIDOfRelatedObject = [self objectIDForEntity:[relatedObject entity] withResourceIdentifier:resourceIdentifierForRelatedObject];
                    relatedObject.af_resourceIdentifier = resourceIdentifierForRelatedObject;
                    [relatedObject setValuesForKeysWithDictionary:[self.HTTPClient attributesForRepresentation:relationshipRepresentation ofEntity:relatedObject.entity fromResponse:operation.response]];
                    
                    [managedObjectsWithNewObjectsIds addObject:relatedObject];
                    
                    [backingContext performBlockAndWait:^{
                        __block NSManagedObject *backingObjectOfRelatedObject = nil;
                        if (objectIDOfRelatedObject) {
                            [backingContext performBlockAndWait:^{
                                backingObjectOfRelatedObject = [backingContext existingObjectWithID:objectIDOfRelatedObject error:nil];
                            }];
                        }
                        
                        if (!backingObjectOfRelatedObject) {
                            backingObjectOfRelatedObject = [NSEntityDescription insertNewObjectForEntityForName:relatedObject.entity.name inManagedObjectContext:backingContext];
                            [backingObjectOfRelatedObject.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:backingObjectOfRelatedObject] error:nil];
                        }
                        
                        [backingObjectOfRelatedObject setValue:resourceIdentifierForRelatedObject forKey:kAFIncrementalStoreResourceIdentifierAttributeName];
                        [backingObjectOfRelatedObject setValuesForKeysWithDictionary:[relatedObject dictionaryWithValuesForKeys:relatedObject.entity.attributesByName.allKeys]];
                        [backingObject setValuesForKeysWithDictionary:@{ relationshipName : backingObjectOfRelatedObject }];
                    }];
                }
                
                [backingContext performBlockAndWait:^{
                    [backingContext save:nil];
                }];
                
                [managedObjectsWithNewObjectsIds addObject:insertedObject];
                
                for (NSManagedObject *managedObject in managedObjectsWithNewObjectsIds) {
                    [managedObject willChangeValueForKey:@"objectID"];
                }
                
                [context obtainPermanentIDsForObjects:managedObjectsWithNewObjectsIds error:nil];
                
                for (NSManagedObject *managedObject in managedObjectsWithNewObjectsIds) {
                    [managedObject didChangeValueForKey:@"objectID"];
                }

                
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Insert Error: %@", error);
            }];
            
            [mutableOperations addObject:operation];
        }
    }
    
    if ([self.HTTPClient respondsToSelector:@selector(requestForUpdatedObject:)]) {
        for (NSManagedObject *updatedObject in [saveChangesRequest updatedObjects]) {
            NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[updatedObject entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:updatedObject.objectID])];

            NSURLRequest *request = [self.HTTPClient requestForUpdatedObject:updatedObject];
            if (!request) {
                [backingContext performBlockAndWait:^{
                    NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                    [backingObject setValuesForKeysWithDictionary:[updatedObject dictionaryWithValuesForKeys:nil]];
                    [backingContext save:nil];
                }];
                continue;
            }
            
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                [updatedObject setValuesForKeysWithDictionary:[self.HTTPClient attributesForRepresentation:responseObject ofEntity:updatedObject.entity fromResponse:operation.response]];
                
                [backingContext performBlockAndWait:^{
                    NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                    [backingObject setValuesForKeysWithDictionary:[updatedObject dictionaryWithValuesForKeys:nil]];
                    [backingContext save:nil];
                }];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Update Error: %@", error);
            }];
            
            [mutableOperations addObject:operation];
        }
    }
    
    if ([self.HTTPClient respondsToSelector:@selector(requestForDeletedObject:)]) {
        for (NSManagedObject *deletedObject in [saveChangesRequest deletedObjects]) {
            NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[deletedObject entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:deletedObject.objectID])];

            NSURLRequest *request = [self.HTTPClient requestForDeletedObject:deletedObject];
            if (!request) {
                [backingContext performBlockAndWait:^{
                    NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                    [backingContext deleteObject:backingObject];
                    [backingContext save:nil];
                }];
                continue;
            }
            
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                [backingContext performBlockAndWait:^{
                    NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                    [backingContext deleteObject:backingObject];
                    [backingContext save:nil];
                }];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Delete Error: %@", error);
            }];
            
            [mutableOperations addObject:operation];
        }
    }
    
    [self notifyManagedObjectContext:context aboutRequestOperations:mutableOperations forSaveChangesRequest:saveChangesRequest];

    [self.HTTPClient enqueueBatchOfHTTPRequestOperations:mutableOperations progressBlock:nil completionBlock:^(NSArray *operations) {
        [self notifyManagedObjectContext:context aboutRequestOperations:operations forSaveChangesRequest:saveChangesRequest];
    }];
    
    return [NSArray array];
}

#pragma mark - NSIncrementalStore

- (BOOL)loadMetadata:(NSError *__autoreleasing *)error {
    if (!_backingObjectIDByObjectID) {
        NSMutableDictionary *mutableMetadata = [NSMutableDictionary dictionary];
        [mutableMetadata setValue:[[NSProcessInfo processInfo] globallyUniqueString] forKey:NSStoreUUIDKey];
        [mutableMetadata setValue:NSStringFromClass([self class]) forKey:NSStoreTypeKey];
        [self setMetadata:mutableMetadata];
        
        _backingObjectIDByObjectID = [[NSCache alloc] init];
        _registeredObjectIDsByEntityNameAndNestedResourceIdentifier = [[NSMutableDictionary alloc] init];
        
        NSManagedObjectModel *model = [self.persistentStoreCoordinator.managedObjectModel copy];
        for (NSEntityDescription *entity in model.entities) {
            // Don't add properties for sub-entities, as they already exist in the super-entity
            if ([entity superentity]) {
                continue;
            }
            
            NSAttributeDescription *resourceIdentifierProperty = [[NSAttributeDescription alloc] init];
            [resourceIdentifierProperty setName:kAFIncrementalStoreResourceIdentifierAttributeName];
            [resourceIdentifierProperty setAttributeType:NSStringAttributeType];
            [resourceIdentifierProperty setIndexed:YES];
            
            NSAttributeDescription *lastModifiedProperty = [[NSAttributeDescription alloc] init];
            [lastModifiedProperty setName:kAFIncrementalStoreLastModifiedAttributeName];
            [lastModifiedProperty setAttributeType:NSStringAttributeType];
            [lastModifiedProperty setIndexed:NO];
            
            [entity setProperties:[entity.properties arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:resourceIdentifierProperty, lastModifiedProperty, nil]]];
        }
        
        _backingPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        
        return YES;
    } else {
        return NO;
    }
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError **)error {
    NSMutableArray *mutablePermanentIDs = [NSMutableArray arrayWithCapacity:[array count]];
    for (NSManagedObject *managedObject in array) {
        NSManagedObjectID *managedObjectID = managedObject.objectID;
        if ([managedObjectID isTemporaryID] && managedObject.af_resourceIdentifier) {
            NSManagedObjectID *objectID = [self objectIDForEntity:managedObject.entity withResourceIdentifier:managedObject.af_resourceIdentifier];
            [mutablePermanentIDs addObject:objectID];
        } else {
            [mutablePermanentIDs addObject:managedObjectID];
        }
    }
    
    return mutablePermanentIDs;
}

- (id)executeRequest:(NSPersistentStoreRequest *)persistentStoreRequest
         withContext:(NSManagedObjectContext *)context
               error:(NSError *__autoreleasing *)error
{
    if (persistentStoreRequest.requestType == NSFetchRequestType) {
        return [self executeFetchRequest:(NSFetchRequest *)persistentStoreRequest withContext:context error:error];
    } else if (persistentStoreRequest.requestType == NSSaveRequestType) {
        return [self executeSaveChangesRequest:(NSSaveChangesRequest *)persistentStoreRequest withContext:context error:error];
    } else {
        NSMutableDictionary *mutableUserInfo = [NSMutableDictionary dictionary];
        [mutableUserInfo setValue:[NSString stringWithFormat:NSLocalizedString(@"Unsupported NSFetchRequestResultType, %d", nil), persistentStoreRequest.requestType] forKey:NSLocalizedDescriptionKey];
        if (error) {
            *error = [[NSError alloc] initWithDomain:AFNetworkingErrorDomain code:0 userInfo:mutableUserInfo];
        }
        
        return nil;
    }
}

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID
                                         withContext:(NSManagedObjectContext *)context
                                               error:(NSError *__autoreleasing *)error
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[[objectID entity] name]];
    fetchRequest.resultType = NSDictionaryResultType;
    fetchRequest.fetchLimit = 1;
    fetchRequest.includesSubentities = NO;
    fetchRequest.propertiesToFetch = [[[[NSEntityDescription entityForName:fetchRequest.entityName inManagedObjectContext:context] attributesByName] allKeys] arrayByAddingObject:kAFIncrementalStoreLastModifiedAttributeName];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K = %@", kAFIncrementalStoreResourceIdentifierAttributeName, AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:objectID])];
    
    __block NSArray *results;
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    [backingContext performBlockAndWait:^{
        results = [backingContext executeFetchRequest:fetchRequest error:error];
    }];
    
    NSDictionary *attributeValues = [results lastObject] ?: [NSDictionary dictionary];
    NSIncrementalStoreNode *node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:attributeValues version:1];
    
    if ([self.HTTPClient respondsToSelector:@selector(shouldFetchRemoteAttributeValuesForObjectWithID:inManagedObjectContext:)] && [self.HTTPClient shouldFetchRemoteAttributeValuesForObjectWithID:objectID inManagedObjectContext:context]) {
        if (attributeValues) {
            NSManagedObjectContext *childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            childContext.parentContext = context;
            childContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
            
            NSMutableURLRequest *request = [self.HTTPClient requestWithMethod:@"GET" pathForObjectWithID:objectID withContext:context];
            NSString *lastModified = [attributeValues objectForKey:kAFIncrementalStoreLastModifiedAttributeName];
            if (lastModified) {
                [request setValue:lastModified forHTTPHeaderField:@"Last-Modified"];
            }
            
            if ([request URL]) {
                if ([attributeValues valueForKey:kAFIncrementalStoreLastModifiedAttributeName]) {
                    [request setValue:[[attributeValues valueForKey:kAFIncrementalStoreLastModifiedAttributeName] description] forHTTPHeaderField:@"If-Modified-Since"];
                }
                
                AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, NSDictionary *representation) {
                    NSManagedObject *managedObject = [childContext existingObjectWithID:objectID error:error];
                    
                    NSMutableDictionary *mutableAttributeValues = [attributeValues mutableCopy];
                    [mutableAttributeValues addEntriesFromDictionary:[self.HTTPClient attributesForRepresentation:representation ofEntity:managedObject.entity fromResponse:operation.response]];
                    [mutableAttributeValues removeObjectForKey:kAFIncrementalStoreLastModifiedAttributeName];
                    [managedObject setValuesForKeysWithDictionary:mutableAttributeValues];
                    
                    NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[objectID entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:objectID])];
                    NSManagedObject *backingObject = [[self backingManagedObjectContext] existingObjectWithID:backingObjectID error:nil];
                    [backingObject setValuesForKeysWithDictionary:mutableAttributeValues];
                    
                    NSString *lastModified = [[operation.response allHeaderFields] valueForKey:@"Last-Modified"];
                    if (lastModified) {
                        [backingObject setValue:lastModified forKey:kAFIncrementalStoreLastModifiedAttributeName];
                    }

                    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:childContext queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                        [context mergeChangesFromContextDidSaveNotification:note];
                    }];
                    
                    [childContext performBlockAndWait:^{
                        if (![[self backingManagedObjectContext] save:error] || ![childContext save:error]) {
                            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[*error localizedFailureReason] userInfo:[NSDictionary dictionaryWithObject:*error forKey:NSUnderlyingErrorKey]];
                        }
                    }];
                    
                    [[NSNotificationCenter defaultCenter] removeObserver:observer];
                } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    NSLog(@"Error: %@, %@", operation, error);
                }];
                
                [self.HTTPClient enqueueHTTPRequestOperation:operation];
            }
        }
    }
    
    return node;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship
              forObjectWithID:(NSManagedObjectID *)objectID
                  withContext:(NSManagedObjectContext *)context
                        error:(NSError *__autoreleasing *)error
{
    if ([self.HTTPClient respondsToSelector:@selector(shouldFetchRemoteValuesForRelationship:forObjectWithID:inManagedObjectContext:)] && [self.HTTPClient shouldFetchRemoteValuesForRelationship:relationship forObjectWithID:objectID inManagedObjectContext:context]) {
        NSURLRequest *request = [self.HTTPClient requestWithMethod:@"GET" pathForRelationship:relationship forObjectWithID:objectID withContext:context];
        
        if ([request URL] && ![[context existingObjectWithID:objectID error:nil] hasChanges]) {
            NSManagedObjectContext *childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            childContext.parentContext = context;
            childContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
                        
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsFromResponseObject:responseObject];
                
                [childContext performBlockAndWait:^{
                    [self insertOrUpdateObjectsFromRepresentations:representationOrArrayOfRepresentations ofEntity:relationship.destinationEntity fromResponse:operation.response withContext:childContext error:error completionBlock:^(NSArray *managedObjects, NSArray *backingObjects) {
                        NSManagedObject *managedObject = [childContext objectWithID:objectID];
                        NSManagedObject *backingObject = [[self backingManagedObjectContext] existingObjectWithID:objectID error:nil];
                        
                        if ([relationship isToMany]) {
                            if ([relationship isOrdered]) {
                                [managedObject setValue:[NSOrderedSet orderedSetWithArray:managedObjects] forKey:relationship.name];
                                [backingObject setValue:[NSOrderedSet orderedSetWithArray:backingObjects] forKey:relationship.name];
                            } else {
                                [managedObject setValue:[NSSet setWithArray:managedObjects] forKey:relationship.name];
                                [backingObject setValue:[NSSet setWithArray:backingObjects] forKey:relationship.name];
                            }
                        } else {
                            [managedObject setValue:[managedObjects lastObject] forKey:relationship.name];
                            [backingObject setValue:[backingObjects lastObject] forKey:relationship.name];
                        }
                        
                        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:childContext queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                            [context mergeChangesFromContextDidSaveNotification:note];
                        }];
                        
                        if (![[self backingManagedObjectContext] save:error] || ![childContext save:error]) {
                            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[*error localizedFailureReason] userInfo:[NSDictionary dictionaryWithObject:*error forKey:NSUnderlyingErrorKey]];
                        }
                        
                        [[NSNotificationCenter defaultCenter] removeObserver:observer];
                    }];
                }];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Error: %@, %@", operation, error);
            }];

            [self.HTTPClient enqueueHTTPRequestOperation:operation];
        }
    }
    
    NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[objectID entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:objectID])];
    NSManagedObject *backingObject = (backingObjectID == nil) ? nil : [[self backingManagedObjectContext] existingObjectWithID:backingObjectID error:nil];
    
    if (backingObject && ![backingObject hasChanges]) {
        id backingRelationshipObject = [backingObject valueForKeyPath:relationship.name];
        if ([relationship isToMany]) {
            NSMutableArray *mutableObjects = [NSMutableArray arrayWithCapacity:[backingRelationshipObject count]];
            for (NSString *resourceIdentifier in [backingRelationshipObject valueForKeyPath:kAFIncrementalStoreResourceIdentifierAttributeName]) {
                NSManagedObjectID *objectID = [self objectIDForEntity:relationship.destinationEntity withResourceIdentifier:resourceIdentifier];
                [mutableObjects addObject:objectID];
            }
                        
            return mutableObjects;            
        } else {
            NSString *resourceIdentifier = [backingRelationshipObject valueForKeyPath:kAFIncrementalStoreResourceIdentifierAttributeName];
            NSManagedObjectID *objectID = [self objectIDForEntity:relationship.destinationEntity withResourceIdentifier:resourceIdentifier];
            
            return objectID ?: [NSNull null];
        }
    } else {
        if ([relationship isToMany]) {
            return [NSArray array];
        } else {
            return [NSNull null];
        }
    }
}

- (void)managedObjectContextDidRegisterObjectsWithIDs:(NSArray *)objectIDs {
    [super managedObjectContextDidRegisterObjectsWithIDs:objectIDs];
    
    for (NSManagedObjectID *objectID in objectIDs) {
        id referenceObject = [self referenceObjectForObjectID:objectID];
        if (!referenceObject) {
            continue;
        }
        
        NSMutableDictionary *objectIDsByResourceIdentifier = [_registeredObjectIDsByEntityNameAndNestedResourceIdentifier objectForKey:objectID.entity.name] ?: [NSMutableDictionary dictionary];
        objectIDsByResourceIdentifier[AFResourceIdentifierFromReferenceObject(referenceObject)] = objectID;
        
        [_registeredObjectIDsByEntityNameAndNestedResourceIdentifier setObject:objectIDsByResourceIdentifier forKey:objectID.entity.name];
    }
}

- (void)managedObjectContextDidUnregisterObjectsWithIDs:(NSArray *)objectIDs {
    [super managedObjectContextDidUnregisterObjectsWithIDs:objectIDs];
    
    for (NSManagedObjectID *objectID in objectIDs) {
        [[_registeredObjectIDsByEntityNameAndNestedResourceIdentifier objectForKey:objectID.entity.name] removeObjectForKey:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:objectID])];
    }
}

@end
