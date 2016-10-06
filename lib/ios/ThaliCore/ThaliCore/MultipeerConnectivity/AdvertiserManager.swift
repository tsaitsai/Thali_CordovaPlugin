//
//  Thali CordovaPlugin
//  AdvertiserManager.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import Foundation

/**
 Manages Thali advertiser's logic
 */
public final class AdvertiserManager: NSObject {

    // MARK: - Public state
    public var advertising: Bool {
        return currentAdvertiser?.advertising ?? false
    }

    // MARK: - Internal state
    internal private(set) var advertisers: Atomic<[Advertiser]> = Atomic([])
    internal private(set) var activeRelays: Atomic<[String : AdvertiserRelay]> = Atomic([:])
    internal var didDisposeAdvertiserForPeerHandler: ((Peer) -> Void)?

    // MARK: - Private state
    private var currentAdvertiser: Advertiser?
    private let serviceType: String
    private let disposeTimeout: NSTimeInterval

    // MARK: - Initialization
    public init(serviceType: String, disposeAdvertiserTimeout: NSTimeInterval) {
        self.serviceType = serviceType
        self.disposeTimeout = disposeAdvertiserTimeout
        super.init()
    }

    // MARK: - Public methods
    public func startUpdateAdvertisingAndListening(onPort port: UInt16,
                                                          errorHandler: ErrorType -> Void) {
        if let currentAdvertiser = currentAdvertiser {
            disposeAdvertiserAfterTimeoutToFinishInvites(currentAdvertiser)
        }

        let newPeer = currentAdvertiser?.peer.nextGenerationPeer() ?? Peer()

        let advertiser = Advertiser(peer: newPeer,
                                    serviceType: serviceType,
                                    receivedInvitation: {
                                        [weak self] session in
                                        guard let strongSelf = self else { return }

                                        strongSelf.activeRelays.modify {
                                            let relay = AdvertiserRelay(with: session)
                                            $0[newPeer.uuid] = relay

                                            relay.openRelay(on: port) {
                                                port, error in
                                            }
                                        }
                                    },
                                    disconnected: {
                                        [weak self] in
                                        guard let strongSelf = self else { return }

                                        strongSelf.activeRelays.modify {
                                            if let relay = $0[newPeer.uuid] {
                                                relay.closeRelay {
                                                    result in
                                                }
                                            }
                                            $0[newPeer.uuid] = nil
                                        }
                                    })
        guard let newAdvertiser = advertiser else {
            errorHandler(ThaliCoreError.ConnectionFailed)
            return
        }

        advertisers.modify {
            newAdvertiser.startAdvertising(errorHandler)
            $0.append(newAdvertiser)
        }

        self.currentAdvertiser = advertiser
    }

    public func stopAdvertising() {
        advertisers.modify {
            $0.forEach { $0.stopAdvertising() }
            $0.removeAll()
        }
        currentAdvertiser = nil
    }

    // MARK: - Private methods
    private func disposeAdvertiserAfterTimeoutToFinishInvites(
        advertiserShouldBeDisposed: Advertiser) {

        let disposeTimeout = dispatch_time(DISPATCH_TIME_NOW,
                                           Int64(self.disposeTimeout * Double(NSEC_PER_SEC)))

        dispatch_after(disposeTimeout, dispatch_get_main_queue()) {
            [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.advertisers.modify {
                advertiserShouldBeDisposed.stopAdvertising()
                if let indexOfDisposingAdvertiser = $0.indexOf(advertiserShouldBeDisposed) {
                    $0.removeAtIndex(indexOfDisposingAdvertiser)
                }
            }

            strongSelf.didDisposeAdvertiserForPeerHandler?(advertiserShouldBeDisposed.peer)
        }
    }
}
