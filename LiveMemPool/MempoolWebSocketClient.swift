//
//  MempoolWebSocketClient.swift
//  LiveMemPool
//
//  Created by Abe Mangona on 5/15/25.
//

import Foundation

// Protocol for WebSocket event delegation
protocol MempoolWebSocketDelegate {
    func didReceiveTransaction(_ transaction: [String: Any])
    func didReceiveAddressTransaction(address: String, transaction: [String: Any])
    func didReceiveBlocks(_ blocks: [[String: Any]])
    func didConnect()
    func didDisconnect(error: Error?)
}

// Default implementations so only relevant methods need to be implemented
extension MempoolWebSocketDelegate {
    func didReceiveTransaction(_ transaction: [String: Any]) {}
    func didReceiveAddressTransaction(address: String, transaction: [String: Any]) {}
    func didReceiveBlocks(_ blocks: [[String: Any]]) {}
    func didConnect() {}
    func didDisconnect(error: Error?) {}
}

class MempoolWebSocketClient {
    // Singleton instance
    static let shared = MempoolWebSocketClient()
    
    // WebSocket properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var isPinging = false
    private var pingTimer: Timer?
    
    // Connection URL
    private let webSocketURL = URL(string: "wss://mempool.space/api/v1/ws")!
    
    // Delegate for handling WebSocket events
    var delegate: MempoolWebSocketDelegate?
    
    // Tracked addresses
    private var trackedAddresses = Set<String>()
    
    // Private initializer for singleton
    private init() {
        // Initialize the URL session
        session = URLSession(configuration: .default)
    }
    
    // MARK: - Connection Management
    
    /// Connect to the mempool.space WebSocket API
    func connect() {
        // Only connect if not already connected
        guard !isConnected else {
            print("WebSocket already connected")
            return
        }
        
        // Create and resume the WebSocket task
        webSocketTask = session?.webSocketTask(with: webSocketURL)
        webSocketTask?.resume()
        
        // Start receiving messages
        receiveMessage()
        
        // Start ping timer
        startPingTimer()
        
        isConnected = true
        print("WebSocket connection initiated")
    }
    
    /// Disconnect from the WebSocket
    func disconnect() {
        stopPingTimer()
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        trackedAddresses.removeAll()
        
        print("WebSocket disconnected")
        delegate?.didDisconnect(error: nil)
    }
    
    // MARK: - Message Handling
    
    /// Receive messages from the WebSocket
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    print("Unknown message type received")
                }
                
                // Continue receiving messages if still connected
                if self.isConnected {
                    self.receiveMessage()
                }
                
            case .failure(let error):
                print("Error receiving message: \(error.localizedDescription)")
                self.isConnected = false
                self.delegate?.didDisconnect(error: error)
            }
        }
    }
    
    /// Handle incoming WebSocket messages
    private func handleMessage(_ message: String) {
        guard let data = message.data(using: .utf8) else {
            print("Could not convert message to data")
            return
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("Invalid JSON format")
                return
            }
            
            // Handle different types of messages
            if let type = json["type"] as? String {
                switch type {
                case "block":
                    if let block = json["block"] as? [String: Any] {
                        delegate?.didReceiveBlocks([block])
                    }
                case "mempool-block":
                    // Handle mempool block update
                    break
                case "tx":
                    if let transaction = json["transaction"] as? [String: Any] {
                        delegate?.didReceiveTransaction(transaction)
                    }
                case "address-transaction":
                    if let transaction = json["transaction"] as? [String: Any],
                       let address = json["address"] as? String {
                        delegate?.didReceiveAddressTransaction(address: address, transaction: transaction)
                    }
                default:
                    print("Unknown message type: \(type)")
                }
            }
        } catch {
            print("Error parsing JSON: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Subscription Methods
    
    /// Subscribe to transaction stream
    func subscribeToTransactions() {
        guard isConnected else {
            print("WebSocket not connected")
            return
        }
        
        let message = "{\"action\":\"want\",\"data\":[\"mempool-tx\"]}"
        sendMessage(message)
    }
    
    /// Track a specific address for transactions
    func trackAddress(_ address: String) {
        guard isConnected else {
            print("WebSocket not connected")
            return
        }
        
        let message = "{\"action\":\"track-address\",\"address\":\"\(address)\"}"
        sendMessage(message)
        trackedAddresses.insert(address)
    }
    
    /// Stop tracking an address
    func stopTrackingAddress(_ address: String) {
        guard isConnected, trackedAddresses.contains(address) else {
            return
        }
        
        let message = "{\"action\":\"untrack-address\",\"address\":\"\(address)\"}"
        sendMessage(message)
        trackedAddresses.remove(address)
    }
    
    /// Subscribe to block updates
    func subscribeToBlocks() {
        guard isConnected else {
            print("WebSocket not connected")
            return
        }
        
        let message = "{\"action\":\"want\",\"data\":[\"blocks\"]}"
        sendMessage(message)
    }
    
    // MARK: - Helper Methods
    
    /// Send a message to the WebSocket
    private func sendMessage(_ message: String) {
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
            }
        }
    }
    
    /// Start a timer to send periodic ping messages
    private func startPingTimer() {
        guard pingTimer == nil else { return }
        
        isPinging = true
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    /// Stop the ping timer
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
        isPinging = false
    }
    
    /// Send a ping to keep the connection alive
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("Error sending ping: \(error.localizedDescription)")
                self?.isConnected = false
                self?.delegate?.didDisconnect(error: error)
            }
        }
    }
}