// AFIncrementalStore.h
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

#import <CoreData/CoreData.h>
#import "AFNetworking.h"

extern NSString * AFIncrementalStoreUnimplementedMethodException;

@protocol AFIncrementalStoreDelegate;
@protocol AFIncrementalStoreHTTPClient;

@interface AFIncrementalStore : NSIncrementalStore

@property (nonatomic, strong) AFHTTPClient <AFIncrementalStoreHTTPClient> *HTTPClient;
@property (readonly) NSPersistentStoreCoordinator *backingPersistentStoreCoordinator;

+ (NSString *)type;

+ (NSManagedObjectModel *)model;

@end

#pragma mark -

@protocol AFIncrementalStoreHTTPClient <NSObject>

- (id)representationOrArrayOfRepresentationsFromResponseObject:(id)responseObject;

- (NSDictionary *)representationsForRelationshipsFromRepresentation:(NSDictionary *)representation
                                                           ofEntity:(NSEntityDescription *)entity
                                                       fromResponse:(NSHTTPURLResponse *)response;

- (NSString *)resourceIdentifierForRepresentation:(NSDictionary *)representation
                                         ofEntity:(NSEntityDescription *)entity
                                     fromResponse:(NSHTTPURLResponse *)response;

- (NSDictionary *)attributesForRepresentation:(NSDictionary *)representation
                                     ofEntity:(NSEntityDescription *)entity
                                 fromResponse:(NSHTTPURLResponse *)response;

- (NSURLRequest *)requestForFetchRequest:(NSFetchRequest *)fetchRequest
                             withContext:(NSManagedObjectContext *)context;

- (NSURLRequest *)requestWithMethod:(NSString *)method
                pathForObjectWithID:(NSManagedObjectID *)objectID
                        withContext:(NSManagedObjectContext *)context;

- (NSURLRequest *)requestWithMethod:(NSString *)method
                pathForRelationship:(NSRelationshipDescription *)relationship
                    forObjectWithID:(NSManagedObjectID *)objectID
                        withContext:(NSManagedObjectContext *)context;

@optional

- (BOOL)shouldFetchRemoteAttributeValuesForObjectWithID:(NSManagedObjectID *)objectID
                                 inManagedObjectContext:(NSManagedObjectContext *)context;

- (BOOL)shouldFetchRemoteValuesForRelationship:(NSRelationshipDescription *)relationship
                               forObjectWithID:(NSManagedObjectID *)objectID
                        inManagedObjectContext:(NSManagedObjectContext *)context;

@end
