//
//  NSManagedObjectContext+AFIncrementalStore.h
//  Sharely
//
//  Created by Adam Price on 10/16/12.
//  Copyright (c) 2012 Fuzz Productions. All rights reserved.
//

#import <CoreData/CoreData.h>

typedef void (^AFSaveRequestCompletionBlock)(NSSet *insertedObjects, NSSet *updatedObjects);
typedef void (^AFFetchRequestCompletionBlock)(NSArray *fetchedObjects);

/**
 A key in the 'userInfo' dictionary of a NSManagedObjectContext.
 The corresponding value is NSNumber with a boolean value. When YES, executeRequest:withContext:error: will return immediately without triggering a network request, and then set the value of the key to NO. */
extern NSString * const AFContextShouldDisableAutomaticTriggeringNetworkRequestKey;

/**
 A key in the 'userInfo' dictionary of a NSManagedObjectContext.
 The corresponding value is a block set to execute on the successful return of an array of managed objects. */
extern NSString * const AFContextFetchCompletionBlockKey;

/**
 A key in the 'userInfo' dictionary of a NSManagedObjectContext.
 The corresponding value is a block set to execute on the successful insertion and/or updating of sets of managed objects. */
extern NSString * const AFContextSaveCompletionBlockKey;

@interface NSManagedObjectContext (AFIncrementalStore)

/**
 This method can be called instead of the typical save: method in order to save the context without implicitly asking AFIncrementalStore to enqueue network requests based on the NSSaveChangesRequest.
 @discussion There are many potential cases where a normal context save without a network request would be appropriate. For example, when terminating the app.
 */
- (void)saveWithoutTriggeringNetworkRequest:(NSError *__autoreleasing*)error;

/**
 This method can be called instead of the typical executeFetchRequest:error: method in order to fetch local objects from the store without implicitly asking AFIncrementalStore to enqueue network requests based on the NSFetchRequest.
 @discussion There are many potential cases where it may be appropriate to fetch local objects from Core Data without spawning network requests. For example, when fetching a local object that does not exist on the web service.
 @return An array of objects that meet the criteria specified by request fetched from the receiver and from the persistent stores associated with the receiver’s persistent store coordinator. If an error occurs, returns nil. If no objects match the criteria specified by request, returns an empty array.
 */
- (NSArray *)executeFetchRequestWithoutTriggeringNetworkRequest:(NSFetchRequest *)fetchRequest
													 error:(NSError *__autoreleasing*)error;
/**
 This method can be called instead of the typical save: method in order to execute code on the inserted or updated NSManagedObjects that were modeled by AFIncrementalStore following a successful network request based on the NSSaveChangesRequest.
 @discussion This may be a more appropriate callback than the provided NSNotification in a variety of cases. For example, when chaining a set of asynchronous blocks together.
 */
- (BOOL)save:(NSError *__autoreleasing*)error
  completion:(AFSaveRequestCompletionBlock)completionBlock;

/**
 This method can be called instead of the typical executeFetchRequest:error: method in order to execute code on the fetched NSManagedObjects that were modeled by AFIncrementalStore following a successful network request based on the NSFetchRequest.
 @discussion This may be a more appropriate callback than the provided NSNotification in a variety of cases. For example, when a different block of code needs to be executed on the cached Core Data objects and the most recent objects from the network. 
 @return An array of objects that meet the criteria specified by request fetched from the receiver and from the persistent stores associated with the receiver’s persistent store coordinator. If an error occurs, returns nil. If no objects match the criteria specified by request, returns an empty array.
 */
- (NSArray *)executeFetchRequest:(NSFetchRequest *)fetchRequest
					  error:(NSError *__autoreleasing*)error
				 completion:(AFFetchRequestCompletionBlock)completionBlock;

@end
