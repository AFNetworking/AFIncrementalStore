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

static NSString * AFPluralizedString(NSString *string) {
    if ([string hasSuffix:@"ss"] || [string hasSuffix:@"se"] || [string hasSuffix:@"sh"] || [string hasSuffix:@"ge"] || [string hasSuffix:@"ch"]) {
        return [[string stringByAppendingString:@"es"] lowercaseString];
    } else {
        return [[string stringByAppendingString:@"s"] lowercaseString];
    }
}

@implementation AFRESTClient

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

- (NSString *)resourceIdentifierForRepresentation:(NSDictionary *)representation
                                         ofEntity:(NSEntityDescription *)entity
{
    static NSArray *_candidatePropertyNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _candidatePropertyNames = [NSArray arrayWithObjects:@"ID", @"resourceIdentifier", @"identifier", @"url", @"URL", @"URLString", nil];
    });
    
    NSString *key = [[representation allKeys] firstObjectCommonWithArray:_candidatePropertyNames];
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
    NSMutableDictionary *mutablePropertyValues = [representation mutableCopy];
    @autoreleasepool {
        NSMutableSet *mutableKeys = [NSMutableSet setWithArray:[representation allKeys]];
        [mutableKeys minusSet:[NSSet setWithArray:[[entity propertiesByName] allKeys]]];
        [mutablePropertyValues removeObjectsForKeys:[mutableKeys allObjects]];
    }
    
    NSSet *keysWithNestedValues = [mutablePropertyValues keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return [obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSDictionary class]];
    }];
    NSLog(@"KEYS: %@", keysWithNestedValues);
    [mutablePropertyValues removeObjectsForKeys:[keysWithNestedValues allObjects]];
    
    return mutablePropertyValues;
}

- (NSDictionary *)relationshipAttributesForRepresentation:(NSDictionary *)representation
                                                 ofEntity:(NSEntityDescription *)entity
                                             fromResponse:(NSHTTPURLResponse *)response
{
    NSMutableDictionary *mutableRelationshipAttributes = [NSMutableDictionary dictionaryWithCapacity:[entity.relationshipsByName count]];
    [entity.relationshipsByName enumerateKeysAndObjectsUsingBlock:^(id name, id relationship, BOOL *stop) {
        id value = [representation valueForKey:name];
        if (value) {
            NSLog(@"!!! %@: %@", name, value);
            if ([relationship isToMany]) {
                NSArray *arrayOfRelationshipRepresentations = nil;
                if ([value isKindOfClass:[NSArray class]]) {
                    arrayOfRelationshipRepresentations = value;
                } else {
                    arrayOfRelationshipRepresentations = [NSArray arrayWithObject:value];
                }
                
                NSMutableArray *mutableArrayOfRelationshipAttributes = [NSMutableArray arrayWithCapacity:[arrayOfRelationshipRepresentations count]];
                for (NSDictionary *relationshipRepresentation in arrayOfRelationshipRepresentations) {
                    NSDictionary *relationshipAttributes = [self attributesForRepresentation:relationshipRepresentation ofEntity:[relationship destinationEntity] fromResponse:response];
                    [mutableArrayOfRelationshipAttributes addObject:relationshipAttributes];
                }
                
                [mutableRelationshipAttributes setValue:mutableArrayOfRelationshipAttributes forKey:name];
            } else {
                NSDictionary *relationshipRepresentation = value;
                NSDictionary *relationshipAttributes = [self attributesForRepresentation:relationshipRepresentation ofEntity:[relationship destinationEntity] fromResponse:response];
                [mutableRelationshipAttributes setValue:relationshipAttributes forKey:name];
            }
        } else {
            NSLog(@"!!!! %@", name);
        }
    }];
    
    return mutableRelationshipAttributes;
}

- (NSURLRequest *)requestForFetchRequest:(NSFetchRequest *)fetchRequest 
                             withContext:(NSManagedObjectContext *)context
{    
    return [self requestWithMethod:@"GET" path:[self pathForEntity:fetchRequest.entity] parameters:nil];
}

- (NSURLRequest *)requestWithMethod:(NSString *)method
                pathForObjectWithID:(NSManagedObjectID *)objectID
                        withContext:(NSManagedObjectContext *)context
{
    NSManagedObject *object = [context objectWithID:objectID];
    return [self requestWithMethod:method path:[self pathForObject:object] parameters:nil];
}

- (NSURLRequest *)requestWithMethod:(NSString *)method
                pathForRelationship:(NSRelationshipDescription *)relationship
                    forObjectWithID:(NSManagedObjectID *)objectID
                        withContext:(NSManagedObjectContext *)context
{
    NSManagedObject *object = [context objectWithID:objectID];
    return [self requestWithMethod:method path:[self pathForRelationship:relationship forObject:object] parameters:nil];
}

#pragma mark - AFHTTPClient

- (void)enqueueHTTPRequestOperation:(AFHTTPRequestOperation *)operation {
    [self cancelAllHTTPOperationsWithMethod:operation.request.HTTPMethod path:operation.request.URL.path];
    [super enqueueHTTPRequestOperation:operation];
}

@end
