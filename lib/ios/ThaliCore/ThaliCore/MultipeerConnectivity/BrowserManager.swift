//
//  Thali CordovaPlugin
//  BrowserManager.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import Foundation

/**
 Manages Thali browser's logic
 */
public final class BrowserManager: NSObject {

    // MARK: - Public state
    public var listening: Bool {
        return currentBrowser?.listening ?? false
    }

    // MARK: - Internal state
    internal private(set) var availablePeers: Atomic<[Peer]> = Atomic([])
    internal private(set) var activeRelays: Atomic<[String : BrowserRelay]> = Atomic([:])

    // MARK: - Private state
    private var currentBrowser: Browser?
    private let serviceType: String
    private let inputStreamReceiveTimeout: NSTimeInterval
    private let peersAvailabilityChangedHandler: ([PeerAvailability]) -> Void

    // MARK: - Public state
    public init(serviceType: String,
                inputStreamReceiveTimeout: NSTimeInterval,
                peersAvailabilityChangedHandler: ([PeerAvailability]) -> Void) {
        self.serviceType = serviceType
        self.peersAvailabilityChangedHandler = peersAvailabilityChangedHandler
        self.inputStreamReceiveTimeout = inputStreamReceiveTimeout
    }

    public func startListeningForAdvertisements(errorHandler: ErrorType -> Void) {

        if currentBrowser != nil { return }

        let browser = Browser(serviceType: serviceType,
                              foundPeer: handleFound,
                              lostPeer: handleLost)

        guard let newBrowser = browser else {
            errorHandler(ThaliCoreError.ConnectionFailed)
            return
        }

        newBrowser.startListening(errorHandler)
        self.currentBrowser = newBrowser
    }

    public func stopListeningForAdvertisements() {
        currentBrowser?.stopListening()
        self.currentBrowser = nil
    }

    public func connectToPeer(peer: Peer,
                              syncValue: String,
                              completion: MultiConnectResolvedCallback) {

        guard let currentBrowser = self.currentBrowser else {
            completion(syncValue: syncValue,
                       error: ThaliCoreError.StartListeningNotActive,
                       port: nil)
            return
        }

        if let activeRelay = activeRelays.value[peer.uuid] {
            completion(syncValue: syncValue,
                       error: nil,
                       port: activeRelay.listenerPort)
            return
        }

        guard let lastGenerationPeer = self.lastGenerationPeer(for: peer) else {
                completion(syncValue: syncValue,
                           error: ThaliCoreError.IllegalPeerID,
                           port: nil)
                return
        }

        do {
            let session = try currentBrowser.inviteToConnect(
                lastGenerationPeer,
                sessionConnectHandler: {
                    [weak self] in
                    guard let strongSelf = self else { return }

                    let relay = strongSelf.activeRelays.value[peer.uuid]

                    relay?.openRelay {
                        port, error in
                        completion(syncValue: syncValue, error: error, port: port)
                    }
                },
                sessionDisconnectHandler: {
                    [weak self] in
                    guard let strongSelf = self else { return }

                    strongSelf.activeRelays.modify {
                        if let relay = $0[peer.uuid] {
                            relay.closeRelay()
                        }
                        $0[peer.uuid] = nil
                        print("relay nil in active relays bro")
                    }
                }
            )

            activeRelays.modify {
                let relay = BrowserRelay(with: session,
                                         createVirtualSocketTimeout: self.inputStreamReceiveTimeout)
                $0[peer.uuid] = relay
            }
        } catch let error {
            completion(syncValue: syncValue,
                       error: error,
                       port: nil)
        }
    }

    public func disconnect(peer: Peer) {
        guard let relay = activeRelays.value[peer.uuid] else {
            return
        }

        relay.disconnectNonTCPSession()
    }

    func lastGenerationPeer(for peer: Peer) -> Peer? {
        return availablePeers.withValue {
            $0
            .filter { $0.uuid == peer.uuid }
            .maxElement { $0.0.generation < $0.1.generation }
        }
    }

    // MARK: - Private handlers
    private func handleFound(peer: Peer) {
        availablePeers.modify { $0.append(peer) }

        let updatedPeerAvailability = PeerAvailability(peer: peer, available: true)
        peersAvailabilityChangedHandler([updatedPeerAvailability])
    }

    private func handleLost(peer: Peer) {
        availablePeers.modify {
            if let indexOfLostPeer = $0.indexOf(peer) {
                $0.removeAtIndex(indexOfLostPeer)
            }
        }

        let updatedPeerAvailability = PeerAvailability(peer: peer, available: false)
        peersAvailabilityChangedHandler([updatedPeerAvailability])
    }
}
