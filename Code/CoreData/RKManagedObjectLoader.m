//
//  RKManagedObjectLoader.m
//  RestKit
//
//  Created by Blake Watters on 2/13/11.
//  Copyright 2011 Two Toasters. All rights reserved.
//

#import "RKManagedObjectLoader.h"
#import "RKURL.h"
#import "RKManagedObject.h"
#import "RKObjectMapper.h"
#import "RKManagedObjectFactory.h"
#import "RKManagedObjectThreadSafeInvocation.h"
#import "../ObjectMapping/RKObjectLoader_Internals.h"

@implementation RKManagedObjectLoader

- (id)init {
    self = [super init];
    if (self) {
        _managedObjectKeyPaths = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_targetObjectID release];
    _targetObjectID = nil;
    [_managedObjectKeyPaths release];
    
    [super dealloc];
}

- (RKManagedObjectStore*)objectStore {
    return self.objectManager.objectStore;
}

#pragma mark - RKObjectMapperDelegate methods

- (void)objectMapper:(RKObjectMapper*)objectMapper didMapFromObject:(id)sourceObject toObject:(id)destinationObject atKeyPath:(NSString*)keyPath usingMapping:(RKObjectMapping*)objectMapping {
    if ([destinationObject isKindOfClass:[NSManagedObject class]]) {
        // TODO: logging here
        // TODO: Unit test with a collection
        [_managedObjectKeyPaths addObject:keyPath];
    }
}

#pragma mark - RKObjectLoader overrides

- (void)performMappingOnBackgroundThread {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    // Refetch the target object now that we are on the background thread
    if (_targetObjectID) {
        self.targetObject = [self.objectStore objectWithID:_targetObjectID];
    }
    
    // Let RKObjectLoader handle the processing...
    [super performMappingOnBackgroundThread];    
    [pool drain];
}

- (void)setTargetObject:(NSObject*)targetObject {
    [_targetObject release];
    _targetObject = nil;	
    _targetObject = [targetObject retain];	

    [_targetObjectID release];
    _targetObjectID = nil;
    
    // Obtain a permanent ID for the object
    // NOTE: There is an important sequencing issue here. You MUST save the
    // managed object context before retaining the objectID or you will run
    // into an error where the object context cannot be saved. We do this
    // right before send to avoid sequencing issues where the target object is
    // set before the managed object store.
    // TODO: Can we just obtain a permanent object ID instead of saving the store???
    if ([targetObject isKindOfClass:[NSManagedObject class]]) {
        NSManagedObjectContext* context = self.objectStore.managedObjectContext;
        NSError* error = nil;
        if ([context obtainPermanentIDsForObjects:[NSArray arrayWithObject:targetObject] error:&error]) {
            _targetObjectID = [[(NSManagedObject*)targetObject objectID] retain];
        }
    }
}

- (void)processMappingResult:(RKObjectMappingResult*)result {
    if (_targetObjectID && self.targetObject && self.method == RKRequestMethodDELETE) {
        // TODO: Logging
        NSManagedObject* backgroundThreadObject = [self.objectStore objectWithID:_targetObjectID];
        [[self.objectStore managedObjectContext] deleteObject:backgroundThreadObject];
    }
    
    // If the response was successful, save the store...
    if ([self.response isSuccessful]) {
        // TODO: Logging or delegate notifications?
        [self.objectStore save];
    }
    
    NSDictionary* dictionary = [result asDictionary];
    NSMethodSignature* signature = [self methodSignatureForSelector:@selector(informDelegateOfObjectLoadWithResultDictionary:)];
    RKManagedObjectThreadSafeInvocation* invocation = [RKManagedObjectThreadSafeInvocation invocationWithMethodSignature:signature];
    [invocation setObjectStore:self.objectStore];
    [invocation setTarget:self];
    [invocation setSelector:@selector(informDelegateOfObjectLoadWithResultDictionary:)];
    [invocation setArgument:&dictionary atIndex:2];
    [invocation setManagedObjectKeyPaths:_managedObjectKeyPaths forArgument:2];
    [invocation invokeOnMainThread];
}

- (id<RKObjectFactory>)createObjectFactory {
    if (self.objectManager.objectStore) {
        return [RKManagedObjectFactory objectFactoryWithObjectStore:self.objectStore];
    }
    
    return nil;    
}

@end
