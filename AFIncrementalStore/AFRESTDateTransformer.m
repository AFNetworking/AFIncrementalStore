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
	
		//	Can not dispatch_once
		//	This method gets called from multiple threads
		//	and the date formatter has internal state
		//	that gets mingled
		
		NSString * const dateFormatterKey = NSStringFromSelector(_cmd);
		NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
		ISO8601DateFormatter *dateFormatter = [threadDictionary objectForKey:dateFormatterKey];
		if (!dateFormatter) {
			dateFormatter = [ISO8601DateFormatter new];
			dateFormatter.includeTime = YES;
			[threadDictionary setObject:dateFormatter forKey:dateFormatterKey];
		}
		
		id transformedValue = [dateFormatter dateFromString:(NSString *)value];
		NSCParameterAssert([transformedValue isKindOfClass:[[self class] transformedValueClass]]);
		return transformedValue;
	
	}
	
	return nil;

}

@end
