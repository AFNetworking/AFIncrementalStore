#import "NSManagedObjectContext+AFIncrementalStore.h"
#import "RASchedulingKit.h"

const void * kDispatchQueue = &kDispatchQueue;
const void * kIgnoringCount = &kIgnoringCount;

@implementation NSManagedObjectContext (AFIncrementalStore)

- (dispatch_queue_t) af_dispatchQueue {

	dispatch_queue_t queue = objc_getAssociatedObject(self, &kDispatchQueue);
	if (!queue) {
		queue = dispatch_queue_create([NSStringFromClass([self class]) UTF8String], DISPATCH_QUEUE_SERIAL);
		objc_setAssociatedObject(self, &kDispatchQueue, queue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	return queue;

}

- (BOOL) af_isDescendantOfContext:(NSManagedObjectContext *)context {

	if (self == context)
		return YES;
	
	if (!self.parentContext)
		return NO;
	
	return [self.parentContext af_isDescendantOfContext:context];

}

- (void) af_executeFetchRequest:(NSFetchRequest *)fetchRequest usingBlock:(void(^)(id results, NSError *error))block {

	NSCParameterAssert(fetchRequest);
	NSCParameterAssert(block);
	
	[self performBlock:^{
	
		NSError *error = nil;
		id results = [self executeFetchRequest:fetchRequest error:&error];
		
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
	
		case NSMainQueueConcurrencyType: {
			if ([NSThread isMainThread]) {
				block();
			} else {
				[self performBlockAndWait:block];
			}
			break;
		}
		
		case NSPrivateQueueConcurrencyType: {
			//	Fixes a locking issue regarding invoking -performBlockAndWait: simultaneously on different threads, involving NSFetchedResultsController, locking and concurrent importing.
			dispatch_sync([self af_dispatchQueue], ^{
				[self performBlockAndWait:block];
			});
			break;
		}
		
		case NSConfinementConcurrencyType: {
			dispatch_sync([self af_dispatchQueue], block);
			break;
		}
	
	}
	
}

- (NSUInteger) af_ignoringCount {

	return [objc_getAssociatedObject(self, &kIgnoringCount) unsignedIntegerValue];

}

- (void) af_setIgnoringCount:(NSUInteger)count {

	objc_setAssociatedObject(self, &kIgnoringCount, [NSNumber numberWithUnsignedInteger:count], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
}

- (void) af_incrementIgnoringCount {

	NSUInteger count = [self af_ignoringCount];
	
	[self af_setIgnoringCount:(count + 1)];

}

- (void) af_decrementIgnoringCount {

	NSUInteger count = [self af_ignoringCount];
	NSCParameterAssert(count);
	
	[self af_setIgnoringCount:(count - 1)];

}

@end
