//
//  RKObjectLoaderTTModel.m
//  RestKit
//
//  Created by Blake Watters on 2/9/10.
//  Copyright 2010 Two Toasters. All rights reserved.
//

#import "RKObjectLoaderTTModel.h"
#import "RKManagedObjectStore.h"
#import "../Network/Network.h"


static NSTimeInterval defaultRefreshRate = NSTimeIntervalSince1970;
static NSString* const kDefaultLoadedTimeKey = @"RKRequestTTModelDefaultLoadedTimeKey";

@interface RKObjectLoaderTTModel (Private)

@property (nonatomic, readonly) NSString* resourcePath;

- (void)clearLoadedTime;
- (void)saveLoadedTime;
- (void)modelsDidLoad:(NSArray*)models;
- (void)load;

@end


@implementation RKObjectLoaderTTModel

@synthesize objects = _objects;
@synthesize objectLoader = _objectLoader;
@synthesize refreshRate = _refreshRate;

+ (NSDate*)defaultLoadedTime {
	NSDate* defaultLoadedTime = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultLoadedTimeKey];
	if (defaultLoadedTime == nil) {
		defaultLoadedTime = [NSDate date];
		[[NSUserDefaults standardUserDefaults] setObject:defaultLoadedTime forKey:kDefaultLoadedTimeKey];
	}

	return defaultLoadedTime;
}

+ (NSTimeInterval)defaultRefreshRate {
	return defaultRefreshRate;
}

+ (void)setDefaultRefreshRate:(NSTimeInterval)newDefaultRefreshRate {
	defaultRefreshRate = newDefaultRefreshRate;
}

+ (RKObjectLoaderTTModel*)modelWithObjectLoader:(RKObjectLoader*)objectLoader {
    return [[[self alloc] initWithObjectLoader:objectLoader] autorelease];
}

- (id)initWithObjectLoader:(RKObjectLoader*)objectLoader {
    self = [super init];
    if (self) {
        // TODO: When allowing mutation of object loader, be sure to update...
        _objectLoader = [objectLoader retain];
        _objectLoader.delegate = self;
    }
    
    return self;
}

// TODO: Does this work?
// Loads a new object loader
- (void)updateModelWithObjectLoader:(RKObjectLoader*)objectLoader {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (id)init {
    self = [super init];
	if (self) {
		self.refreshRate = [RKObjectLoaderTTModel defaultRefreshRate];
		_cacheLoaded = NO;
		_objects = nil;
		_isLoaded = NO;
		_isLoading = NO;
		_emptyReloadAttempted = NO;
	}
	return self;
}

- (void)dealloc {
	[[RKRequestQueue sharedQueue] cancelRequestsWithDelegate:self];
	[_objects release];
	_objects = nil;
    [_objectLoader release];
    _objectLoader = nil;
    
	[super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// TTModel

- (NSString*)resourcePath {
    return self.objectLoader.resourcePath;
}

- (BOOL)isLoaded {
	return _isLoaded;
}

- (BOOL)isLoading {
	return _isLoading;
}

- (BOOL)isLoadingMore {
	return NO;
}

- (BOOL)isOutdated {
	NSTimeInterval sinceNow = [self.loadedTime timeIntervalSinceNow];
	if (![self isLoading] && !_emptyReloadAttempted && _objects && [_objects count] == 0) {
		_emptyReloadAttempted = YES;
        
        // TODO: Returning YES from here causes the view to enter an infinite
        // loading state if you switch data sources
        //		return YES;
        return NO;
	}
	return (![self isLoading] && (-sinceNow > _refreshRate));
}

- (void)cancel {
	[[RKRequestQueue sharedQueue] cancelRequestsWithDelegate:self];
	[self didCancelLoad];
}

- (void)invalidate:(BOOL)erase {
	// TODO: Note sure how to handle erase...
	[self clearLoadedTime];
}

- (void)load:(TTURLRequestCachePolicy)cachePolicy more:(BOOL)more {
	[self load];
}

- (NSDate*)loadedTime {
	NSDate* loadedTime = [[NSUserDefaults standardUserDefaults] objectForKey:self.resourcePath];
	if (loadedTime == nil) {
		return [RKObjectLoaderTTModel defaultLoadedTime];
	}
	return loadedTime;
}

#pragma mark RKModelLoaderDelegate

- (void)objectLoader:(RKObjectLoader*)objectLoader didLoadObjects:(NSArray*)objects {
	_isLoading = NO;
	[self saveLoadedTime];
	[self modelsDidLoad:objects];
}

- (void)objectLoader:(RKObjectLoader*)objectLoader didFailWithError:(NSError*)error {
	_isLoading = NO;
	[self didFailLoadWithError:error];
}

- (void)objectLoaderDidLoadUnexpectedResponse:(RKObjectLoader*)objectLoader {
	_isLoading = NO;

	// TODO: Passing a nil error here does nothing for Three20.  Need to construct our
	// own error here to make Three20 happy??
	[self didFailLoadWithError:nil];
}

#pragma mark RKRequestTTModel (Private)

// TODO: Can we push this load time into RKRequestCache???
- (void)clearLoadedTime {
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:self.resourcePath];
}

- (void)saveLoadedTime {
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:self.resourcePath];
}

- (void)modelsDidLoad:(NSArray*)models {
	[models retain];
	[_objects release];
	_objects = nil;

	_objects = models;
	_isLoaded = YES;

	[self didFinishLoad];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// public

- (void)load {
	RKManagedObjectStore* store = [RKObjectManager sharedManager].objectStore;
	NSArray* cacheFetchRequests = nil;
	if (store.managedObjectCache) {
		cacheFetchRequests = [store.managedObjectCache fetchRequestsForResourcePath:self.resourcePath];
	}

	if (!store.managedObjectCache || !cacheFetchRequests || _cacheLoaded) {
		_isLoading = YES;
		[self didStartLoad];
		[self.objectLoader send];
	} else if (cacheFetchRequests && !_cacheLoaded) {
		_cacheLoaded = YES;
		[self modelsDidLoad:[RKManagedObject objectsWithFetchRequests:cacheFetchRequests]];
	}
}

@end