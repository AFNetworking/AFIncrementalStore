// AFRESTClient.m
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

#import "AFRESTClient.h"
#import "ISO8601DateFormatter.h"

NSString * AFPluralizedString(NSString *string) {
    if ([string hasSuffix:@"ss"] || [string hasSuffix:@"se"] || [string hasSuffix:@"sh"] || [string hasSuffix:@"ch"]) {
        return [[string stringByAppendingString:@"es"] lowercaseString];
    } else {
        return [[string stringByAppendingString:@"s"] lowercaseString];
    }
}

@implementation AFRESTClient

@synthesize supportRelationsByID;

- (NSString *)pathForEntity:(NSEntityDescription *)entity {
    return AFPluralizedString(entity.name);
}

- (NSString *)pathForObject:(NSManagedObject *)object {
    NSString *resourceIdentifier = [(NSIncrementalStore *)object.objectID.persistentStore referenceObjectForObjectID:object.objectID];
    return [[self pathForEntity:object.entity] stringByAppendingPathComponent:[resourceIdentifier lastPathComponent]];
}

- (NSString *)pathForRelationship:(NSRelationshipDescription *)relationship 
                        forObject:(NSManagedObject *)object
{
    return [[self pathForObject:object] stringByAppendingPathComponent:relationship.name];
}

#pragma mark - AFIncrementalStoreHTTPClient

#pragma mark Read Methods

- (id)representationOrArrayOfRepresentationsFromResponseObject:(id)responseObject {
    if ([responseObject isKindOfClass:[NSArray class]]) {
        return responseObject;
    } else if ([responseObject isKindOfClass:[NSDictionary class]]) {
        // Distinguish between keyed array or individual representation
        if ([[responseObject allKeys] count] == 1) {
            id value = [responseObject valueForKey:[[responseObject allKeys] lastObject]];
            if ([value isKindOfClass:[NSArray class]]) {
                return value;
            }
        }
        
        return responseObject;
    }
    
    return responseObject;
}

- (NSDictionary *)representationsForRelationshipsFromRepresentation:(NSDictionary *)representation
                                                           ofEntity:(NSEntityDescription *)entity
                                                       fromResponse:(NSHTTPURLResponse *)response
{
    NSMutableDictionary *mutableRelationshipRepresentations = [NSMutableDictionary dictionaryWithCapacity:[entity.relationshipsByName count]];
    [entity.relationshipsByName enumerateKeysAndObjectsUsingBlock:^(id name, id relationship, BOOL *stop) {
        NSString *relationKey = name;
        if (self.supportRelationsByID) {
            relationKey = [relationKey stringByAppendingString:@"_id"];
            if ([relationship isToMany]) relationKey = [relationKey stringByAppendingString:@"s"];
        }
        
        id value = [representation valueForKey:relationKey];
        if (value) {
            if ([relationship isToMany]) {
                NSArray *arrayOfRelationshipRepresentations = nil;
                if ([value isKindOfClass:[NSArray class]]) {
                    
                    if (self.supportRelationsByID) {
                        NSMutableArray *valueArray = [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
                        for (id oneValue in value) {
                            [valueArray addObject:@{@"id" : oneValue}];
                        }
                        value = valueArray;
                    }
                    
                    arrayOfRelationshipRepresentations = value;
                } else {
                    if (self.supportRelationsByID) value = @{@"id" : value};
                    arrayOfRelationshipRepresentations = [NSArray arrayWithObject:value];
                }
                                
                [mutableRelationshipRepresentations setValue:arrayOfRelationshipRepresentations forKey:relationKey];
            } else {
                if (self.supportRelationsByID) value = @{@"id" : value};
                [mutableRelationshipRepresentations setValue:value forKey:relationKey];
            }
        }
    }];
    
    return mutableRelationshipRepresentations;
}

- (NSString *)resourceIdentifierForRepresentation:(NSDictionary *)representation
                                         ofEntity:(NSEntityDescription *)entity
                                     fromResponse:(NSHTTPURLResponse *)response
{
    static NSArray *_candidateKeys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _candidateKeys = [NSArray arrayWithObjects:@"id", @"identifier", @"url", @"URL", nil];
    });
    
    NSString *key = [[representation allKeys] firstObjectCommonWithArray:_candidateKeys];
    if (key) {
        id value = [representation valueForKey:key];
        if (value) {
            return [value description];
        }
    }
    
    return nil;
}

