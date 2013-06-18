# AFIncrementalStore
**Core Data Persistence with AFNetworking, Done Right**

AFIncrementalStore is an [`NSIncrementalStore`](http://nshipster.com/nsincrementalstore/) subclass that uses [AFNetworking](https://github.com/afnetworking/afnetworking) to automatically request resources as properties and relationships are needed. 

Weighing in at just a few hundred LOC, in a single `{.h,.m}` file pair, AFIncrementalStore is something you can get your head around. Integrating it into your project couldn't be easier--just swap out your `NSPersistentStore` for it. No monkey-patching, no extra properties on your models.

## Incremental Store Persistence

`AFIncrementalStore` does not persist data directly. Instead, _it manages a persistent store coordinator_ that can be configured to communicate with any number of persistent stores of your choice.

In the Twitter example, a SQLite persistent store is added, which works to persist tweets between launches, and return locally-cached results while the network request finishes:

``` objective-c
NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Twitter.sqlite"];
NSDictionary *options = @{ NSInferMappingModelAutomaticallyOption : @(YES) };

NSError *error = nil;
if (![incrementalStore.backingPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
}
```

If your data set is of a more fixed or ephemeral nature, you may want to use `NSInMemoryStoreType`.

## Mapping Core Data to HTTP

The only thing you need to do is tell `AFIncrementalStore` how to map Core Data to an HTTP client. These methods are defined in the `AFIncrementalStoreHTTPClient` protocol:

> Don't worry if this looks like a lot of work--if your web service is RESTful, `AFRESTClient` does a lot of the heavy lifting for you. If your target web service is SOAP, RPC, or kinda ad-hoc, you can easily use these protocol methods to get everything hooked up.

```objective-c

- (NSDictionary *)representationsForRelationshipsFromRepresentation:(NSDictionary *)representation
                                                           ofEntity:(NSEntityDescription *)entity
                                                       fromResponse:(NSHTTPURLResponse *)response;

- (NSString *)resourceIdentifierForRepresentation:(NSDictionary *)representation
                                         ofEntity:(NSEntityDescription *)entity;

- (NSDictionary *)attributesForRepresentation:(NSDictionary *)representation
                                         ofEntity:(NSEntityDescription *)entity
                                     fromResponse:(NSHTTPURLResponse *)response;

- (NSURLRequest *)requestForFetchRequest:(NSFetchRequest *)fetchRequest
                             withContext:(NSManagedObjectContext *)context;

- (NSURLRequest *)requestWithMethod:(NSString *)method
                pathForObjectWithID:(NSManagedObjectID *)objectID
                        withContext:(NSManagedObjectContext *)context;

- (NSURLRequest *)requestWithMethod:(NSString *)method
                pathForRelationship:(NSRelationshipDescription *)relationship
                    forObjectWithID:(NSManagedObjectID *)objectID
                        withContext:(NSManagedObjectContext *)context;
```

## Getting Started

Check out the example projects that are included in the repository. They are somewhat simple demonstration of an app that uses Core Data with `AFIncrementalStore` to communicate with an API for faulted properties and relationships. Note that there are no explicit network requests being made in the app--it's all done automatically by Core Data.

Also, don't forget to pull down AFNetworking with `git submodule update --init` if you want to run the example. 

## Requirements

AFIncrementalStore requires Xcode 4.4 with either the [iOS 5.0](http://developer.apple.com/library/ios/#releasenotes/General/WhatsNewIniPhoneOS/Articles/iOS5.html) or [Mac OS 10.6](http://developer.apple.com/library/mac/#releasenotes/MacOSX/WhatsNewInOSX/Articles/MacOSX10_6.html#//apple_ref/doc/uid/TP40008898-SW7) ([64-bit with modern Cocoa runtime](https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtVersionsPlatforms.html)) SDK, as well as [AFNetworking](https://github.com/afnetworking/afnetworking) 0.9 or higher.

## Installation

[CocoaPods](http://cocoapods.org) is the recommended way to add AFIncrementalStore to your project.

Here's an example podfile that installs AFIncrementalStore and its dependency, AFNetworking. 
### Podfile

```ruby
platform :ios, '5.0'

pod 'AFIncrementalStore'
```

Note the specification of iOS 5.0 as the platform; leaving out the 5.0 will cause CocoaPods to fail with the following message:

> [!] AFIncrementalStore is not compatible with iOS 4.3.

## Credits

AFIncrementalStore was created by [Mattt Thompson](https://github.com/mattt/).

## Contact

Follow AFNetworking on Twitter ([@AFNetworking](https://twitter.com/AFNetworking))

### Creators

[Mattt Thompson](http://github.com/mattt)  
[@mattt](https://twitter.com/mattt)

## License

AFIncrementalStore and AFNetworking are available under the MIT license. See the LICENSE file for more info.
