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

@protocol AFIncrementalStoreHTTPClient;

/**
 `AFIncrementalStore` is an abstract subclass of `NSIncrementalStore`, designed to allow you to load and save data incrementally to and from a one or more web services.
 
 ## Subclassing Notes
 
 ### Methods to Override
 
 In a subclass of `AFIncrementalStore`, you _must_ override the following methods to provide behavior appropriate for your store:
    
    - `+type`
    - `+model`
 
 Additionally, all `NSPersistentStore` subclasses, and thus all `AFIncrementalStore` subclasses must do `NSPersistentStoreCoordinator +registerStoreClass:forStoreType:` in order to be created by `NSPersistentStoreCoordinator -addPersistentStoreWithType:configuration:URL:options:error:`. It is recommended that subclasses register themselves in their own `+initialize` method.
 
 Optionally, `AFIncrementalStore` subclasses can override the following methods:
 
    - `-executeFetchRequest:withContext:error:`
    - `-executeSaveChangesRequest:withContext:error:`

 ### Methods Not To Be Overridden
 
 Subclasses should not override `-executeRequest:withContext:error`. Instead, override `-executeFetchRequest:withContext:error:` or `-executeSaveChangesRequest:withContext:error:`, which are called by `-executeRequest:withContext:error` depending on the type of persistent store request.
 */
@interface AFIncrementalStore : NSIncrementalStore

///---------------------------------------------
/// @name Accessing Incremental Store Properties
///---------------------------------------------

/**
 The HTTP client used to manage requests and responses with the associated web services.
 */
@property (nonatomic, strong) AFHTTPClient <AFIncrementalStoreHTTPClient> *HTTPClient;

/**
 The persistent store coordinator used to persist data from the associated web serivices locally.
 
 @discussion Rather than persist values directly, `AFIncrementalStore` manages and proxies through a persistent store coordinator.
 */
@property (readonly) NSPersistentStoreCoordinator *backingPersistentStoreCoordinator;

///-----------------------
/// @name Required Methods
///-----------------------

/**
 Returns the string used as the `NSStoreTypeKey` value by the application's persistent store coordinator.
 
 @return The string used to describe the type of the store.
 */
+ (NSString *)type;

/**
 Returns the managed object model used by the store.
 
 @return The managed object model used by the store
 */
+ (NSManagedObjectModel *)model;

///-----------------------
/// @name Optional Methods
///-----------------------

/**
 
 */
- (id)executeFetchRequest:(NSFetchRequest *)fetchRequest
              withContext:(NSManagedObjectContext *)context
                    error:(NSError *__autoreleasing *)error;

/**
 
 */
- (id)executeSaveChangesRequest:(NSSaveChangesRequest *)saveChangesRequest
                    withContext:(NSManagedObjectContext *)context
                          error:(NSError *__autoreleasing *)error;

@end

#pragma mark -

/**
 The `AFIncrementalStoreHTTPClient` protocol defines the methods used by the HTTP client to interract with the associated web services of an `AFIncrementalStore`.
 */
@protocol AFIncrementalStoreHTTPClient <NSObject>

///-----------------------
/// @name Required Methods
///-----------------------

/**
 Returns an `NSDictionary` or an `NSArray` of `NSDictionaries` containing the representations of the resources found in a response object.
 
 @discussion For example, if `GET /users` returned an `NSDictionary` with an array of users keyed on `"users"`, this method would return the keyed array. Conversely, if `GET /users/123` returned a dictionary with all of the atributes of the requested user, this method would simply return that dictionary.

 @param entity The entity represented
 @param responseObject The response object returned from the server.
 
 @return An `NSDictionary` with the representation or an `NSArray` of `NSDictionaries` containing the resource representations.
 */
- (id)representationOrArrayOfRepresentationsOfEntity:(NSEntityDescription *)entity
                                  fromResponseObject:(id)responseObject;

/**
 Returns an `NSDictionary` containing the representations of associated objects found within the representation of a response object, keyed by their relationship name.
 
 @discussion For example, if `GET /albums/123` returned the representation of an album, including the tracks as sub-entities, keyed under `"tracks"`, this method would return a dictionary with an array of representations for those objects, keyed under the name of the relationship used in the model (which is likely also to be `"tracks"`). Likewise, if an album also contained a representation of its artist, that dictionary would contain a dictionary representation of that artist, keyed under the name of the relationship used in the model (which is likely also to be `"artist"`).
 
 @param representation The resource representation.
 @param entity The entity for the representation.
 @param response The HTTP response for the resource request.
 
 @return An `NSDictionary` containing representations of relationships, keyed by relationship name.
 */
