#import "AFRESTClient+ValueTransforming.h"

NSString * const kTypesToValueTransformers = @"-[AFRESTClient(ValueTransforming) typesToValueTransformers]";

@implementation AFRESTClient (ValueTransforming)

+ (NSDictionary *) defaultAttributeTypesToValueTransformers {

	return @{
	
		@(NSDateAttributeType): [NSValueTransformer valueTransformerForName:@"AFRESTDateTransformer"],
		
		@(NSDecimalAttributeType): [NSValueTransformer valueTransformerForName:@"AFRESTDecimalTransformer"]
	
	};

}

- (NSMutableDictionary *) typesToValueTransformers {

	NSMutableDictionary *dictionary = objc_getAssociatedObject(self, &kTypesToValueTransformers);
	if (!dictionary) {
		dictionary = [[[self class] defaultAttributeTypesToValueTransformers] mutableCopy];
		objc_setAssociatedObject(self, &kTypesToValueTransformers, dictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	return dictionary;

}

- (NSValueTransformer *) valueTransformerForAttributeType:(NSAttributeType)type {

	return [self typesToValueTransformers][@(type)];

}

- (void) setValueTransformer:(NSValueTransformer *)transformer forAttributeType:(NSAttributeType)type {

	[self typesToValueTransformers][@(type)] = transformer;

}

- (id) valueForObject:(id)object inAttribute:(NSAttributeDescription *)attribute {

	NSAttributeType type = attribute.attributeType;
	NSValueTransformer *transformer = [self valueTransformerForAttributeType:type];
	
	if (!transformer) {
		return object;
	}

	id returnedValue = [transformer transformedValue:object];
	NSCParameterAssert([returnedValue isKindOfClass:[[transformer class] transformedValueClass]]);
	
	return returnedValue;

}

@end
