#import <CoreData/CoreData.h>

@interface NSManagedObject (AFIncrementalStore)

@property (readwrite, nonatomic, copy, setter = af_setResourceIdentifier:) NSString *af_resourceIdentifier;

@end