- (NSDictionary *)representationsForRelationshipsFromRepresentation:(NSDictionary *)representation
                                                           ofEntity:(NSEntityDescription *)entity
                                                       fromResponse:(NSHTTPURLResponse *)response;

/**
 Returns the resource identifier for the resource whose representation of an entity came from the specified HTTP response. A resource identifier is a string that uniquely identifies a particular resource among all resource types. If new attributes come back for an existing resource identifier, the managed object associated with that resource identifier will be updated, rather than a new object being created.
 
 @discussion For example, if `GET /posts` returns a collection of posts, the resource identifier for any particular one might be its URL-safe "slug" or parameter string, or perhaps its numeric id.  For example: `/posts/123` might be a resource identifier for a particular post.
 
 @param representation The resource representation.
 @param entity The entity for the representation.
 @param response The HTTP response for the resource request.
 
 @return An `NSString` resource identifier for the resource.
 */
- (NSString *)resourceIdentifierForRepresentation:(NSDictionary *)representation
                                         ofEntity:(NSEntityDescription *)entity
                                     fromResponse:(NSHTTPURLResponse *)response;

/**
 Returns the attributes for the managed object corresponding to the representation of an entity from the specified response. This method is used to get the attributes of the managed object from its representation returned in `-representationOrArrayOfRepresentationsFromResponseObject` or `representationsForRelationshipsFromRepresentation:ofEntity:fromResponse:`.
 
 @discussion For example, if the representation returned from `GET /products/123` had a `description` field that corresponded with the `productDescription` attribute in its Core Data model, this method would set the value of the `productDescription` key in the returned dictionary to the value of the `description` field in representation.
 
 @param representation The resource representation.
 @param entity The entity for the representation.
 @param response The HTTP response for the resource request.
 
 @return An `NSDictionary` containing the attributes for a managed object. 
 */
- (NSDictionary *)attributesForRepresentation:(NSDictionary *)representation
                                     ofEntity:(NSEntityDescription *)entity
                                 fromResponse:(NSHTTPURLResponse *)response;

/**
 Returns a URL request object for the specified fetch request within a particular managed object context.
 
 @discussion For example, if the fetch request specified the `User` entity, this method might return an `NSURLRequest` with `GET /users` if the web service was RESTful, `POST /endpoint?method=users.getAll` for an RPC-style system, or a request with an XML envelope body for a SOAP webservice.
 
 @param fetchRequest The fetch request to translate into a URL request.
 @param context The managed object context executing the fetch request.
 
 @return An `NSURLRequest` object corresponding to the specified fetch request.
 */
- (NSMutableURLRequest *)requestForFetchRequest:(NSFetchRequest *)fetchRequest
                                    withContext:(NSManagedObjectContext *)context;

/**
 Returns a URL request object with a given HTTP method for a particular managed object. This method is used in `AFIncrementalStore -newValuesForObjectWithID:withContext:error`.
 
 @discussion For example, if a `User` managed object were to be refreshed, this method might return a `GET /users/123` request.
 
 @param method The HTTP method of the request.
 @param objectID The object ID for the specified managed object.
 @param context The managed object context for the managed object.
 
 @return An `NSURLRequest` object with the provided HTTP method for the resource corresponding to the managed object.
 */
- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                       pathForObjectWithID:(NSManagedObjectID *)objectID
                               withContext:(NSManagedObjectContext *)context;

/**
 Returns a URL request object with a given HTTP method for a particular relationship of a given managed object. This method is used in `AFIncrementalStore -newValueForRelationship:forObjectWithID:withContext:error:`.
 
 @discussion For example, if a `Department` managed object was attempting to fulfill a fault on the `employees` relationship, this method might return `GET /departments/sales/employees`.
 
 @param method The HTTP method of the request.
 @param relationship The relationship of the specifified managed object 
 @param objectID The object ID for the specified managed object.
 @param context The managed object context for the managed object.
 
 @return An `NSURLRequest` object with the provided HTTP method for the resource or resoures corresponding to the relationship of the managed object.

 */
- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                       pathForRelationship:(NSRelationshipDescription *)relationship
                           forObjectWithID:(NSManagedObjectID *)objectID
                               withContext:(NSManagedObjectContext *)context;

@optional

///-----------------------
/// @name Optional Methods
///-----------------------

