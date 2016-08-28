//
//  Thali CordovaPlugin
//  AppContextTests.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license. See LICENSE.txt file in the project root for full license information.
//

import XCTest

class AppContextTests: XCTestCase {
    var expectation: XCTestExpectation?

    func testUpdateNetworkStatus() {

        class AppContextDelegateMock: NSObject, AppContextDelegate {
            var networkStatus: [String : AnyObject]?
            var networkStatusUpdated = false
            @objc func context(context: AppContext, didChangePeerAvailability peers: Array<[String : AnyObject]>) {}
            @objc func context(context: AppContext, didChangeNetworkStatus status: [String : AnyObject]) {
                networkStatusUpdated = true
                networkStatus = status
            }
            @objc func context(context: AppContext, didUpdateDiscoveryAdvertisingState discoveryAdvertisingState: [String : AnyObject]) {}
            @objc func context(context: AppContext, didFailIncomingConnectionToPort port: UInt16) {}
            @objc func appWillEnterBackground(withContext context: AppContext) {}
            @objc func appDidEnterForeground(withContext context: AppContext) {}
        }

        let context = AppContext()
        let delegateMock = AppContextDelegateMock()
        context.delegate = delegateMock
        context.didRegisterToNative(AppContext.networkChanged())
        XCTAssertTrue(delegateMock.networkStatusUpdated, "network status is not updated")


        let expectedParameters = [
            "bluetooth",
            "bluetoothLowEnergy",
            "wifi",
            "cellular"
        ]

        XCTAssertEqual(delegateMock.networkStatus!.count, expectedParameters.count, "Wrong amount of parameters in network status")
        for expectedParameter in expectedParameters {
            XCTAssertNotNil(delegateMock.networkStatus![expectedParameter], "Network status doesn't contain \(expectedParameter) parameter")
        }


        var bluetoothStateActual: String!
        var bluetoothLowEnergyStateActual: String!
        var wifiStateActual: String!
        var cellularStateActual: String!
        var bluetoothStateExpected: String!
        var bluetoothLowEnergyStateExpected: String!
        var wifiStateExpected: String!
        var cellularStateExpected: String!

        BluetoothHarwareControlManager.sharedInstance().registerObserver(self)
        NSThread.sleepForTimeInterval(1)

        // Push hardware state
        let bluetoothIsPoweredBeforeTest = BluetoothHarwareControlManager.sharedInstance().bluetoothIsPowered()

        //TODO: turn bluetooth (and BLE) on and check status
        if !bluetoothIsPoweredBeforeTest {
            expectation = expectationWithDescription("Bluetooth turned on")

            BluetoothHarwareControlManager.sharedInstance().turnBluetoothOn()

            waitForExpectationsWithTimeout(10, handler: { error in
                XCTFail("Can not turn on bluetooth hardware")
            })
        }

        context.didRegisterToNative(AppContext.networkChanged())
        NSThread.sleepForTimeInterval(1)

        bluetoothStateExpected = "on"
        bluetoothLowEnergyStateExpected = "on"
        bluetoothStateActual = delegateMock.networkStatus!["bluetooth"] as! String
        bluetoothLowEnergyStateActual = delegateMock.networkStatus!["bluetoothLowEnergy"] as! String
        XCTAssertEqual(bluetoothStateActual, bluetoothStateExpected, "Wrong bluetooth state (expected: \(bluetoothStateExpected), real: \(bluetoothStateActual))")
        XCTAssertEqual(bluetoothLowEnergyStateActual, bluetoothLowEnergyStateExpected, "Wrong bluetoothLowEnergyState state (expected: on, real: \(bluetoothLowEnergyStateActual))")


        //TODO: turn bluetooth (and BLE) off and check status
        expectation = expectationWithDescription("Bluetooth turned off")

        BluetoothHarwareControlManager.sharedInstance().turnBluetoothOff()

        waitForExpectationsWithTimeout(10, handler: { error in
            XCTFail("Can not turn off bluetooth hardware")
        })

        context.didRegisterToNative(AppContext.networkChanged())
        NSThread.sleepForTimeInterval(1)

        bluetoothStateExpected = "off"
        bluetoothLowEnergyStateExpected = "off"
        bluetoothStateActual = delegateMock.networkStatus!["bluetooth"] as! String
        bluetoothLowEnergyStateActual = delegateMock.networkStatus!["bluetoothLowEnergy"] as! String
        XCTAssertEqual(bluetoothStateActual, bluetoothStateExpected, "Wrong bluetooth state (expected: \(bluetoothStateExpected), real: \(bluetoothStateActual))")
        XCTAssertEqual(bluetoothLowEnergyStateActual, bluetoothLowEnergyStateExpected, "Wrong bluetoothLowEnergyState state (expected: \(bluetoothLowEnergyStateExpected), real: \(bluetoothLowEnergyStateActual))")

        // Restore hardware state
        bluetoothIsPoweredBeforeTest
            ? BluetoothHarwareControlManager.sharedInstance().turnBluetoothOn()
            : BluetoothHarwareControlManager.sharedInstance().turnBluetoothOff()

        //        //TODO: turn wifi on and check status
        //        wifiStateExpected = "on"
        //        wifiStateActual = delegateMock.networkStatus!["wifi"] as! String
        //        XCTAssertEqual(wifiStateActual, wifiStateExpected, "Wrong wifi state (expected: \(wifiStateExpected), real: \(wifiStateActual))")
        //
        //
        //        //TODO: turn wifi off and check status
        //        wifiStateExpected = "off"
        //        wifiStateActual = delegateMock.networkStatus!["wifi"] as! String
        //        XCTAssertEqual(wifiStateActual, wifiStateExpected, "Wrong wifi state (expected: \(wifiStateExpected), real: \(wifiStateActual))")


        //TODO: check cellular in status
        cellularStateExpected = "doNotCare"
        cellularStateActual = delegateMock.networkStatus!["cellular"] as! String
        XCTAssertEqual(cellularStateActual, cellularStateExpected, "Wrong cellular state (expected: \(cellularStateExpected), real: \(cellularStateActual))")
    }
}

extension AppContextTests : BluetoothHarwareControlObserverProtocol {
    func receivedBluetoothNotification(btNotification: BluetoothHardwareControlNotification) {
        if btNotification == PowerChangedNotification {
            expectation?.fulfill()
        }
    }
}
