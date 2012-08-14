//
//  User.h
//  Incremental Twitter Example
//
//  Created by Mattt Thompson on 2012/08/13.
//
//

#import <CoreData/CoreData.h>

@interface User : NSManagedObject

@property NSNumber *userID;
@property NSString *username;
@property NSString *profileImageURLString;

@property NSSet *tweets;

@end
