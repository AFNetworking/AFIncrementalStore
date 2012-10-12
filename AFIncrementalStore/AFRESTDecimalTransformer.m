#import "AFRESTDecimalTransformer.h"

@implementation AFRESTDecimalTransformer

+ (void) load {

	[self setValueTransformer:[self new] forName:NSStringFromClass(self)];

}

+ (Class) transformedValueClass {

	return [NSDecimalNumber class];

}

- (id) transformedValue:(id)value {

	if ([value isKindOfClass:[NSNumber class]]) {
	
		//	https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/Foundation/Classes/NSDecimalNumber_Class/Reference/Reference.html
	
		const char * valueType = [value objCType];
		if (!strcmp(valueType, "d"))
			return value;
			
		return [NSDecimalNumber decimalNumberWithDecimal:[value decimalValue]];
	
	} else if ([value isKindOfClass:[NSString class]]) {
	
		return [NSDecimalNumber decimalNumberWithString:(NSString *)value];
	
	}
	
	return nil;

}

@end
