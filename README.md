# AFIncrementalStore
**Core Data Persistence with AFNetworking, Done Right**

> _This is still in early stages of development, so proceed with caution when using this in a production application.  
> Any bug reports, feature requests, or general feedback at this point would be greatly appreciated._

**A lot of us have been burned by Core Data + REST frameworks in the past.**  
**I can promise you that this is unlike anything you've seen before.**

AFIncrementalStore is an [`NSIncrementalStore`](http://nshipster.com/nsincrementalstore/) subclass that uses [AFNetworking](https://github.com/afnetworking/afnetworking) to automatically request resources as properties and relationships are needed. 

Weighing in at just under 500 LOC, AFIncrementalStore is something you can get your head around. Integrating it into your project couldn't be easier--just swap out your `NSPersistentStore` for it. No monkey-patching, no extra properties on your models.

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
- (id)representationOrArrayOfRepresentationsFromResponseObject:(id)responseObject;

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

Also, don't forget to pull down AFNetworking with `git submodule init && git submodule update` if you want to run the example. 

## Requirements

AFIncrementalStore requires Xcode 4.4 with either the [iOS 5.0](http://developer.apple.com/library/ios/#releasenotes/General/WhatsNewIniPhoneOS/Articles/iOS5.html) or [Mac OS 10.6](http://developer.apple.com/library/mac/#releasenotes/MacOSX/WhatsNewInOSX/Articles/MacOSX10_6.html#//apple_ref/doc/uid/TP40008898-SW7) ([64-bit with modern Cocoa runtime](https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtVersionsPlatforms.html)) SDK, as well as [AFNetworking](https://github.com/afnetworking/afnetworking) 0.9 or higher.

## Next Steps

This project is just getting started. Next up for `AFIncrementalStore` are the following:

- Full Documentation
- Additional example projects
- POST to server when creating new managed objects
- Automatic `If-Modified-Since` & `If-Match` headers based on last request of resources.
- Default transformations for fetch request offset / limit to pagination parameters
- Examples of other API adapters (e.g. RPC, SOAP, ad-hoc)

## Credits

AFIncrementalStore was created by [Mattt Thompson](https://github.com/mattt/).

## Contact

Follow AFNetworking on Twitter ([@AFNetworking](https://twitter.com/AFNetworking))

### Creators

[Mattt Thompson](http://github.com/mattt)  
[@mattt](https://twitter.com/mattt)

## License

AFNetworking is available under the MIT license. See the LICENSE file for more info.
