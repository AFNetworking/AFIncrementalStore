//
//  Tweet.h
//  Incremental Twitter Example
//
//  Created by Mattt Thompson on 2012/08/13.
//
//

#import <CoreData/CoreData.h>

@class User;

@interface Tweet : NSManagedObject

@property NSNumber *tweetID;
@property NSString *text;
@property NSDate *createdAt;

@property User *user;

@end
