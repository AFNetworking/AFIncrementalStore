#import "NSManagedObject+AFIncrementalStore.h"
#import "AFIncrementalStore.h"

static char kAFResourceIdentifierObjectKey;

@implementation NSManagedObject (AFIncrementalStore)
@dynamic af_resourceIdentifier;

- (NSString *) af_resourceIdentifier {

    NSString *identifier = (NSString *)objc_getAssociatedObject(self, &kAFResourceIdentifierObjectKey);
    
    if (!identifier) {
        if ([self.objectID.persistentStore isKindOfClass:[AFIncrementalStore class]]) {
            id referenceObject = [(AFIncrementalStore *)self.objectID.persistentStore referenceObjectForObjectID:self.objectID];
            if ([referenceObject isKindOfClass:[NSString class]]) {
                return referenceObject;
            }
        }
    }
    
    return identifier;
    
}

- (void) af_setResourceIdentifier:(NSString *)resourceIdentifier {
  
		objc_setAssociatedObject(self, &kAFResourceIdentifierObjectKey, resourceIdentifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
		
}

@end