- (NSDictionary *)attributesForRepresentation:(NSDictionary *)representation
                                     ofEntity:(NSEntityDescription *)entity
                                 fromResponse:(NSHTTPURLResponse *)response
{
    static ISO8601DateFormatter *_iso8601DateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _iso8601DateFormatter = [[ISO8601DateFormatter alloc] init];
    });
    
    if ([representation isEqual:[NSNull null]]) {
        return nil;
    }
    
    NSMutableDictionary *mutableAttributes = [representation mutableCopy];
    @autoreleasepool {
        NSMutableSet *mutableKeys = [NSMutableSet setWithArray:[representation allKeys]];
        [mutableKeys minusSet:[NSSet setWithArray:[[entity propertiesByName] allKeys]]];
        [mutableAttributes removeObjectsForKeys:[mutableKeys allObjects]];
    }
    
    NSSet *keysWithNestedValues = [mutableAttributes keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return [obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSDictionary class]];
    }];
    [mutableAttributes removeObjectsForKeys:[keysWithNestedValues allObjects]];
    
    [[entity attributesByName] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([(NSAttributeDescription *)obj attributeType] == NSDateAttributeType) {
            id value = [mutableAttributes valueForKey:key];
            if (value && ![value isEqual:[NSNull null]]) {
                [mutableAttributes setValue:[_iso8601DateFormatter dateFromString:value] forKey:key];
            }
        }
    }];
    
    return mutableAttributes;
}

- (NSMutableURLRequest *)requestForFetchRequest:(NSFetchRequest *)fetchRequest
                                    withContext:(NSManagedObjectContext *)context
{
    NSMutableURLRequest *mutableRequest =  [self requestWithMethod:@"GET" path:[self pathForEntity:fetchRequest.entity] parameters:nil];
    mutableRequest.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    
    return mutableRequest;
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                       pathForObjectWithID:(NSManagedObjectID *)objectID
                               withContext:(NSManagedObjectContext *)context
{
    NSManagedObject *object = [context objectWithID:objectID];
    return [self requestWithMethod:method path:[self pathForObject:object] parameters:nil];
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                       pathForRelationship:(NSRelationshipDescription *)relationship
                           forObjectWithID:(NSManagedObjectID *)objectID
                               withContext:(NSManagedObjectContext *)context
{
    NSManagedObject *object = [context objectWithID:objectID];
    return [self requestWithMethod:method path:[self pathForRelationship:relationship forObject:object] parameters:nil];
}

- (BOOL)shouldFetchRemoteValuesForRelationship:(NSRelationshipDescription *)relationship
                               forObjectWithID:(NSManagedObjectID *)objectID
                        inManagedObjectContext:(NSManagedObjectContext *)context
{
    return [relationship isToMany] || ![relationship inverseRelationship];
}

#pragma mark Write Methods

- (NSDictionary *)representationOfAttributes:(NSDictionary *)attributes
                             ofManagedObject:(NSManagedObject *)managedObject
{
    return attributes;
}

- (NSMutableURLRequest *)requestForInsertedObject:(NSManagedObject *)insertedObject {
    return [self requestWithMethod:@"POST" path:[self pathForEntity:insertedObject.entity] parameters:[self representationOfAttributes:[insertedObject dictionaryWithValuesForKeys:[insertedObject.entity.attributesByName allKeys]] ofManagedObject:insertedObject]];
}

- (NSMutableURLRequest *)requestForUpdatedObject:(NSManagedObject *)updatedObject {
    return [self requestWithMethod:@"PUT" path:[self pathForObject:updatedObject] parameters:[self representationOfAttributes:[[updatedObject changedValuesForCurrentEvent] dictionaryWithValuesForKeys:[updatedObject.entity.attributesByName allKeys]] ofManagedObject:updatedObject]];
}

- (NSMutableURLRequest *)requestForDeletedObject:(NSManagedObject *)deletedObject {
    return [self requestWithMethod:@"PUT" path:[self pathForObject:deletedObject] parameters:nil];
}

#pragma mark - AFHTTPClient

- (void)enqueueHTTPRequestOperation:(AFHTTPRequestOperation *)operation {
    [self cancelAllHTTPOperationsWithMethod:operation.request.HTTPMethod path:operation.request.URL.path];
    [super enqueueHTTPRequestOperation:operation];
}

@end
