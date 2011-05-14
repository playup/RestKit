//
//  RKManagedObjectLoaderSpec.m
//  RestKit
//
//  Created by Blake Watters on 4/28/11.
//  Copyright 2011 Two Toasters. All rights reserved.
//

#import "RKSpecEnvironment.h"
#import "RKManagedObjectLoader.h"
#import "RKHuman.h"

@interface RKManagedObjectLoaderSpec : RKSpec {
    
}

@end

@implementation RKManagedObjectLoaderSpec
//manager.objectStore = [RKManagedObjectStore
//                       objectStoreWithStoreFilename:@"SaferTaxi.sqlite"
//                       
//                       usingSeedDatabaseName:nil
//                       
//                       managedObjectModel:nil];
//
//RKObjectMapper* mapper =  manager.mapper;
//[mapper registerClass:[STUser class] forElementNamed:@"data.STUser"];
//
//and then on my controller:
//
//RKObjectManager* objectManager = [RKObjectManager sharedManager];
//[[objectManager loadObjectsAtResourcePath:@"/users/login.json"
//                              objectClass:[STUser class] delegate:self] retain];

- (void)itShouldDeleteObjectFromLocalStoreOnDELETE {    
    RKManagedObjectStore* store = RKSpecNewManagedObjectStore();
    RKObjectManager* objectManager = RKSpecNewObjectManager();
    RKSpecStubNetworkAvailability(YES);
    RKSpecNewRequestQueue();
    objectManager.objectStore = store;
    RKHuman* human = [RKHuman object];
    human.name = @"Blake Watters";
    human.railsID = [NSNumber numberWithInt:1];
    [objectManager.objectStore save];
    
    RKObjectMapping* mapping = [RKObjectMapping mappingForClass:[RKHuman class]];
    RKSpecResponseLoader* responseLoader = [RKSpecResponseLoader responseLoader];
    RKManagedObjectLoader* objectLoader = [RKManagedObjectLoader loaderWithResourcePath:@"/humans/1" objectManager:objectManager delegate:responseLoader];
    objectLoader.method = RKRequestMethodDELETE;
    objectLoader.objectMapping = mapping;
    objectLoader.targetObject = human;
    [objectLoader send];
    [responseLoader waitForResponse];
    assertThatBool([human isDeleted], equalToBool(YES));
}

@end
