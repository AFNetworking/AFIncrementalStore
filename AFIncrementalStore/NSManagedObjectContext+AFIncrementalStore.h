#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (AFIncrementalStore)

- (BOOL) af_isDescendantOfContext:(NSManagedObjectContext *)context;

- (void) af_executeFetchRequest:(NSFetchRequest *)fetchRequest usingBlock:(void(^)(NSArray *results, NSError *error))block;

- (void) af_performBlock:(void(^)())block;

- (void) af_performBlockAndWait:(void(^)())block;

@end
