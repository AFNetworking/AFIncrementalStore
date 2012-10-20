#import <objc/runtime.h>
#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (AFIncrementalStore)

- (BOOL) af_isDescendantOfContext:(NSManagedObjectContext *)context;

- (void) af_executeFetchRequest:(NSFetchRequest *)fetchRequest usingBlock:(void(^)(NSArray *results, NSError *error))block;

- (void) af_performBlock:(void(^)())block;
- (void) af_performBlockAndWait:(void(^)())block;

- (NSUInteger) af_ignoringCount;
- (void) af_incrementIgnoringCount;
- (void) af_decrementIgnoringCount;

@end
