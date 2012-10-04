//
//  CheckIn.m
//  Read-Write Example
//
//  Created by Mattt Thompson on 2012/10/04.
//  Copyright (c) 2012年 AFNetworking. All rights reserved.
//

#import "CheckIn.h"

@implementation CheckIn

@dynamic latitude;
@dynamic longitude;
@dynamic timestamp;

- (id)initWithTimestamp:(NSDate *)timestamp inManagedObjectContext:(NSManagedObjectContext *)context{
    self = [self initWithEntity:[NSEntityDescription entityForName:@"CheckIn" inManagedObjectContext:context] insertIntoManagedObjectContext:nil];
    if (!self) {
        return nil;
    }
    
    self.latitude = @(42.0);
    self.longitude = @(69.0);
    self.timestamp = timestamp;
    
    return self;
}

@end
