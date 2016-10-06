//
//  Thali CordovaPlugin
//  Advertiser.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import Foundation
import MultipeerConnectivity

/**
 The `Advertiser` class manages underlying `MCNearbyServiceAdvertiser` object
 and handles `MCNearbyServiceAdvertiserDelegate` events
 */
final class Advertiser: NSObject {

    // MARK: - Internal state
    internal private(set) var advertising: Bool = false
    internal let peer: Peer

    // MARK: - Private state
    private let advertiser: MCNearbyServiceAdvertiser
    private let didReceiveInvitationHandler: (session: Session) -> Void
    private let didDisconnectHandler: () -> Void
    private var startAdvertisingErrorHandler: (ErrorType -> Void)? = nil

    // MARK: - Public methods

    /**
     Returns a new `Advertiser` object or nil if it could not be created.

     - parameters:
       - peer:
         `Peer`

       - serviceType:
         The type of service to advertise.
         This should be a string in the format of Bonjour service type:
           1. *Must* be 1–15 characters long
           2. Can contain *only* ASCII letters, digits, and hyphens.
           3. *Must* contain at least one ASCII letter
           4. *Must* not begin or end with a hyphen
           5. Hyphens must not be adjacent to other hyphens
         For more details, see [RFC6335](https://tools.ietf.org/html/rfc6335#section-5.1).

       - receivedInvitation:
         Called when an invitation to join a MCSession is received from a nearby peer.

       - disconnected:
         Called when the nearby peer is not (or is no longer) in this session.

     - returns: An initialized `Advertiser` object, or nil if an object could not be created
                due to invalid `serviceType` format.
     */
    required init?(peer: Peer,
                   serviceType: String,
                   receivedInvitation: (session: Session) -> Void,
                   disconnected: () -> Void) {

        if !String.isValidServiceType(serviceType) {
            return nil
        }

        let advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID(peer: peer),
                                                   discoveryInfo:nil,
                                                   serviceType: serviceType)

        self.advertiser = advertiser
        self.peer = peer
        self.didReceiveInvitationHandler = receivedInvitation
        self.didDisconnectHandler = disconnected
        super.init()
    }

    /**
     Begins advertising the `serviceType` provided in init method.

     This method sets `advertising` value to `true`.

     This method does not change state if `Advertiser` is already advertising.

     - parameters:
       - startAdvertisingErrorHandler:
         Called when advertisement fails.
     */
    func startAdvertising(startAdvertisingErrorHandler: ErrorType -> Void) {
        if !advertising {
            self.startAdvertisingErrorHandler = startAdvertisingErrorHandler
            advertiser.delegate = self
            advertiser.startAdvertisingPeer()
            advertising = true
        }
    }

    /**
     Stops advertising the `serviceType` provided in init method.

     This method sets `advertising` value to `false`.

     This method does not change state if `Advertiser` is already advertising.
     */
    func stopAdvertising() {
        if advertising {
            advertiser.delegate = nil
            advertiser.stopAdvertisingPeer()
            advertising = false
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension Advertiser: MCNearbyServiceAdvertiserDelegate {

    func advertiser(advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: NSData?,
                    invitationHandler: (Bool, MCSession) -> Void) {

        let mcSession = MCSession(peer: advertiser.myPeerID)

        // TODO: https://github.com/thaliproject/Thali_CordovaPlugin/issues/1040
        let session = Session(session: mcSession,
                              identifier: peerID,
                              connectHandler: {},
                              disconnectHandler: didDisconnectHandler)

        invitationHandler(true, mcSession)
        didReceiveInvitationHandler(session: session)
    }

    func advertiser(advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: NSError) {
        stopAdvertising()
        startAdvertisingErrorHandler?(error)
    }
}
