//
//  BluetoothHarwareControlManager.m
//  ThaliCore
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license. See LICENSE.txt file in the project root for full license information.
//

#import "BluetoothHarwareControlManager.h"
#import "BluetoothManager.h"
#import <dlfcn.h>

static void *frameworkHandle;

@interface BluetoothHarwareControlManager ()

@property (retain, nonatomic) BluetoothManager *privateBluetoothManager;

- (instancetype)init;

@end

@implementation BluetoothHarwareControlManager

+ (BluetoothHarwareControlManager *)sharedInstance
{
    static BluetoothHarwareControlManager *bluetoothManager = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        frameworkHandle = dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
        if (frameworkHandle) {
            bluetoothManager = [[BluetoothHarwareControlManager alloc] init];
        }
    });

    return bluetoothManager;
}

// Instantiate current class dynamically
+ (BluetoothManager *) bluetoothManagerSharedInstance {
    Class bm = NSClassFromString(@"BluetoothManager");
    return (BluetoothManager *)[bm sharedInstance];
}

- (instancetype)init
{
    if (self = [super init]) {
        _privateBluetoothManager = [BluetoothHarwareControlManager bluetoothManagerSharedInstance];
    }

    return self;
}


@end
