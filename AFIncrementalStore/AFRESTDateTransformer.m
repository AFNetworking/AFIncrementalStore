#import "AFRESTDateTransformer.h"
#import "ISO8601DateFormatter.h"

@implementation AFRESTDateTransformer

+ (void) load {

	[self setValueTransformer:[self new] forName:NSStringFromClass(self)];

}

+ (Class) transformedValueClass {

	return [NSDate class];

}

- (id) transformedValue:(id)value {

	if ([value isKindOfClass:[NSDate class]]) {
	
		return value;
	
	} else if ([value isKindOfClass:[NSString class]]) {
	
		static dispatch_once_t onceToken;
		static ISO8601DateFormatter *dateFormatter;
		dispatch_once(&onceToken, ^{
			dateFormatter = [ISO8601DateFormatter new];
		});
		
		return [dateFormatter dateFromString:(NSString *)value];
	
	}
	
	return nil;

}

@end
