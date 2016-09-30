//
//  Thali CordovaPlugin
//  AdvertiserTests.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import MultipeerConnectivity
@testable import ThaliCore
import XCTest

class AdvertiserTests: XCTestCase {

    // MARK: - State
    let randomlyGeneratedServiceType = String.randomValidServiceType(length: 7)

    // MARK: - Tests
    func testAdvertiserReturnsObjectWhenValidServiceType() {
        // Given, When
        let advertiser = Advertiser(peer: Peer(),
                                    serviceType: randomlyGeneratedServiceType,
                                    receivedInvitation: unexpectedReceivedSessionHandler,
                                    disconnected: unexpectedDisconnectHandler)

        // Then
        XCTAssertNotNil(advertiser, "Advertiser object is nil and could not be created")
    }

    func testAdvertiserReturnsNilWhenEmptyServiceType() {
        // Given
        let emptyServiceType = String.randomValidServiceType(length: 0)

        // When
        let advertiser = Advertiser(peer: Peer(),
                                    serviceType: emptyServiceType,
                                    receivedInvitation: unexpectedReceivedSessionHandler,
                                    disconnected: unexpectedDisconnectHandler)

        // Then
        XCTAssertNil(advertiser, "Advertiser object is created with empty serviceType parameter")
    }

    func testStartStopChangesAdvertisingState() {
        // Given
        let newAdvertiser = Advertiser(peer: Peer(),
                                       serviceType: randomlyGeneratedServiceType,
                                       receivedInvitation: unexpectedReceivedSessionHandler,
                                       disconnected: unexpectedDisconnectHandler)

        guard let advertiser = newAdvertiser else {
            XCTFail("Advertiser must not be nil")
            return
        }

        // When
        advertiser.startAdvertising(unexpectedErrorHandler)
        // Then
        XCTAssertTrue(advertiser.advertising)

        // When
        advertiser.stopAdvertising()
        // Then
        XCTAssertFalse(advertiser.advertising)
    }

    func testStartCalledTwiceChangesStateProperly() {
        // Given
        let newAdvertiser = Advertiser(peer: Peer(),
                                       serviceType: randomlyGeneratedServiceType,
                                       receivedInvitation: unexpectedReceivedSessionHandler,
                                       disconnected: unexpectedDisconnectHandler)

        guard let advertiser = newAdvertiser else {
            XCTFail("Advertiser must not be nil")
            return
        }

        advertiser.startAdvertising(unexpectedErrorHandler)
        XCTAssertTrue(advertiser.advertising)

        // When
        advertiser.startAdvertising(unexpectedErrorHandler)

        // Then
        XCTAssertTrue(advertiser.advertising)
    }

    func testStopCalledTwiceChangesStateProperly() {
        // Given
        let newAdvertiser = Advertiser(peer: Peer(),
                                       serviceType: randomlyGeneratedServiceType,
                                       receivedInvitation: unexpectedReceivedSessionHandler,
                                       disconnected: unexpectedDisconnectHandler)

        guard let advertiser = newAdvertiser else {
            XCTFail("Advertiser must not be nil")
            return
        }

        advertiser.startAdvertising(unexpectedErrorHandler)
        XCTAssertTrue(advertiser.advertising)
        advertiser.stopAdvertising()
        XCTAssertFalse(advertiser.advertising)

        // When
        advertiser.stopAdvertising()

        // Then
        XCTAssertFalse(advertiser.advertising)
    }

    func testFailedStartAdvertising() {
        // Given
        let startAdvertisingErrorHandlerCalled =
            expectationWithDescription("startAdvertisingErrorHandler is called.")

        let newAdvertiser = Advertiser(peer: Peer(),
                                       serviceType: String.randomValidServiceType(length: 7),
                                       receivedInvitation: unexpectedReceivedSessionHandler,
                                       disconnected: unexpectedDisconnectHandler)

        guard let advertiser = newAdvertiser else {
            XCTFail("Advertiser must not be nil")
            return
        }

        advertiser.startAdvertising {
            [weak startAdvertisingErrorHandlerCalled] error in
            startAdvertisingErrorHandlerCalled?.fulfill()
        }

        let mcAdvertiser = MCNearbyServiceAdvertiser(peer: MCPeerID(displayName: "test"),
                                                     discoveryInfo: nil,
                                                     serviceType: "test")

        // When
        // Fake invocation of delegate method
        let error = NSError(domain: "org.thaliproject.test.fake",
                            code: 42,
                            userInfo: nil)
        advertiser.advertiser(mcAdvertiser, didNotStartAdvertisingPeer: error)

        // Then
        let didNotStartAdvertisingTimeout: NSTimeInterval = 1.0
        waitForExpectationsWithTimeout(didNotStartAdvertisingTimeout, handler: nil)
    }

    //    func testStartStopMethodsEmptyRaceConditions() {
    //        // Given
    //        let randomlyGeneratedPeerID = MCPeerID(displayName: NSUUID().UUIDString)
    //        let advertiser = createAndStartAdvertiser(with: randomlyGeneratedPeerID,
    //                                                  receivedInvitationHandler: { _ in },
    //                                                  disconnectHandler: unexpectedDisconnectHandler,
    //                                                  mcSessionInvitationHandler: { _ in })
    //
    //        let startQueue = dispatch_queue_create("org.thaliproject.AdvertiserTestsStartQueue",
    //                                               DISPATCH_QUEUE_CONCURRENT)
    //        let stopQueue = dispatch_queue_create("org.thaliproject.AdvertiserTestsStopQueue",
    //                                              DISPATCH_QUEUE_CONCURRENT)
    //
    //        let testExp = expectationWithDescription("wait 5 sec")
    //
    //        let loopIterationsCount = 10000
    //
    //        dispatch_async(startQueue) {
    //            for i in 0...loopIterationsCount {
    //                advertiser.startAdvertising(unexpectedErrorHandler)
    //                print("start before \(i)")
    //                XCTAssertTrue(advertiser.advertising, "ITER: \(i)")
    //                print("start after \(i)")
    //            }
    //        }
    //
    //        dispatch_async(stopQueue) {
    //            for i in 0...loopIterationsCount {
    //                advertiser.stopAdvertising()
    //                print("stop before \(i)")
    //                XCTAssertFalse(advertiser.advertising, "ITER: \(i)")
    //                print("stop after \(i)")
    //            }
    //        }
    //
    //        waitForExpectationsWithTimeout(5, handler: nil)
    //    }
}
