//
//  BluetoothHarwareControlManager.h
//  ThaliCore
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license. See LICENSE.txt file in the project root for full license information.
//

#ifndef BluetoothHarwareControlManager_h
#define BluetoothHarwareControlManager_h

#import <Foundation/Foundation.h>

@interface BluetoothHarwareControlManager : NSObject

+ (BluetoothHarwareControlManager *)sharedInstance;

- (BOOL)bluetoothIsPowered;
- (void)turnBluetoothOn;
- (void)turnBluetoothOff;

@end

#endif /* BluetoothHarwareControlManager_h */