/**
 Returns the attributes representation of an entity from the specified managed object. This method is used to get the attributes of the representation from its managed object.
 
 @discussion For example, if the representation sent to `POST /products` or `PUT /products/123` had a `description` field that corresponded with the `productDescription` attribute in its Core Data model, this method would set the value of the `productDescription` field to the value of the `description` key in representation/dictionary.
 
 @param attributes The resource representation.
 @param managedObject The `NSManagedObject` for the representation.
 
 @return An `NSDictionary` containing the attributes for a representation, based on the given managed object. 
 */
- (NSDictionary *)representationOfAttributes:(NSDictionary *)attributes
                             ofManagedObject:(NSManagedObject *)managedObject;

/**
 
 */
- (NSMutableURLRequest *)requestForInsertedObject:(NSManagedObject *)insertedObject;

/**
 
 */
- (NSMutableURLRequest *)requestForUpdatedObject:(NSManagedObject *)updatedObject;

/**
 
 */
- (NSMutableURLRequest *)requestForDeletedObject:(NSManagedObject *)deletedObject;

/**
 Returns whether the client should fetch remote attribute values for a particular managed object. This method is consulted when a managed object faults on an attribute, and will call `-requestWithMethod:pathForObjectWithID:withContext:` if `YES`.
 
 @param objectID The object ID for the specified managed object.
 @param context The managed object context for the managed object.
 
 @return `YES` if an HTTP request should be made, otherwise `NO.
 */
- (BOOL)shouldFetchRemoteAttributeValuesForObjectWithID:(NSManagedObjectID *)objectID
                                 inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 Returns whether the client should fetch remote relationship values for a particular managed object. This method is consulted when a managed object faults on a particular relationship, and will call `-requestWithMethod:pathForRelationship:forObjectWithID:withContext:` if `YES`.
 
 @param relationship The relationship of the specifified managed object
 @param objectID The object ID for the specified managed object.
 @param context The managed object context for the managed object.
 
 @return `YES` if an HTTP request should be made, otherwise `NO.
 */
- (BOOL)shouldFetchRemoteValuesForRelationship:(NSRelationshipDescription *)relationship
                               forObjectWithID:(NSManagedObjectID *)objectID
                        inManagedObjectContext:(NSManagedObjectContext *)context;

@end

///----------------
/// @name Functions
///----------------

/** 
 There is a bug in Core Data wherein managed object IDs whose reference object is a string beginning with a digit will incorrectly strip any subsequent non-numeric characters from the reference object. This breaks any functionality related to URI representations of the managed object ID, and likely other methods as well. For example, an object ID with a reference object of @"123ABC" would generate one with a URI represenation `coredata://store-UUID/Entity/123`, rather than the expected `coredata://store-UUID/Entity/123ABC`. As a fix, rather than resource identifiers being used directly as reference objects, they are prepended with a non-numeric constant first.
 
 Thus, in order to get the resource identifier of a managed object's reference object, you must use the function `AFResourceIdentifierFromReferenceObject()`.
    
 See https://github.com/AFNetworking/AFIncrementalStore/issues/82 for more details.
 */
extern NSString * AFReferenceObjectFromResourceIdentifier(NSString *resourceIdentifier);

extern NSString * AFResourceIdentifierFromReferenceObject(id referenceObject);

///----------------
/// @name Constants
///----------------

/**
 The name of the exception called when `AFIncrementalStore` or a subclass is attempted to be used, without implementing one of the required methods.
 */
extern NSString * const AFIncrementalStoreUnimplementedMethodException;

///--------------------
/// @name Notifications
///--------------------

/**
 Posted before an HTTP request operation corresponding to a fetch request starts. 
 The object is the managed object context of the request.
 The notification `userInfo` contains the finished request operation, keyed at `AFIncrementalStoreRequestOperationKey`, as well as the associated persistent store request, if applicable, keyed at `AFIncrementalStorePersistentStoreRequestKey`.
 */
extern NSString * const AFIncrementalStoreContextWillFetchRemoteValues;

/**
 Posted after an HTTP request operation corresponding to a fetch request finishes.
 The object is the managed object context of the request.
 The notification `userInfo` contains the finished request operation, keyed at `AFIncrementalStoreRequestOperationKey`, as well as the associated persistent store request, if applicable, keyed at `AFIncrementalStorePersistentStoreRequestKey`.
 */
extern NSString * const AFIncrementalStoreContextDidFetchRemoteValues;

//------------------------------------------------------------------------------

/**
 Posted before an HTTP request operation corresponding to a fetch request starts.
 The object is the managed object context of the request.
 The notification `userInfo` contains an array of request operations, keyed at `AFIncrementalStoreRequestOperationKey`, as well as the associated persistent store request, if applicable, keyed at `AFIncrementalStorePersistentStoreRequestKey`.
 */
