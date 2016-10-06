//
//  Thali CordovaPlugin
//  PeerTests.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import XCTest
@testable import ThaliCore

class PeerTests: XCTestCase {

    func testGenetationByNextGenerationCallShouldHaveSameUUIDPart() {
        let peer = Peer()
        let nextGenPeer = peer.nextGenerationPeer()
        XCTAssertEqual(peer.uuid, nextGenPeer.uuid)
    }

    func testGenetationByNextGenerationCallShouldBeIncreasedByOne() {
        let peer = Peer()
        let nextGenPeer = peer.nextGenerationPeer()
        XCTAssertEqual(peer.generation + 1, nextGenPeer.generation)
    }

    func testStringValueHasEBNForm() {
        for i in 0...0xF {
            let uuid = NSUUID().UUIDString
            let string = "\(uuid):\(String(i, radix: 16))"
            let peer = try? Peer(stringValue: string)
            XCTAssertEqual(peer?.uuid, uuid)
            XCTAssertEqual(peer?.generation, i)
        }
    }

    func testInitWithStringHasNotEBNFormError() {
        let string = "eqwer:asdf:aasdf"
        var parsingError: ThaliCoreError?
        do {
            let _ = try Peer(stringValue: string)
        } catch let peerErr as ThaliCoreError {
            parsingError = peerErr
        } catch _ {
        }
        XCTAssertEqual(parsingError, .IllegalPeerID)
    }

    func testInitWithStringHasNotNumberGeneration() {
        let string = "eqwer:not_a_number"
        var parsingError: ThaliCoreError?
        do {
            let _ = try Peer(stringValue: string)
        } catch let peerErr as ThaliCoreError {
            parsingError = peerErr
        } catch _ {
        }
        XCTAssertEqual(parsingError, .IllegalPeerID)
    }

    func testEqualityByCharacter() {
        let peerID1 = Peer()
        let peerID2 = Peer(uuidIdentifier: peerID1.uuid, generation: peerID1.generation)
        XCTAssertEqual(peerID1, peerID2)

        /* These strings has the same linguistic meaning and appearance but using different UTF-8
           characters. But `==` treats them as equal because they're canonically equivalent.
           Therefore we need to use String.compare function to compare strings by character
         */
        let peerID3 = Peer(uuidIdentifier: "id\u{E9}ntifi\u{E9}r", generation: 0)
        let peerID4 = Peer(uuidIdentifier: "id\u{65}\u{301}ntifi\u{65}\u{301}r",
                           generation: 0)
        XCTAssertEqual(peerID3.uuid, peerID4.uuid)
        XCTAssertNotEqual(peerID3, peerID4)
    }

    func testGenerationsEquality() {
        let peerID1 = Peer()
        let peerID2 = Peer(uuidIdentifier: peerID1.uuid,
                                     generation: peerID1.generation + 1)
        XCTAssertNotEqual(peerID1, peerID2)
    }
}
