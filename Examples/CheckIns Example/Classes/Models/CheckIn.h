//
//  CheckIn.h
//  Read-Write Example
//
//  Created by Mattt Thompson on 2012/10/04.
//  Copyright (c) 2012年 AFNetworking. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface CheckIn : NSManagedObject

@property NSNumber *latitude;
@property NSNumber *longitude;
@property NSDate *timestamp;

- (id)initWithTimestamp:(NSDate *)timestamp inManagedObjectContext:(NSManagedObjectContext *)context;

@end
