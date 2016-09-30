//
//  Thali CordovaPlugin
//  TCPListener.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import Foundation

/**
 Provides simple methods that listen for and accept incoming TCP connection requests.
 */
class TCPListener: NSObject {

    // MARK: - Internal state
    internal var listenerPort: UInt16 {
        return socket.localPort
    }

    // MARK: - Private state
    private var socket: GCDAsyncSocket
    private var listening: Bool = false
    private let socketQueue = dispatch_queue_create("org.thaliproject.GCDAsyncSocket.delegateQueue",
                                                    DISPATCH_QUEUE_CONCURRENT)
    private var activeConnections: Atomic<[GCDAsyncSocket]> = Atomic([])
    private var didAcceptConnectionHandler: ((GCDAsyncSocket) -> Void)?
    private var didReadDataHandler: ((GCDAsyncSocket, NSData) -> Void)
    private var didDisconnectHandler: ((GCDAsyncSocket) -> Void)

    // MARK: - Public methods
    required init(with TCPSocketReadDataHandler: (GCDAsyncSocket, NSData) -> Void,
                  TCPsocketDisconnectHandler: (GCDAsyncSocket) -> Void) {
        socket = GCDAsyncSocket()
        didReadDataHandler = TCPSocketReadDataHandler
        didDisconnectHandler = TCPsocketDisconnectHandler
        super.init()
        socket.delegate = self
        socket.delegateQueue = socketQueue
    }

    convenience override init() {
        self.init()
    }

    func startListeningForIncomingConnections(on port: UInt16,
                                                 newConnectionHandler: (GCDAsyncSocket) -> Void,
                                                 completion: (port: UInt16?, error: ErrorType?)
                                              -> Void) {
        if !listening {
            do {
                try socket.acceptOnPort(port)
                listening = true
                didAcceptConnectionHandler = newConnectionHandler
                completion(port: socket.localPort, error: nil)
            } catch _ {
                completion(port: 0, error: ThaliCoreError.ConnectionFailed)
            }
        }
    }

    func stopListeningForIncomingConnections() {
        if listening {
            listening = false
            socket.delegate = nil
            socket.delegateQueue = nil
            socket.disconnect()
        }
    }
}

// MARK: - GCDAsyncSocketDelegate - Handling socket events
extension TCPListener: GCDAsyncSocketDelegate {

    func socketDidDisconnect(sock: GCDAsyncSocket, withError err: NSError?) {
        activeConnections.modify {
            if let indexOfDisconnectedSocket = $0.indexOf(sock) {
                $0.removeAtIndex(indexOfDisconnectedSocket)
            }
        }

        didDisconnectHandler(sock)
    }

    func socket(sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("TCP listener accepted new connection on port \(sock.localPort)")
        activeConnections.modify { $0.append(newSocket) }
        didAcceptConnectionHandler?(newSocket)
    }

    func socket(sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {

    }

    func socket(sock: GCDAsyncSocket, didReadData data: NSData, withTag tag: Int) {
        didReadDataHandler(sock, data)
    }
}
