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

// Instantiate current class dynamically
+ (BluetoothManager *) bluetoothManagerSharedInstance {
    Class bm = NSClassFromString(@"BluetoothManager");
    return (BluetoothManager *)[bm sharedInstance];
}

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

- (instancetype)init
{
    if (self = [super init]) {
        _privateBluetoothManager = [BluetoothHarwareControlManager bluetoothManagerSharedInstance];
    }

    return self;
}

#pragma mark - class methods

- (BOOL)bluetoothIsPowered
{
    return [[BluetoothHarwareControlManager bluetoothManagerSharedInstance] powered];
}

- (void)turnBluetoothOn
{
    if (![self bluetoothIsPowered]) {
        [[BluetoothHarwareControlManager bluetoothManagerSharedInstance] setPowered:YES];
    }
}

- (void)turnBluetoothOff
{
    if ([self bluetoothIsPowered]) {
        [[BluetoothHarwareControlManager bluetoothManagerSharedInstance] setPowered:NO];
    }
}

@end
