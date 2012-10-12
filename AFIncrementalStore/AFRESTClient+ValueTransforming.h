#import <objc/runtime.h>
#import "AFRESTClient.h"

@interface AFRESTClient (ValueTransforming)

+ (NSDictionary *) defaultAttributeTypesToValueTransformers;

- (NSValueTransformer *) valueTransformerForAttributeType:(NSAttributeType)type;
- (void) setValueTransformer:(NSValueTransformer *)transformer forAttributeType:(NSAttributeType)type;

- (id) valueForObject:(id)object inAttribute:(NSAttributeDescription *)attribute;

@end
