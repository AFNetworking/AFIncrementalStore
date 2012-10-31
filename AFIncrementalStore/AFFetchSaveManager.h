//
//  AFFetchSaveManager.h
//  Sharely
//
//  Created by Adam Price on 10/26/12.
//  Copyright (c) 2012 Fuzz Productions. All rights reserved.
//

@class AFHTTPRequestOperation;

typedef void (^AFIncrementalStoreFetchCompletionBlock)(NSFetchRequest *fetchRequest, AFHTTPRequestOperation *operation, NSArray *fetchedObjects);
typedef void (^AFIncrementalStoreSaveCompletionBlock)(NSSaveChangesRequest *saveChangesRequest, AFHTTPRequestOperation *operation, NSArray *insertedObjects, NSArray *updatedObjects, NSArray *deletedObjectIDs);

@interface AFFetchSaveManager : NSObject

/**
 `AFFetchSaveManager` is a class designed to manage executing NSFetchRequests with completion blocks and NSManagedObjectContext saves with completion blocks. There is no need to create an instance of this class; the class itself is the observer for notifications and the only public methods are class methods.
 
 ## Description
 
 There are only two class methods with which to interface with AFFetchSaveManager. An exception will be raised if you call these methods without a context.
 
 The completion and failure blocks will be associated with the corresponding NSFetchRequest or NSSaveChangesRequest that are executed by AFIncrementalStore. 
 AFFetchSaveManager acts as a global observer of AFIncrementalStore's NSNotifications, and will execute the appropriate completion block when it gets the corresponding 
 didFetchRemoteValues: or didSaveRemoteValues: notification.
 */

+ (BOOL)saveContext:(NSManagedObjectContext *)context
			  error:(NSError *__autoreleasing*)error
		 completion:(AFIncrementalStoreSaveCompletionBlock)completionBlock;

+ (NSArray *)executeFetchRequest:(NSFetchRequest *)fetchRequest
						 context:(NSManagedObjectContext *)context
						   error:(NSError *__autoreleasing*)error
					  completion:(AFIncrementalStoreFetchCompletionBlock)completionBlock;

///-----------------------------------------
/// @name ManagedObjectContext userInfo keys
///-----------------------------------------

/**
 A key in the `userInfo` dictionary of a NSManagedObjectContext, set by AFFetchSaveManager.
 The corresponding value is a unique `requestIdentifier` key that is generated in each of AFFetchSaveManager's class methods and used as a key for the pending completion block
 of that NSPersistentStoreRequest. This key is immediately removed from the `userInfo` dictionary and attached to the appropriate NSFetchRequest or NSSaveChangesRequest in the
 executeRequest:withContext:error method of AFIncrementalStore.
 */
extern NSString * const AFFetchSaveManagerPersistentStoreRequestIdentifierKey;

@end
