//
//  AddressTrackerView.swift
//  LiveMemPool
//
//  Created by Abe Mangona on 5/14/25.
//

import SwiftUI
import MempoolKit

struct TransactionListItem: Identifiable {
    let id: String // txid
    let timestamp: Int?
    let isConfirmed: Bool
    let direction: TransactionDirection
    let amount: Int
    
    enum TransactionDirection {
        case incoming, outgoing, selfTransfer
    }
}

struct UTXOListItem: Identifiable {
    let id: String // composite of txid and vout
    let txid: String
    let vout: Int
    let value: Int
    let isConfirmed: Bool
    let blockHeight: Int?
}

struct AddressTrackerView: View {
    @State private var address = ""
    @State private var addressInfo: Address? = nil
    @State private var transactionItems: [TransactionListItem] = []
    @State private var utxoItems: [UTXOListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedTab = 0
    @State private var isLiveTracking = false
    @State private var lastUpdated: Date? = nil
    @State private var updateTimer: Timer? = nil
    @State private var recentTransactions = Set<String>()
    @State private var newTransactionCount = 0
    @State private var isWebSocketConnected = false
    
    let mempool = Mempool()
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Live tracking timer interval (in seconds)
    let liveTrackingInterval: TimeInterval = 30
    
    // Reference to WebSocket client
    private let webSocketClient = MempoolWebSocketClient.shared
    
    var body: some View {
        VStack {
            // Address Input Field
            HStack {
                TextField("Bitcoin Address", text: $address)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .disabled(isLiveTracking)
                
                Button(action: {
                    lookupAddress()
                }) {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(address.isEmpty || isLoading || isLiveTracking)
            }
            .padding(.horizontal)
            
            if addressInfo != nil {
                // Live tracking toggle
                HStack {
                    Toggle("Live Tracking", isOn: $isLiveTracking)
                        .onChange(of: isLiveTracking) { newValue in
                            if newValue {
                                startLiveTracking()
                            } else {
                                stopLiveTracking()
                            }
                        }
                    
                    if isLiveTracking, let lastUpdate = lastUpdated {
                        Spacer()
                        
                        Text("Updated: \(dateFormatter.string(from: lastUpdate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if newTransactionCount > 0 {
                        Spacer()
                        
                        Button(action: {
                            newTransactionCount = 0
                        }) {
                            Text("\(newTransactionCount) new transaction\(newTransactionCount == 1 ? "" : "s")")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            if isLoading {
                ProgressView()
                    .padding()
                Spacer()
            } else if addressInfo != nil {
                // Address Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Address Summary")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Transactions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            let chainTxCount = addressInfo?.chain_stats.tx_count ?? 0
                            let mempoolTxCount = addressInfo?.mempool_stats.tx_count ?? 0
                            let totalTxCount = chainTxCount + mempoolTxCount
                            
                            Text("\(totalTxCount)")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Final Balance")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            let chainFunded = addressInfo?.chain_stats.funded_txo_sum ?? 0
                            let chainSpent = addressInfo?.chain_stats.spent_txo_sum ?? 0
                            let mempoolFunded = addressInfo?.mempool_stats.funded_txo_sum ?? 0
                            let mempoolSpent = addressInfo?.mempool_stats.spent_txo_sum ?? 0
                            let totalBalance = chainFunded - chainSpent + mempoolFunded - mempoolSpent
                            
                            Text("\(formatBitcoin(totalBalance)) BTC")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Tab view for Transactions and UTXOs
                Picker("", selection: $selectedTab) {
                    Text("Transactions").tag(0)
                    Text("UTXOs").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedTab == 0 {
                    // Transactions List
                    if transactionItems.isEmpty {
                        Text("No transactions found")
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    } else {
                        List {
                            ForEach(transactionItems) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.id)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        Spacer()
                                        
                                        Text(item.isConfirmed ? "Confirmed" : "Unconfirmed")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(item.isConfirmed ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    
                                    HStack {
                                        switch item.direction {
                                        case .incoming:
                                            Image(systemName: "arrow.down")
                                                .foregroundColor(.green)
                                        case .outgoing:
                                            Image(systemName: "arrow.up")
                                                .foregroundColor(.red)
                                        case .selfTransfer:
                                            Image(systemName: "arrow.right.arrow.left")
                                                .foregroundColor(.purple)
                                        }
                                        
                                        Text((item.direction == .incoming ? "+" : "") + formatBitcoin(item.amount))
                                            .fontWeight(.bold)
                                            .foregroundColor(item.direction == .incoming ? .green : (item.direction == .outgoing ? .red : .purple))
                                        
                                        Spacer()
                                        
                                        if let timestamp = item.timestamp {
                                            Text(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp))))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Pending")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else {
                    // UTXOs List
                    if utxoItems.isEmpty {
                        Text("No UTXOs found")
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    } else {
                        List {
                            ForEach(utxoItems) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.txid)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("vout: \(item.vout)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text(formatBitcoin(item.value))
                                            .fontWeight(.bold)
                                        Text("BTC")
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        if item.isConfirmed, let height = item.blockHeight {
                                            Text("Conf: \(height)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Unconfirmed")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .padding()
                    
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Spacer()
                }
                .padding()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "bitcoinsign.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("Enter a Bitcoin address to see transactions and UTXOs")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Text("Example addresses:")
                        .font(.headline)
                        .padding(.top)
                    
                    Button(action: {
                        address = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
                        lookupAddress()
                    }) {
                        Text("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        address = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
                        lookupAddress()
                    }) {
                        Text("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Address Tracker")
        .onDisappear {
            // Clean up timer when view disappears
            stopLiveTracking()
        }
    }
    
    private func lookupAddress() {
        guard !address.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        addressInfo = nil
        transactionItems = []
        utxoItems = []
        recentTransactions = []
        newTransactionCount = 0
        
        Task {
            do {
                try await fetchAddressData(isInitialLoad: true)
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func startLiveTracking() {
        guard !address.isEmpty, addressInfo != nil else {
            isLiveTracking = false
            return
        }
        
        // Store current transaction IDs for comparison
        recentTransactions = Set(transactionItems.map { $0.id })
        
        // Set up WebSocket delegate
        webSocketClient.delegate = self
        
        // Connect to WebSocket if not already connected
        if !isWebSocketConnected {
            webSocketClient.connect()
        }
        
        // Create and start a timer for periodic updates (as backup)
        updateTimer = Timer.scheduledTimer(withTimeInterval: liveTrackingInterval, repeats: true) { _ in
            Task {
                await updateAddressData()
            }
        }
        
        // Initial update immediately when tracking starts
        Task {
            await updateAddressData()
            
            // After initial data load, subscribe to address updates via WebSocket
            webSocketClient.trackAddress(address)
        }
    }
    
    private func stopLiveTracking() {
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Stop tracking the address
        if !address.isEmpty {
            webSocketClient.stopTrackingAddress(address)
        }
        
        // Disconnect only if we're not using it elsewhere
        // In a real app, you might want to check if other views are using it
        webSocketClient.disconnect()
        isWebSocketConnected = false
    }
    
    private func updateAddressData() async {
        guard !address.isEmpty else { return }
        
        do {
            try await fetchAddressData(isInitialLoad: false)
            lastUpdated = Date()
        } catch {
            errorMessage = "Update error: \(error.localizedDescription)"
        }
    }
    
    private func fetchAddressData(isInitialLoad: Bool) async throws {
        // Fetch address info
        let newAddressInfo = try await mempool.address(address: address)
        
        // Only update addressInfo on initial load or when it changes
        if isInitialLoad || self.addressInfo?.chain_stats.tx_count != newAddressInfo.chain_stats.tx_count ||
           self.addressInfo?.mempool_stats.tx_count != newAddressInfo.mempool_stats.tx_count {
            self.addressInfo = newAddressInfo
        }
        
        // Fetch transactions
        let addressTxs = try await mempool.addressTXS(address: address)
        
        var newTransactions: [TransactionListItem] = []
        var foundNewTransactions = false
        
        // Process transactions
        for tx in addressTxs {
            // Check if this is a new transaction we haven't seen before
            let isNewTransaction = !recentTransactions.contains(tx.txid)
            
            if isNewTransaction && !isInitialLoad {
                foundNewTransactions = true
                newTransactionCount += 1
            }
            
            // Calculate if this transaction is sending or receiving for this address
            let sending = tx.vin.contains { input in
                if let prevout = input.prevout {
                    return prevout.scriptpubkey_address == address
                }
                return false
            }
            
            let receiving = tx.vout.contains { output in
                return output.scriptpubkey_address == address
            }
            
            // Determine direction
            let direction: TransactionListItem.TransactionDirection
            if sending && receiving {
                direction = .selfTransfer
            } else if sending {
                direction = .outgoing
            } else {
                direction = .incoming
            }
            
            // Calculate amount change for this address
            var amountReceived: Int = 0
            for output in tx.vout {
                if output.scriptpubkey_address == address {
                    amountReceived += output.value
                }
            }
            
            var amountSent: Int = 0
            for input in tx.vin {
                if let prevout = input.prevout, prevout.scriptpubkey_address == address {
                    amountSent += prevout.value ?? 0
                }
            }
            
            let netAmount = direction == .incoming ? amountReceived : (direction == .outgoing ? amountSent : abs(amountReceived - amountSent))
            
            // Create transaction item
            let item = TransactionListItem(
                id: tx.txid,
                timestamp: tx.status.block_time,
                isConfirmed: tx.status.confirmed,
                direction: direction,
                amount: netAmount
            )
            
            // Add to new transactions list and recent transactions set
            newTransactions.append(item)
            recentTransactions.insert(tx.txid)
        }
        
        // Update the transactions list
        transactionItems = newTransactions
        
        // Fetch UTXOs
        let addressUTXOs = try await mempool.addressUTXOs(address: address)
        
        var newUtxoItems: [UTXOListItem] = []
        
        // Process UTXOs
        for utxo in addressUTXOs {
            let item = UTXOListItem(
                id: "\(utxo.txid):\(utxo.vout)",
                txid: utxo.txid,
                vout: utxo.vout,
                value: utxo.value,
                isConfirmed: utxo.status.confirmed,
                blockHeight: utxo.status.block_height
            )
            
            newUtxoItems.append(item)
        }
        
        // Update the UTXOs list
        utxoItems = newUtxoItems
    }
    
    private func formatBitcoin(_ satoshis: Int) -> String {
        let bitcoinValue = Double(satoshis) / 100_000_000
        
        if bitcoinValue == 0 {
            return "0.0"
        } else if bitcoinValue < 0.000001 {
            return String(format: "%.8f", bitcoinValue)
        } else if bitcoinValue < 0.001 {
            return String(format: "%.6f", bitcoinValue)
        } else if bitcoinValue < 1 {
            return String(format: "%.4f", bitcoinValue)
        } else {
            return String(format: "%.2f", bitcoinValue)
        }
    }
}

#Preview {
    NavigationView {
        AddressTrackerView()
    }
}

// MARK: - WebSocket Delegate
extension AddressTrackerView: MempoolWebSocketDelegate {
    func didConnect() {
        isWebSocketConnected = true
    }
    
    func didDisconnect(error: Error?) {
        isWebSocketConnected = false
        
        if let error = error {
            errorMessage = "WebSocket Error: \(error.localizedDescription)"
        }
    }
    
    func didReceiveAddressTransaction(address: String, transaction: [String: Any]) {
        // Make sure this is the address we're tracking
        guard address == self.address else { return }
        
        // Extract basic transaction data
        guard let txid = transaction["txid"] as? String else { return }
        
        // Skip if we've already seen this transaction
        if recentTransactions.contains(txid) {
            return
        }
        
        // Increment new transaction counter
        DispatchQueue.main.async {
            self.newTransactionCount += 1
            self.lastUpdated = Date()
        }
        
        // Fetch full transaction details and update UI
        Task {
            do {
                // Fetch the full transaction details
                let fullTx = try await mempool.transaction(txid: txid)
                
                // Process the transaction
                let newTransaction = processTransaction(fullTx)
                
                // Add to recent transactions
                recentTransactions.insert(txid)
                
                // Update UI
                DispatchQueue.main.async {
                    // Add to transaction list
                    self.transactionItems.insert(newTransaction, at: 0)
                    
                    // Also update UTXOs
                    Task {
                        do {
                            // Refresh UTXOs
                            let addressUTXOs = try await mempool.addressUTXOs(address: self.address)
                            
                            var newUtxoItems: [UTXOListItem] = []
                            
                            // Process UTXOs
                            for utxo in addressUTXOs {
                                let item = UTXOListItem(
                                    id: "\(utxo.txid):\(utxo.vout)",
                                    txid: utxo.txid,
                                    vout: utxo.vout,
                                    value: utxo.value,
                                    isConfirmed: utxo.status.confirmed,
                                    blockHeight: utxo.status.block_height
                                )
                                
                                newUtxoItems.append(item)
                            }
                            
                            // Update the UTXOs list
                            DispatchQueue.main.async {
                                self.utxoItems = newUtxoItems
                            }
                        } catch {
                            print("Error updating UTXOs: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                print("Error fetching full transaction: \(error.localizedDescription)")
            }
        }
    }
    
    private func processTransaction(_ tx: MempoolKit.Transaction) -> TransactionListItem {
        // Calculate if this transaction is sending or receiving for this address
        let sending = tx.vin.contains { input in
            if let prevout = input.prevout {
                return prevout.scriptpubkey_address == address
            }
            return false
        }
        
        let receiving = tx.vout.contains { output in
            return output.scriptpubkey_address == address
        }
        
        // Determine direction
        let direction: TransactionListItem.TransactionDirection
        if sending && receiving {
            direction = .selfTransfer
        } else if sending {
            direction = .outgoing
        } else {
            direction = .incoming
        }
        
        // Calculate amount change for this address
        var amountReceived: Int = 0
        for output in tx.vout {
            if output.scriptpubkey_address == address {
                amountReceived += output.value
            }
        }
        
        var amountSent: Int = 0
        for input in tx.vin {
            if let prevout = input.prevout, prevout.scriptpubkey_address == address {
                amountSent += prevout.value ?? 0
            }
        }
        
        let netAmount = direction == .incoming ? amountReceived : (direction == .outgoing ? amountSent : abs(amountReceived - amountSent))
        
        // Create transaction item
        return TransactionListItem(
            id: tx.txid,
            timestamp: tx.status.block_time,
            isConfirmed: tx.status.confirmed,
            direction: direction,
            amount: netAmount
        )
    }
}