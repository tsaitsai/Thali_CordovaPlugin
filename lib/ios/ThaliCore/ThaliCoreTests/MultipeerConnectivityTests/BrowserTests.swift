//
//  Thali CordovaPlugin
//  BrowserTests.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import MultipeerConnectivity
@testable import ThaliCore
import XCTest

class BrowserTests: XCTestCase {

    // MARK: - State
    let randomlyGeneratedServiceType = String.randomValidServiceType(length: 7)

    // MARK: - Tests
    func testStartStopChangesListeningState() {
        // Given
        let newBrowser = Browser(serviceType: randomlyGeneratedServiceType,
                                 foundPeer: unexpectedFoundPeerHandler,
                                 lostPeer: unexpectedLostPeerHandler)

        guard let browser = newBrowser else {
            XCTFail("Browser must not be nil")
            return
        }

        // When
        browser.startListening(unexpectedErrorHandler)
        // Then
        XCTAssertTrue(browser.listening)

        // When
        browser.stopListening()
        // Then
        XCTAssertFalse(browser.listening)
    }

    func testFoundPeerHandlerCalled() {
        // Given
        let foundPeerExpectation =
            expectationWithDescription("foundPeerHandler is called on Browser")

        let newBrowser = Browser(serviceType: randomlyGeneratedServiceType,
                                 foundPeer: {
                                     [weak foundPeerExpectation] _ in
                                     foundPeerExpectation?.fulfill()
                                 },
                                 lostPeer: { _ in })

        guard let browser = newBrowser else {
            XCTFail("Browser must not be nil")
            return
        }
        let randomlyGeneratedPeerID = MCPeerID(displayName: Peer().stringValue)
        let mcBrowser = MCNearbyServiceBrowser(peer: randomlyGeneratedPeerID,
                                               serviceType: randomlyGeneratedServiceType)


        // When
        // Fake invocation of delegate method
        browser.browser(mcBrowser, foundPeer: randomlyGeneratedPeerID, withDiscoveryInfo: nil)

        let foundLostPeerExpectationsTimeout = 1.0
        waitForExpectationsWithTimeout(foundLostPeerExpectationsTimeout, handler: nil)
    }

    func testLostPeerHandlerCalled() {
        // Given
        let lostPeerExpectation =
            expectationWithDescription("lostPeerHandler is called on Browser")

        let newBrowser = Browser(serviceType: randomlyGeneratedServiceType,
                                 foundPeer: { _ in },
                                 lostPeer: {
                                     [weak lostPeerExpectation] _ in
                                     lostPeerExpectation?.fulfill()
                                 })

        guard let browser = newBrowser else {
            XCTFail("Browser must not be nil")
            return
        }

        let randomlyGeneratedPeerID = MCPeerID(displayName: Peer().stringValue)
        let mcBrowser = MCNearbyServiceBrowser(peer: randomlyGeneratedPeerID,
                                               serviceType: randomlyGeneratedServiceType)

        // When
        browser.browser(mcBrowser, lostPeer: randomlyGeneratedPeerID)

        // Then
        let foundLostPeerExpectationsTimeout = 1.0
        waitForExpectationsWithTimeout(foundLostPeerExpectationsTimeout, handler: nil)
    }

    func testStartListeningErrorHandlerCalled() {
        // Given
        let failedStartBrowsingExpectation =
            expectationWithDescription("Failed start advertising because of " +
                "delegate MCNearbyServiceBrowserDelegate call")

        let newBrowser = Browser(serviceType: randomlyGeneratedServiceType,
                                 foundPeer: unexpectedFoundPeerHandler,
                                 lostPeer: unexpectedLostPeerHandler)

        guard let browser = newBrowser else {
            XCTFail("Browser must not be nil")
            return
        }

        browser.startListening {
            [weak failedStartBrowsingExpectation] error in
            failedStartBrowsingExpectation?.fulfill()
        }

        let randomlyGeneratedPeerID = MCPeerID(displayName: NSUUID().UUIDString)
        let mcBrowser = MCNearbyServiceBrowser(peer: randomlyGeneratedPeerID,
                                               serviceType: randomlyGeneratedServiceType)

        // When
        // Fake invocation of delegate method
        // Send error start browsing failed error
        let error = NSError(domain: "org.thaliproject.test", code: 42, userInfo: nil)
        browser.browser(mcBrowser, didNotStartBrowsingForPeers: error)

        // Then
        waitForExpectationsWithTimeout(1.0, handler: nil)
    }

    func testInviteToConnectPeerMethodReturnsSession() {
        // Given
        // Firsly we have to "find" peer and get handler called
        let foundPeerExpectation =
            expectationWithDescription("foundPeerHandler is called on Browser")

        let randomlyGeneratedPeer = Peer()

        let newBrowser = Browser(serviceType: randomlyGeneratedServiceType,
                                 foundPeer: {
                                     [weak foundPeerExpectation] foundedPeer in

                                     foundPeerExpectation?.fulfill()
                                     XCTAssertEqual(
                                         foundedPeer, randomlyGeneratedPeer
                                     )
                                 },
                                 lostPeer: unexpectedLostPeerHandler)

        guard let browser = newBrowser else {
            XCTFail("Browser must not be nil")
            return
        }

        let peerIdOfPeerThatWillBeFounded =
            MCPeerID(displayName: randomlyGeneratedPeer.stringValue)
        let mcBrowser = MCNearbyServiceBrowser(peer: peerIdOfPeerThatWillBeFounded,
                                               serviceType: randomlyGeneratedServiceType)

        // Fake invocation of delegate method
        browser.browser(mcBrowser, foundPeer: peerIdOfPeerThatWillBeFounded, withDiscoveryInfo: nil)

        let foundPeerExpectationTimeout = 1.0
        waitForExpectationsWithTimeout(foundPeerExpectationTimeout, handler: nil)

        // When
        do {
            let session = try
                browser.inviteToConnect(randomlyGeneratedPeer,
                                        sessionConnectHandler:  unexpectedConnectHandler,
                                        sessionDisconnectHandler: unexpectedDisconnectHandler)
            // Then
            XCTAssertNotNil(session)
        } catch let error {
            XCTFail("inviteToConnectPeer didn't return Session. Unexpected error: \(error)")
        }
    }

    func testInviteToConnectWrongPeerReturnsIllegalPeerIDError() {
        // Given
        let newBrowser = Browser(serviceType: randomlyGeneratedServiceType,
                                 foundPeer: unexpectedFoundPeerHandler,
                                 lostPeer: unexpectedLostPeerHandler)

        guard let browser = newBrowser else {
            XCTFail("Browser must not be nil")
            return
        }

        // When
        do {
            let _ = try
                browser.inviteToConnect(Peer(),
                                        sessionConnectHandler: unexpectedConnectHandler,
                                        sessionDisconnectHandler: unexpectedDisconnectHandler)
        } catch let error as ThaliCoreError {
            // Then
            XCTAssertEqual(error, ThaliCoreError.IllegalPeerID)
        } catch let error {
            XCTFail(
                "inviteToConnectPeer didn't return IllegalPeerID error. " +
                    "Unexpected error: \(error)"
            )
        }
    }

    // MARK: - Private methods
    private func unexpectedFoundPeerHandler(peer: Peer) {
        XCTFail("Unexpected call foundPeerHandler with peer: \(peer)")
    }

    private func unexpectedLostPeerHandler(peer: Peer) {
        XCTFail("unexpected lostPeerHandler with peer: \(peer)")
    }
}
