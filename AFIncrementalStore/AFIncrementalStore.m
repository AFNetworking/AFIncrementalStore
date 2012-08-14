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

NSString * AFIncrementalStoreUnimplementedMethodException = @"com.alamofire.incremental-store.exceptions.unimplemented-method";

@interface AFIncrementalStore ()
- (NSString *)propertyValuesCacheKeyForObjectID:(NSManagedObjectID *)objectID;
- (void)cachePropertyValues:(NSDictionary *)values forObjectID:(NSManagedObjectID *)objectID;
- (NSDictionary *)cachedPropertyValuesForObjectID:(NSManagedObjectID *)objectID;

- (NSString *)relationshipsCacheKeyForRelationship:(NSRelationshipDescription *)relationship andObjectID:(NSManagedObjectID *)objectID;
- (void)cacheObjectIDs:(NSArray *)objectIDs forRelationship:(NSRelationshipDescription *)relationship forObjectID:(NSManagedObjectID *)objectID;
- (NSArray *)objectIDSForRelationship:(NSRelationshipDescription *)relationship forObjectID:(NSManagedObjectID *)objectID;
@end

@implementation AFIncrementalStore {
@private
    NSCache *_propertyValuesCache;
    NSCache *_relationshipsCache;
}
@synthesize HTTPClient = _HTTPClient;

+ (NSString *)type {
    @throw([NSException exceptionWithName:AFIncrementalStoreUnimplementedMethodException reason:NSLocalizedString(@"Unimplemented method: +type. Must be overridden in a subclass", nil) userInfo:nil]);
}

+ (NSManagedObjectModel *)model {
    @throw([NSException exceptionWithName:AFIncrementalStoreUnimplementedMethodException reason:NSLocalizedString(@"Unimplemented method: +model. Must be overridden in a subclass", nil) userInfo:nil]);
}

- (BOOL)loadMetadata:(NSError *__autoreleasing *)error {
    if (!_propertyValuesCache) {
        NSMutableDictionary *mutableMetadata = [NSMutableDictionary dictionary];
        [mutableMetadata setValue:[[NSProcessInfo processInfo] globallyUniqueString] forKey:NSStoreUUIDKey];
        [mutableMetadata setValue:NSStringFromClass([self class]) forKey:NSStoreTypeKey];
        [self setMetadata:mutableMetadata];
        
        _propertyValuesCache = [[NSCache alloc] init];
        _relationshipsCache = [[NSCache alloc] init];
        
        return YES;
    } else {
        return NO;
    }
}

