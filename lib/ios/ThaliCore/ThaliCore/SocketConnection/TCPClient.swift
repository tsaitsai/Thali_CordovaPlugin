//
//  Thali CordovaPlugin
//  TCPClient.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import Foundation

class TCPClient: NSObject {

    // MARK: - Internal state
    internal var localPort: UInt16 {
        return socket.localPort
    }

    // MARK: - Private state
    private var socket: GCDAsyncSocket
    private var connected: Bool = false
    private let socketQueue = dispatch_queue_create("org.thaliproject.GCDAsyncSocket.delegateQueue",
                                                    DISPATCH_QUEUE_CONCURRENT)
    private var activeConnections: Atomic<[GCDAsyncSocket]> = Atomic([])
    private var didReadDataHandler: ((GCDAsyncSocket, NSData) -> Void)
    private var didDisconnectHandler: ((GCDAsyncSocket) -> Void)

    // MARK: - Public methods
    required init(with TCPSocketReadDataHandler: (GCDAsyncSocket, NSData) -> Void,
                       TCPSocketDisconnectHandler: (GCDAsyncSocket) -> Void) {
        socket = GCDAsyncSocket()
        didReadDataHandler = TCPSocketReadDataHandler
        didDisconnectHandler = TCPSocketDisconnectHandler
        super.init()
        socket.delegate = self
        socket.delegateQueue = socketQueue
    }

    func connectToLocalhost(onPort port: UInt16,
                                   completion: (socket: GCDAsyncSocket,
                                                port: UInt16?, error: ErrorType?) -> Void) {
        do {
            try socket.connectToHost("127.0.0.1", onPort: port)
            completion(socket: socket, port: port, error: nil)
        } catch _ {
            completion(socket: socket, port: port, error: ThaliCoreError.ConnectionFailed)
        }
    }

    func disconnectFromLocalhost(with completion: (Bool) -> Void) {
        print("TCP client did disconnect")
        socket.delegate = nil
        socket.delegateQueue = nil
        socket.disconnect()
        completion(true)
    }
}

// MARK: - GCDAsyncSocketDelegate - Handling socket events
extension TCPClient: GCDAsyncSocketDelegate {

    func socket(sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("TCP client connected to host on \(port)")
    }

    func socketDidDisconnect(sock: GCDAsyncSocket, withError err: NSError?) {
        didDisconnectHandler(sock)
    }

    func socket(sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {

    }

    func socket(sock: GCDAsyncSocket, didReadData data: NSData, withTag tag: Int) {
        didReadDataHandler(sock, data)
    }
}
