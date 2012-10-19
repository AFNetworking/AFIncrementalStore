#import "NSManagedObjectContext+AFIncrementalStore.h"

@implementation NSManagedObjectContext (AFIncrementalStore)

- (BOOL) af_isDescendantOfContext:(NSManagedObjectContext *)context {

	if (self == context)
		return YES;
	
	if (!self.parentContext)
		return NO;
	
	return [self.parentContext af_isDescendantOfContext:context];

}

- (void) af_executeFetchRequest:(NSFetchRequest *)fetchRequest usingBlock:(void(^)(NSArray *results, NSError *error))block {

	NSCParameterAssert(fetchRequest);
	NSCParameterAssert(block);
	
	[self performBlock:^{
	
		NSError *error = nil;
		NSArray *results = [self executeFetchRequest:fetchRequest error:&error];
		
		if (block)
			block(results, error);
		
	}];

}

- (void) af_performBlock:(void(^)())block {

	switch (self.concurrencyType) {
	
		case NSMainQueueConcurrencyType:
		case NSPrivateQueueConcurrencyType: {
			[self performBlock:block];
			break;
		}
		
		case NSConfinementConcurrencyType: {
			block();
			break;
		}
	
	}
	
}

- (void) af_performBlockAndWait:(void(^)())block {

	switch (self.concurrencyType) {
	
		case NSMainQueueConcurrencyType:
		case NSPrivateQueueConcurrencyType: {
			[self performBlockAndWait:block];
			break;
		}
		
		case NSConfinementConcurrencyType: {
			block();
			break;
		}
	
	}

}

@end
