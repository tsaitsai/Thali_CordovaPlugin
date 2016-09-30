//
//  Thali CordovaPlugin
//  Relay.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import Foundation

/**
 `Relay` class manages both TCP and non-TCP connections and handles binding.
 */
class Relay<SocketBuilder: VirtualSocketBuilder>: NSObject {

    // MARK: - Internal state
    internal var virtualSocketsAmount: Int {
        return virtualSockets.value.count
    }

    // MARK: - Private state
    private var nonTCPsession: Session
    private var virtualSockets: Atomic<[GCDAsyncSocket : VirtualSocket]> = Atomic([:])
    private let createVirtualSocketTimeout: NSTimeInterval

    // MARK: - Public methods
    init(with session: Session, createVirtualSocketTimeout: NSTimeInterval) {
        self.nonTCPsession = session
        self.createVirtualSocketTimeout = createVirtualSocketTimeout
        super.init()
    }

    // MARK: - Internal methods
    func disconnectNonTCPSession() {
        print("disconnect nonTCP session")
        self.nonTCPsession.disconnect()
    }

    // MARK: - Private methods
    private func createNonTCPVirtualSocket(
        with completion: ((VirtualSocket?, ErrorType?) -> Void)) {

        let _ = SocketBuilder(with: nonTCPsession,
                              streamReceivedBackTimeout: createVirtualSocketTimeout) {
            virtualSocket, error in
            completion(virtualSocket, error)
        }
    }

    private func readDataFromInputStream(virtualSocket: VirtualSocket, data: NSData) {
        virtualSockets.withValue {
            print("Browser. searcing for socket...")
            if let socket = $0.key(for: virtualSocket) {
                print("Browser. socket founded. writing...")
                socket.writeData(data, withTimeout: -1, tag: 0)
            }
        }
    }

    private func didClosedInputStreamHandler() {
        print("received closed event on vs inputStream in relay")
    }
}

// MARK: - Methods that available for Relay<AdvertiserVirtualSocketBuilder>
final class AdvertiserRelay: Relay<AdvertiserVirtualSocketBuilder> {

    // MARK: - Internal state
    internal var clientPort: UInt16 {
        return tcpClient.localPort
    }

    // MARK: - Private state
    private var tcpClient: TCPClient!

    // MARK: - Public methods
    override init(with session: Session, createVirtualSocketTimeout: NSTimeInterval = 0) {
        super.init(with: session, createVirtualSocketTimeout: createVirtualSocketTimeout)
        self.tcpClient = TCPClient(with: TCPSocketReadDataHandler,
                                   TCPSocketDisconnectHandler: TCPSocketDisconnectHandler)
    }

    func openRelay(on port: UInt16, completion: (port: UInt16?, error: ErrorType?) -> Void) {
        tcpClient.connectToLocalhost(onPort: port) {
            [weak self] socket, port, error in
            guard let strongSelf = self else { return }

            print("advertiser. connecting TCP client and starting creating vs.")

            guard error == nil else {
                completion(port: port, error: error)
                return
            }

            strongSelf.createNonTCPVirtualSocket {
                virtualSocket, error in

                guard let virtualSocket = virtualSocket else {
                    return
                }

                print("advertiser: VS is created after accepting connection, error: \(error)")

                strongSelf.virtualSockets.modify {
                    virtualSocket.didReadDataFromStreamHandler = strongSelf.readDataFromInputStream
                    virtualSocket.openStreams()
                    $0[socket] = virtualSocket
                }

                socket.readDataWithTimeout(-1, tag: 0)

                completion(port: port, error: error)
            }
        }
    }

    func closeRelay(with completion: (Bool) -> Void) {
        disconnectTCPSocket {
            result in
            completion(result)
        }

        virtualSockets.modify {
            $0.forEach { $0.1.closeStreams() }
            $0.removeAll()
        }
    }

    // MARK: - Private methods
    private func disconnectTCPSocket(with completion: (Bool) -> Void) {
        tcpClient.disconnectFromLocalhost {
            result in
            completion(result)
        }
    }

    // MARK: - Private handlers
    private func TCPSocketReadDataHandler(socket: GCDAsyncSocket, data: NSData) {
        virtualSockets.withValue {
            let virtualSocket = $0[socket]
            print("socket \(socket) for vs \(virtualSocket)")
            virtualSocket?.writeDataToOutputStream(data)
        }
    }

    private func TCPSocketDisconnectHandler(socket: GCDAsyncSocket) {

    }
}

// MARK: - Methods that available for Relay<BrowserVirtualSocketBuilder>
final class BrowserRelay: Relay<BrowserVirtualSocketBuilder> {

    // MARK: - Internal state
    internal var listenerPort: UInt16 {
        return tcpListener.listenerPort
    }

    // MARK: - Private state
    private var tcpListener: TCPListener!

    // MARK: - Public methods
    override init(with session: Session, createVirtualSocketTimeout: NSTimeInterval) {
        super.init(with: session, createVirtualSocketTimeout: createVirtualSocketTimeout)

        tcpListener = TCPListener(with: TCPSocketReadDataHandler,
                                  TCPsocketDisconnectHandler: TCPSocketDisconnectHandler)
    }

    func openRelay(with completion: (port: UInt16?, error: ErrorType?) -> Void) {
        let anyAvailablePort: UInt16 = 0

        tcpListener.startListeningForIncomingConnections(
                                            on: anyAvailablePort,
                                            newConnectionHandler: acceptConnectionHandler) {
                port, error in
                completion(port: port, error: error)
        }
    }

    func closeRelay() {
        tcpListener.stopListeningForIncomingConnections()

        virtualSockets.modify {
            $0.forEach { $0.1.closeStreams() }
            $0.removeAll()
        }
    }

    // MARK: - Handlers
    private func acceptConnectionHandler(socket: GCDAsyncSocket) {
        createNonTCPVirtualSocket {
            virtualSocket, error in

            print("browser: VS is created after accepting connection, error: \(error)")

            self.virtualSockets.modify {
                virtualSocket?.didReadDataFromStreamHandler = self.readDataFromInputStream
                virtualSocket?.openStreams()
                $0[socket] = virtualSocket
            }

            socket.readDataWithTimeout(-1, tag: 1)
        }
    }

    private func TCPSocketReadDataHandler(socket: GCDAsyncSocket, data: NSData) {
        let msg = NSString(data: data, encoding: NSUTF8StringEncoding)

        print("Relay: read TCPListener data with length \(msg?.length)")
        virtualSockets.withValue {
            let virtualSocket = $0[socket]
            virtualSocket?.writeDataToOutputStream(data)
        }

    }

    private func TCPSocketDisconnectHandler(socket: GCDAsyncSocket) {
        self.virtualSockets.modify {
            let virtualSocket = $0[socket]
            virtualSocket?.closeStreams()
            $0[socket] = nil
        }
    }
}
