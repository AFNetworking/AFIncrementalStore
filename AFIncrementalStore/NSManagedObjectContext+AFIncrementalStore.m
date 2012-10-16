//
//  NSManagedObjectContext+AFIncrementalStore.m
//  Sharely
//
//  Created by Adam Price on 10/16/12.
//  Copyright (c) 2012 Fuzz Productions. All rights reserved.
//

#import "NSManagedObjectContext+AFIncrementalStore.h"

NSString * const AFContextShouldDisableAutomaticTriggeringNetworkRequestKey = @"AFContextShouldDisableAutomaticTriggeringNetworkRequestKey";
NSString * const AFContextFetchCompletionBlockKey = @"AFContextFetchCompletionBlockKey";
NSString * const AFContextSaveCompletionBlockKey = @"AFContextFetchCompletionBlockKey";

@implementation NSManagedObjectContext (AFIncrementalStore)

- (void)saveWithoutTriggeringNetworkRequest:(NSError *__autoreleasing*)error
{
	[self.userInfo setValue:@(YES) forKey:AFContextShouldDisableAutomaticTriggeringNetworkRequestKey];
	
	[self save:error];
}

- (NSArray *)executeFetchRequestWithoutTriggeringNetworkRequest:(NSFetchRequest *)fetchRequest
														  error:(NSError *__autoreleasing*)error
{
	[self.userInfo setValue:@(YES) forKey:AFContextShouldDisableAutomaticTriggeringNetworkRequestKey];
	
	return [self executeFetchRequest:fetchRequest error:error];
}

- (BOOL)save:(NSError *__autoreleasing*)error
  completion:(AFSaveRequestCompletionBlock)completionBlock
{
	[self.userInfo setValue:completionBlock forKey:AFContextSaveCompletionBlockKey];
	
	return [self save:error];
}

- (NSArray *)executeFetchRequest:(NSFetchRequest *)fetchRequest
					  error:(NSError *__autoreleasing*)error
				 completion:(AFFetchRequestCompletionBlock)completionBlock
{
	[self.userInfo setValue:completionBlock forKey:AFContextSaveCompletionBlockKey];
	
	return [self executeFetchRequest:fetchRequest error:error];
}

@end
