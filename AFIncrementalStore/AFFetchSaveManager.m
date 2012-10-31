//
//  AFFetchSaveManager.m
//  Sharely
//
//  Created by Adam Price on 10/26/12.
//  Copyright (c) 2012 Fuzz Productions. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "AFFetchSaveManager.h"
#import "AFIncrementalStore.h"

NSString * const AFFetchSaveManagerPersistentStoreRequestIdentifierKey = @"AFFetchSaveManagerPersistentStoreRequestIdentifierKey";

static NSMutableDictionary *_fetchRequestBlockDictionary = nil;
static NSMutableDictionary *_saveRequestBlockDictionary = nil;

@implementation AFFetchSaveManager

+ (void)setupObserver
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken,^
	{
		[[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector(willFetchRemoteValues:) name:AFIncrementalStoreContextWillFetchRemoteValues object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector(didFetchRemoteValues:) name:AFIncrementalStoreContextDidFetchRemoteValues object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector(willSaveRemoteValues:) name:AFIncrementalStoreContextWillSaveRemoteValues object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector(didSaveRemoteValues:) name:AFIncrementalStoreContextDidSaveRemoteValues object:nil];
	});
}

#pragma mark -
#pragma mark NSManagedObjectContext public class methods

+ (NSArray *)executeFetchRequest:(NSFetchRequest *)fetchRequest
					context:(NSManagedObjectContext *)context
					  error:(NSError *__autoreleasing*)error
				 completion:(AFIncrementalStoreFetchCompletionBlock)completionBlock
{
	NSParameterAssert(context);
	
	[[self class] setupObserver];
	
	if (completionBlock) {
		NSString *requestIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
		
		[context.userInfo setObject:requestIdentifier forKey:AFFetchSaveManagerPersistentStoreRequestIdentifierKey];

		[[[self class] fetchRequestBlockDictionary] setObject:completionBlock forKey:requestIdentifier];
	}
	
	return [context executeFetchRequest:fetchRequest error:error];
}

+ (BOOL)saveContext:(NSManagedObjectContext *)context
			  error:(NSError *__autoreleasing*)error
		 completion:(AFIncrementalStoreSaveCompletionBlock)completionBlock
{
	NSParameterAssert(context);
	
	[[self class] setupObserver];
	
	if (completionBlock) {
		NSString *requestIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
		
		[context.userInfo setObject:requestIdentifier forKey:AFFetchSaveManagerPersistentStoreRequestIdentifierKey];
		
		[[[self class] saveRequestBlockDictionary] setObject:completionBlock forKey:requestIdentifier];
	}
	
	return [context save:error];
}

#pragma mark -
#pragma mark Private Getter Methods

+ (NSMutableDictionary *)fetchRequestBlockDictionary
{
	if (!_fetchRequestBlockDictionary)
		_fetchRequestBlockDictionary = [[NSMutableDictionary alloc] init];
	return _fetchRequestBlockDictionary;
}

+ (NSMutableDictionary *)saveRequestBlockDictionary
{
	if (!_saveRequestBlockDictionary)
		_saveRequestBlockDictionary = [[NSMutableDictionary alloc] init];
	return _saveRequestBlockDictionary;
}

#pragma mark -
#pragma mark NSNotifications

+ (void)willFetchRemoteValues:(NSNotification *)inNotification
{
	
}

+ (void)didFetchRemoteValues:(NSNotification *)inNotification
{
	[[self class] executeCompletionBlockWithNotification:inNotification];
}

+ (void)willSaveRemoteValues:(NSNotification *)inNotification
{

}

+ (void)didSaveRemoteValues:(NSNotification *)inNotification
{
	[[self class] executeCompletionBlockWithNotification:inNotification];
}

#pragma mark -
#pragma mark Private block handler functions

+ (void)executeCompletionBlockWithNotification:(NSNotification *)inNotification
{
	BOOL couldNotFindValidCompletionBlock = NO;
	
	NSPersistentStoreRequest *tmpPersistentStoreRequest = [inNotification.userInfo objectForKey:AFIncrementalStorePersistentStoreRequestKey];
	AFHTTPRequestOperation *tmpOperation = [inNotification.userInfo objectForKey:AFIncrementalStoreRequestOperationKey];
	if (tmpPersistentStoreRequest && tmpOperation)
	{
		NSString *requestIdentifier = [tmpPersistentStoreRequest af_requestIdentifier];
		if (!requestIdentifier || requestIdentifier.length == 0)
			return;
		
		if (tmpPersistentStoreRequest.requestType == NSFetchRequestType)
		{
			AFIncrementalStoreFetchCompletionBlock tmpFetchCompletionBlock = [[[self class] fetchRequestBlockDictionary] objectForKey:requestIdentifier];
			if (!tmpFetchCompletionBlock)
				couldNotFindValidCompletionBlock = YES;
			else
			{
				NSArray *tmpFetchedObjects = [inNotification.userInfo objectForKey:AFIncrementalStoreFetchedObjectsKey];
				if (tmpFetchCompletionBlock)
					tmpFetchCompletionBlock((NSFetchRequest *)tmpPersistentStoreRequest, tmpOperation, tmpFetchedObjects);
			}
		}
		else
		{
			AFIncrementalStoreSaveCompletionBlock tmpSaveCompletionBlock = [[[self class] saveRequestBlockDictionary] objectForKey:requestIdentifier];
			if (!tmpSaveCompletionBlock)
				couldNotFindValidCompletionBlock = YES;
			else
			{
				NSArray *tmpInsertedObjects =  [inNotification.userInfo objectForKey:AFIncrementalStoreInsertedObjectsKey];
				NSArray *tmpUpdatedObjects = [inNotification.userInfo objectForKey:AFIncrementalStoreUpdatedObjectsKey];
				NSArray *tmpDeletedObjects = [inNotification.userInfo objectForKey:AFIncrementalStoreDeletedObjectIDsKey];
				if (tmpSaveCompletionBlock)
					tmpSaveCompletionBlock((NSSaveChangesRequest *)tmpPersistentStoreRequest, tmpOperation, tmpInsertedObjects, tmpUpdatedObjects, tmpDeletedObjects);
			}
		}
	}
	else
		couldNotFindValidCompletionBlock = YES;
	
	if (couldNotFindValidCompletionBlock)
		NSLog(@"Could Not Find Valid Completion Block");
}

@end
