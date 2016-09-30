//
//  Thali CordovaPlugin
//  VirtualSocketBuilder.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import Foundation

class VirtualSocketBuilder {

    // MARK: - Private state
    private let nonTCPsession: Session
    private let streamReceivedBackTimeout: NSTimeInterval

    required init(with nonTCPsession: Session,
                       streamReceivedBackTimeout: NSTimeInterval,
                       completion: (VirtualSocket?, ErrorType?) -> Void) {
        self.nonTCPsession = nonTCPsession
        self.streamReceivedBackTimeout = streamReceivedBackTimeout
    }
}

/**
 Creates `VirtualSocket` on `BrowserRelay` if possible.
 */
final class BrowserVirtualSocketBuilder: VirtualSocketBuilder {

    required init(with nonTCPsession: Session,
                       streamReceivedBackTimeout: NSTimeInterval,
                       completion: (VirtualSocket?, ErrorType?) -> Void) {

        super.init(with: nonTCPsession,
                   streamReceivedBackTimeout: streamReceivedBackTimeout,
                   completion: completion)

        do {
            let streamReceivedBack = Atomic(false)

            print("Start building socket...")

            let outputStreamName = NSUUID().UUIDString
            let outputStream = try nonTCPsession.startOutputStream(with: outputStreamName)
            nonTCPsession.didReceiveInputStreamHandler = {
                inputStream, inputStreamName in

                guard inputStreamName == outputStreamName else {
                    inputStream.close()
                    completion(nil, ThaliCoreError.ConnectionFailed)
                    return
                }

                streamReceivedBack.modify { $0 = true }
                let virtualNonTCPSocket = VirtualSocket(with: inputStream,
                                                        outputStream: outputStream)

                completion(virtualNonTCPSocket, nil)
            }

            let streamReceivedBackTimeout = dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(streamReceivedBackTimeout * Double(NSEC_PER_SEC))
            )

            dispatch_after(streamReceivedBackTimeout, dispatch_get_main_queue()) {
                [weak self] in
                guard let strongSelf = self else { return }

                streamReceivedBack.withValue {
                    if $0 == false {
                        strongSelf.nonTCPsession.didReceiveInputStreamHandler = nil
                    }
                }

                completion(nil, ThaliCoreError.ConnectionTimedOut)
            }
        } catch let error {
            completion(nil, error)
        }
    }
}

/**
 Creates `VirtualSocket` on `AdvertiserRelay` if possible.
 */
final class AdvertiserVirtualSocketBuilder: VirtualSocketBuilder {

    required init(with nonTCPsession: Session,
                       streamReceivedBackTimeout: NSTimeInterval,
                       completion: (VirtualSocket?, ErrorType?) -> Void) {

        super.init(with: nonTCPsession,
                   streamReceivedBackTimeout: streamReceivedBackTimeout,
                   completion: completion)

        let streamReceivedBack = Atomic(false)

        print("not recieve yet. start building socket...")

        self.nonTCPsession.didReceiveInputStreamHandler = {
            inputStream, inputStreamName in

            print("receive!!!! Start building socket...")

            streamReceivedBack.modify { $0 = true }

            do {
                let outputStream = try nonTCPsession.startOutputStream(with: inputStreamName)
                let virtualNonTCPSocket = VirtualSocket(with: inputStream,
                                                        outputStream: outputStream)
                completion(virtualNonTCPSocket, nil)
            } catch let error {
                completion(nil, error)
            }
        }

        let streamReceivedBackTimeout = dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(streamReceivedBackTimeout * Double(NSEC_PER_SEC))
        )

        dispatch_after(streamReceivedBackTimeout, dispatch_get_main_queue()) {
            [weak self] in
            guard let strongSelf = self else { return }

            streamReceivedBack.withValue {
                if $0 == false {
                    strongSelf.nonTCPsession.didReceiveInputStreamHandler = nil
                }
            }

            completion(nil, ThaliCoreError.ConnectionTimedOut)
        }
    }
}