extern NSString * const AFIncrementalStoreContextWillSaveRemoteValues;

/**
 Posted after an HTTP request operation corresponding to a fetch request finishes.
 The object is the managed object context of the request.
 The notification `userInfo` contains an array of request operations, keyed at `AFIncrementalStoreRequestOperationKey`, as well as the associated persistent store request, if applicable, keyed at `AFIncrementalStorePersistentStoreRequestKey`.
 */
extern NSString * const AFIncrementalStoreContextDidSaveRemoteValues;

//------------------------------------------------------------------------------

/**
 Posted before an HTTP request operation corresponding to an attribute fault starts.
 The object is the managed object context of the request.
 The notification `userInfo` contains an array of request operations, keyed at `AFIncrementalStoreRequestOperationKey`, as well as the managed object ID of the faulting object, keyed at `AFIncrementalStoreFaultingObjectIDKey`.
 */
extern NSString * const AFIncrementalStoreContextWillFetchNewValuesForObject;

/**
 Posted after an HTTP request operation corresponding to an attribute fault finishes.
 The object is the managed object context of the request.
 The notification `userInfo` contains an array of request operations, keyed at `AFIncrementalStoreRequestOperationKey`, as well as the managed object ID of the faulting object, keyed at `AFIncrementalStoreFaultingObjectIDKey`.
 */
extern NSString * const AFIncrementalStoreContextDidFetchNewValuesForObject;

//------------------------------------------------------------------------------

/**
 Posted before an HTTP request operation corresponding to an relationship fault starts.
 The object is the managed object context of the request.
 The notification `userInfo` contains an array of request operations, keyed at `AFIncrementalStoreRequestOperationKey`, as well as the faulting relationship, keyed at `AFIncrementalStoreFaultingRelationshipKey`, and the managed object ID of the faulting object, keyed at `AFIncrementalStoreFaultingObjectIDKey`.

 */
extern NSString * const AFIncrementalStoreContextWillFetchNewValuesForRelationship;

/**
 Posted after an HTTP request operation corresponding to a relationship fault finishes.
 The object is the managed object context of the request.
 The notification `userInfo` contains an array of request operations, keyed at `AFIncrementalStoreRequestOperationKey`, as well as the faulting relationship, keyed at `AFIncrementalStoreFaultingRelationshipKey`, and the managed object ID of the faulting object, keyed at `AFIncrementalStoreFaultingObjectIDKey`.
 */
extern NSString * const AFIncrementalStoreContextDidFetchNewValuesForRelationship;

//------------------------------------------------------------------------------

/**
 A key in the `userInfo` dictionary in a `AFIncrementalStoreContextWillFetchRemoteValues` or `AFIncrementalStoreContextDidFetchRemoteValues` as well as `AFIncrementalStoreContextWillSaveRemoteValues` or `AFIncrementalStoreContextDidSaveRemoteValues` notifications.
 The corresponding value is an `NSArray` of `AFHTTPRequestOperation` objects corresponding to the request operations triggered by the fetch or save changes request. 
 */
extern NSString * const AFIncrementalStoreRequestOperationsKey;

/**
 A key in the `userInfo` dictionary in a `AFIncrementalStoreContextWillFetchRemoteValues` or `AFIncrementalStoreContextDidFetchRemoteValues` notification.
 The corresponding value is an `NSArray` of `NSManagedObjectIDs` for the objects returned by the remote HTTP request for the associated fetch request.
 */
extern NSString * const AFIncrementalStoreFetchedObjectIDsKey;

/**
 A key in the `userInfo` dictionary in a `AFIncrementalStoreContextWillFetchNewValuesForObject` or `AFIncrementalStoreContextDidFetchNewValuesForObject` notification.
 The corresponding value is an `NSManagedObjectID` for the faulting managed object.
 */
extern NSString * const AFIncrementalStoreFaultingObjectIDKey;

/**
 A key in the `userInfo` dictionary in a `AFIncrementalStoreContextWillFetchNewValuesForRelationship` or `AFIncrementalStoreContextDidFetchNewValuesForRelationship` notification.
 The corresponding value is an `NSRelationshipDescription` for the faulting relationship.
 */
extern NSString * const AFIncrementalStoreFaultingRelationshipKey;

/**
 A key in the `userInfo` dictionary in a `AFIncrementalStoreContextWillFetchRemoteValues` or `AFIncrementalStoreContextDidFetchRemoteValues` notification.
 The corresponding value is an `NSPersistentStoreRequest` object representing the associated fetch or save request. */
extern NSString * const AFIncrementalStorePersistentStoreRequestKey;