- (id)executeRequest:(NSPersistentStoreRequest *)persistentStoreRequest 
         withContext:(NSManagedObjectContext *)context 
               error:(NSError *__autoreleasing *)error 
{
    if (persistentStoreRequest.requestType == NSFetchRequestType) {
        NSFetchRequest *fetchRequest = (NSFetchRequest *)persistentStoreRequest;
        
        NSManagedObjectContext *backgroundManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        backgroundManagedObjectContext.parentContext = context;
        backgroundManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

        NSFetchRequest *backgroundFetchRequest = [fetchRequest copy];
        backgroundFetchRequest.entity = [NSEntityDescription entityForName:fetchRequest.entityName inManagedObjectContext:backgroundManagedObjectContext];
        backgroundFetchRequest.resultType = NSManagedObjectIDResultType;
        
        NSURLRequest *request = [self.HTTPClient requestForFetchRequest:fetchRequest withContext:context];
        if ([request URL]) {
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsFromResponseObject:responseObject];
                
                NSArray *representations = nil;
                if ([representationOrArrayOfRepresentations isKindOfClass:[NSArray class]]) {
                    representations = representationOrArrayOfRepresentations;
                } else {
                    representations = [NSArray arrayWithObject:representationOrArrayOfRepresentations];
                }
                
                NSEntityDescription *entity = backgroundFetchRequest.entity;
                [representations enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id representation, NSUInteger idx, BOOL *stop) {
                    NSString *resourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:representation ofEntity:entity];
                    
                    NSManagedObjectID *objectID = [self newObjectIDForEntity:entity referenceObject:resourceIdentifier];
                    NSDictionary *attributes = [self.HTTPClient attributesForRepresentation:representation ofEntity:entity fromResponse:operation.response];
                    NSDictionary *relationshipAttributes = [self.HTTPClient attributesForRepresentation:representation ofEntity:entity fromResponse:operation.response];

                    dispatch_sync(dispatch_get_main_queue(), ^{
                        NSManagedObject *managedObject = [context existingObjectWithID:objectID error:error];
                        [managedObject setValuesForKeysWithDictionary:attributes];
                        
                        [relationshipAttributes enumerateKeysAndObjectsUsingBlock:^(id name, id attributes, BOOL *stop) {
                            NSLog(@"name: %@", name);
                            NSLog(@"relationships: %@", [entity relationshipsByName]);
                            NSRelationshipDescription *relationship = [[entity relationshipsByName] valueForKey:name];
                            if (relationship) {
                                if ([relationship isToMany]) {
                                    for (NSDictionary *individualAttributes in attributes) {
                                        NSString *relationshipResourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:representation ofEntity:entity];
                                        NSManagedObjectID *relationshipObjectID = [self newObjectIDForEntity:relationship.destinationEntity referenceObject:relationshipResourceIdentifier];
                                        NSManagedObject *relationshipObject = [context existingObjectWithID:relationshipObjectID error:nil];
                                        [relationshipObject setValuesForKeysWithDictionary:individualAttributes];
                                        [self cachePropertyValues:individualAttributes forObjectID:relationshipObjectID];
                                    }
                                } else {
                                    NSString *relationshipResourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:representation ofEntity:entity];
                                    NSManagedObjectID *relationshipObjectID = [self newObjectIDForEntity:relationship.entity referenceObject:relationshipResourceIdentifier];
                                    NSManagedObject *relationshipObject = [context existingObjectWithID:relationshipObjectID error:nil];
                                    NSLog(@"Relationship: %@", relationship);
                                    NSLog(@"object: %@", relationshipObject);

//                                    NSManagedObject *relationshipObject = [[NSManagedObject alloc] initWithEntity:relationship.entity insertIntoManagedObjectContext:context];
                                    
                                    [relationshipObject setValuesForKeysWithDictionary:attributes];
                                    [self cachePropertyValues:attributes forObjectID:relationshipObject.objectID];
                                    [managedObject setValue:relationshipObject forKey:relationship.name];
                                    NSLog(@"Managed Object: %@", managedObject);
                                }
                            }
                        }];
                    });
                    
                    [self cachePropertyValues:attributes forObjectID:objectID];
                }];
                
                if (![backgroundManagedObjectContext save:error]) {
                    NSLog(@"Error: %@", *error);
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Error: %@", error);
            }];
            
            operation.successCallbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            [self.HTTPClient enqueueHTTPRequestOperation:operation];
        }

        switch (fetchRequest.resultType) {
            case NSManagedObjectResultType:
            case NSManagedObjectIDResultType:
            case NSDictionaryResultType:
                return [NSArray array];
            case NSCountResultType:
                return [NSArray arrayWithObject:[NSNumber numberWithUnsignedInteger:0]];
            default:
                goto _error;
        }
    } else {
        switch (persistentStoreRequest.requestType) {
            case NSSaveRequestType:
                return nil;
            default:
                goto _error;
        }  
    }
    
    return nil;

    _error: {
        NSMutableDictionary *mutableUserInfo = [NSMutableDictionary dictionary];
        [mutableUserInfo setValue:[NSString stringWithFormat:NSLocalizedString(@"Unsupported NSFetchRequestResultType, %d", nil), persistentStoreRequest.requestType] forKey:NSLocalizedDescriptionKey];
        if (error) {
            *error = [[NSError alloc] initWithDomain:AFNetworkingErrorDomain code:0 userInfo:mutableUserInfo];
        }
        
        return nil;
    }
}

