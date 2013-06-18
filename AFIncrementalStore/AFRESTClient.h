// AFRESTClient.h
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

#import "AFHTTPClient.h"
#import "AFHTTPRequestOperation.h"
#import "AFIncrementalStore.h"
#import "TTTStringInflector.h"

@protocol AFPaginator;

/**
 `AFRESTClient` is a subclass of `AFHTTPClient` that implements the `AFIncrementalStoreHTTPClient` protocol in a way that follows the conventions of a RESTful web service.
 */
@interface AFRESTClient : AFHTTPClient <AFIncrementalStoreHTTPClient>

/**
 
 */
@property (nonatomic, strong) id <AFPaginator> paginator;

/**
 
 */
@property (readonly, nonatomic, strong) TTTStringInflector *inflector;

///------------------------
/// @name Determining Paths
///------------------------

/**
 Returns the request path for a collection of resources of the specified entity. By default, this returns an imprecise pluralization of the entity name.
 
 @discussion The return value of this method is used as the `path` parameter in other `AFHTTPClient` methods.
 
 @param entity The entity used to determine the resources path.
 
 @return An `NSString` representing the request path.
 */
- (NSString *)pathForEntity:(NSEntityDescription *)entity;

/**
 Returns the request path for the resource of a particular managed object. By default, this returns an imprecise pluralization of the entity name, with the additional path component of the resource identifier corresponding to the managed object.
 
 @discussion The return value of this method is used as the `path` parameter in other `AFHTTPClient` methods.
 
 @param object The managed object used to determine the resource path.
 
 @return An `NSString` representing the request path.
 */
- (NSString *)pathForObject:(NSManagedObject *)object;

/**
 Returns the request path for the resource of a particular managed object. By default, this returns an imprecise pluralization of the entity name, with the additional path component of either an imprecise pluralization of the relationship destination entity name if the relationship is to-many, or the relationship destination entity name if to-one.
 
 @discussion The return value of this method is used as the `path` parameter in other `AFHTTPClient` methods.
 
 @param relationship The relationship used to determine the resource path
 @param object The managed object used to determine the resource path.
 
 @return An `NSString` representing the request path.
 */
- (NSString *)pathForRelationship:(NSRelationshipDescription *)relationship
                        forObject:(NSManagedObject *)object;

@end

///-----------------
/// @name Pagination
///-----------------

/**
 
 */
@protocol AFPaginator <NSObject>
- (NSDictionary *)parametersForFetchRequest:(NSFetchRequest *)fetchRequest;
@end

/**
 
 */
@interface AFLimitAndOffsetPaginator : NSObject <AFPaginator>

@property (readonly, nonatomic, copy) NSString *limitParameter;
@property (readonly, nonatomic, copy) NSString *offsetParameter;

+ (instancetype)paginatorWithLimitParameter:(NSString *)limitParameterName
                            offsetParameter:(NSString *)offsetParameterName;
@end

/**
 
 */
@interface AFPageAndPerPagePaginator : NSObject <AFPaginator>

@property (readonly, nonatomic, copy) NSString *pageParameter;
@property (readonly, nonatomic, copy) NSString *perPageParameter;

+ (instancetype)paginatorWithPageParameter:(NSString *)pageParameterName
                          perPageParameter:(NSString *)perPageParameterName;
@end

/**
 
 */
@interface AFBlockPaginator : NSObject <AFPaginator>
+ (instancetype)paginatorWithBlock:(NSDictionary * (^)(NSFetchRequest *fetchRequest))block;
@end