#pragma mark -

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID 
                                         withContext:(NSManagedObjectContext *)context 
                                               error:(NSError *__autoreleasing *)error 
{
    NSDictionary *propertyValues = [self cachedPropertyValuesForObjectID:objectID];
    NSIncrementalStoreNode *node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:propertyValues version:1];

    if (propertyValues) {
        NSManagedObjectContext *backgroundManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        backgroundManagedObjectContext.parentContext = context;    
        backgroundManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        NSURLRequest *request = [self.HTTPClient requestWithMethod:@"GET" pathForObjectWithID:objectID withContext:context];
        
        if ([request URL]) {
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, NSDictionary *representation) {
                NSManagedObject *managedObject = [backgroundManagedObjectContext existingObjectWithID:objectID error:error];
                
                NSMutableDictionary *mutablePropertyValues = [propertyValues mutableCopy];
                [mutablePropertyValues addEntriesFromDictionary:[self.HTTPClient attributesForRepresentation:representation ofEntity:managedObject.entity fromResponse:operation.response]];
                [managedObject setValuesForKeysWithDictionary:mutablePropertyValues];
                
                [self cachePropertyValues:mutablePropertyValues forObjectID:objectID];

                if (![backgroundManagedObjectContext save:error]) {
                    NSLog(@"Error: %@", *error);
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Error: %@, %@", operation, error);
            }];
            
            [self.HTTPClient enqueueHTTPRequestOperation:operation];
        }
    }

    return node;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship 
              forObjectWithID:(NSManagedObjectID *)objectID 
                  withContext:(NSManagedObjectContext *)context 
                        error:(NSError *__autoreleasing *)error
{
    NSDictionary *propertyValues = [self cachedPropertyValuesForObjectID:objectID];
    if (propertyValues) {
        NSManagedObjectContext *backgroundManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        backgroundManagedObjectContext.parentContext = context;
        backgroundManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

        NSURLRequest *request = [self.HTTPClient requestWithMethod:@"GET" pathForRelationship:relationship forObjectWithID:objectID withContext:context];
        
        if ([request URL]) {
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                __block NSManagedObject *managedObject = nil;

                dispatch_sync(dispatch_get_main_queue(), ^{
                    managedObject = [backgroundManagedObjectContext objectWithID:objectID];
                });
                
                id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsFromResponseObject:responseObject];
                
                NSArray *representations = nil;
                if ([representationOrArrayOfRepresentations isKindOfClass:[NSArray class]]) {
                    representations = representationOrArrayOfRepresentations;
                } else {
                    representations = [NSArray arrayWithObject:representationOrArrayOfRepresentations];
                }
                
                NSMutableSet *mutableDestinationObjects = [NSMutableSet setWithCapacity:[representations count]];
                
                NSEntityDescription *entity = relationship.destinationEntity;
                [representations enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id representation, NSUInteger idx, BOOL *stop) {
                    NSString *resourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:representation ofEntity:entity];
                    
                    NSManagedObjectID *destinationObjectID = [self newObjectIDForEntity:entity referenceObject:resourceIdentifier];
                    NSDictionary *propertyValues = [self.HTTPClient attributesForRepresentation:representation ofEntity:entity fromResponse:operation.response];

                    __block NSManagedObject *destinationObject;
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        destinationObject = [backgroundManagedObjectContext existingObjectWithID:destinationObjectID error:error];
                        [destinationObject setValuesForKeysWithDictionary:propertyValues];
                    });
                    
                    if (![backgroundManagedObjectContext save:error]) {
                        NSLog(@"Error: %@", *error);
                    }

                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [mutableDestinationObjects addObject:destinationObject];
                    });
                    [self cachePropertyValues:propertyValues forObjectID:destinationObjectID];
                }];

                dispatch_sync(dispatch_get_main_queue(), ^{
                    if ([relationship isToMany]) {
                        [managedObject setValue:mutableDestinationObjects forKey:relationship.name];
                    } else {
                        [managedObject setValue:[mutableDestinationObjects anyObject] forKey:relationship.name];
                    }
                });
                
                [self cacheObjectIDs:[[mutableDestinationObjects allObjects] valueForKeyPath:@"objectID"] forRelationship:relationship forObjectID:objectID];
                
                if (![backgroundManagedObjectContext save:error]) {
                    NSLog(@"Error: %@", *error);
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Error: %@, %@", operation, error);
            }];

            operation.successCallbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            [self.HTTPClient enqueueHTTPRequestOperation:operation];
        }
    }

    NSArray *objectIDs = [self objectIDSForRelationship:relationship forObjectID:objectID];
    if (objectIDs) {
        if ([relationship isToMany]) {
            return [NSOrderedSet orderedSetWithArray:objectIDs];
        } else {
            return [objectIDs lastObject];
        }
    } else {
        if ([relationship isToMany]) {
            return [NSOrderedSet orderedSet];
        } else {
            return [NSNull null];
        } 
    }
}

#pragma mark - NSIncrementalStore

- (void)managedObjectContextDidUnregisterObjectsWithIDs:(NSArray *)objectIDs {
    for (NSManagedObjectID *objectID in objectIDs) {
        [_propertyValuesCache removeObjectForKey:objectID];
    }
}

#pragma mark -

- (NSString *)propertyValuesCacheKeyForObjectID:(NSManagedObjectID *)objectID {
    return [self referenceObjectForObjectID:objectID];
}

- (void)cachePropertyValues:(NSDictionary *)values 
        forObjectID:(NSManagedObjectID *)objectID 
{
    if (values) {
        [_propertyValuesCache setObject:values forKey:[self propertyValuesCacheKeyForObjectID:objectID]];
    }
}

- (NSDictionary *)cachedPropertyValuesForObjectID:(NSManagedObjectID *)objectID {
    return [_propertyValuesCache objectForKey:[self propertyValuesCacheKeyForObjectID:objectID]];
}

#pragma mark -

- (NSString *)relationshipsCacheKeyForRelationship:(NSRelationshipDescription *)relationship 
                                       andObjectID:(NSManagedObjectID *)objectID
{
    return [[self referenceObjectForObjectID:objectID] stringByAppendingPathComponent:relationship.name];
}

- (void)cacheObjectIDs:(NSArray *)objectIDs 
       forRelationship:(NSRelationshipDescription *)relationship 
           forObjectID:(NSManagedObjectID *)objectID 
{
    [_relationshipsCache setObject:objectIDs forKey:[self relationshipsCacheKeyForRelationship:relationship andObjectID:objectID]];
}

- (NSArray *)objectIDSForRelationship:(NSRelationshipDescription *)relationship 
                          forObjectID:(NSManagedObjectID *)objectID 
{
    return [_relationshipsCache objectForKey:[self relationshipsCacheKeyForRelationship:relationship andObjectID:objectID]];
}

@end
