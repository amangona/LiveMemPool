//
//  LiveTransactionsView.swift
//  LiveMemPool
//
//  Created by Abe Mangona on 5/14/25.
//

import SwiftUI
import MempoolKit

struct LiveTransactionItem: Identifiable {
    let id: String // txid
    let timestamp: Date
    let vsize: Int
    let fee: Int
    let feeRate: Double
    let value: Int
}

struct LiveTransactionsView: View {
    @State private var transactions: [LiveTransactionItem] = []
    @State private var isLiveTracking = false
    @State private var lastUpdated: Date? = nil
    @State private var updateTimer: Timer? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var transactionCount = 0
    @State private var seenTransactions = Set<String>()
    @State private var totalFees = 0
    @State private var totalValue = 0
    @State private var autoScroll = true
    @State private var isWebSocketConnected = false
    
    // Display properties
    @State private var sortOption = SortOption.newest
    @State private var filterFeeRate: Double? = nil
    
    // Live tracking timer interval (in seconds)
    let liveTrackingInterval: TimeInterval = 5
    
    // Maximum number of transactions to display
    let maxTransactions = 100
    
    let mempool = Mempool()
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
    
    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case feeRate = "Fee Rate"
        case value = "Value"
    }
    
    // Reference to WebSocket client
    private let webSocketClient = MempoolWebSocketClient.shared
    
    var body: some View {
        VStack {
            // Header with stats
            VStack(spacing: 4) {
                HStack {
                    Toggle("Live Tracking", isOn: $isLiveTracking)
                        .onChange(of: isLiveTracking) { newValue in
                            if newValue {
                                startLiveTracking()
                            } else {
                                stopLiveTracking()
                            }
                        }
                    
                    Spacer()
                    
                    if isLiveTracking, let lastUpdate = lastUpdated {
                        Text("Updated: \(dateFormatter.string(from: lastUpdate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 16) {
                    VStack {
                        Text("Transactions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(transactionCount)")
                            .font(.headline)
                    }
                    
                    VStack {
                        Text("Fees (sat)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(totalFees)")
                            .font(.headline)
                    }
                    
                    VStack {
                        Text("Value (BTC)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBitcoin(totalValue))
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        resetStats()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.blue)
                    }
                }
                
                HStack {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 240)
                    
                    Spacer()
                    
                    Toggle("Auto Scroll", isOn: $autoScroll)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color(.secondarySystemBackground))
            
            if isLoading && transactions.isEmpty {
                ProgressView()
                    .padding()
                Spacer()
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
            } else if transactions.isEmpty {
                VStack {
                    Spacer()
                    
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("No transactions yet.")
                        .foregroundColor(.secondary)
                    
                    Text("Toggle Live Tracking to start monitoring.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    Spacer()
                }
            } else {
                ScrollViewReader { scrollView in
                    List {
                        ForEach(sortedTransactions) { tx in
                            TransactionRow(transaction: tx)
                                .id(tx.id)
                        }
                    }
//                    .onChange(of: transactions) { _ in
//                        if autoScroll && !transactions.isEmpty {
//                            DispatchQueue.main.async {
//                                withAnimation {
//                                    scrollView.scrollTo(transactions.first?.id, anchor: .top)
//                                }
//                            }
//                        }
//                    }
                }
            }
        }
        .navigationTitle("Live Transactions")
        .onAppear {
            if isLiveTracking {
                startLiveTracking()
            }
        }
        .onDisappear {
            stopLiveTracking()
        }
    }
    
    var sortedTransactions: [LiveTransactionItem] {
        switch sortOption {
        case .newest:
            return transactions.sorted(by: { $0.timestamp > $1.timestamp })
        case .feeRate:
            return transactions.sorted(by: { $0.feeRate > $1.feeRate })
        case .value:
            return transactions.sorted(by: { $0.value > $1.value })
        }
    }
    
    private func startLiveTracking() {
        isLoading = true
        
        // Set up WebSocket delegate
        webSocketClient.delegate = self
        
        // Connect to WebSocket if not already connected
        if !isWebSocketConnected {
            webSocketClient.connect()
        }
        
        // Fetch initial data
        Task {
            await fetchRecentTransactions()
            isLoading = false
            
            // Subscribe to transaction updates
            webSocketClient.subscribeToTransactions()
        }
        
        // Create and start a timer as fallback for periodic updates
        // This is a backup in case WebSocket doesn't provide all transactions
        updateTimer = Timer.scheduledTimer(withTimeInterval: liveTrackingInterval, repeats: true) { _ in
            Task {
                await fetchRecentTransactions()
            }
        }
    }
    
    private func stopLiveTracking() {
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Disconnect from WebSocket
        webSocketClient.disconnect()
        isWebSocketConnected = false
    }
    
    private func resetStats() {
        transactionCount = 0
        totalFees = 0
        totalValue = 0
    }
    
    private func fetchRecentTransactions() async {
        do {
            let recentTxs = try await mempool.mempoolRecent()
            
            var newTransactions: [LiveTransactionItem] = []
            
            for tx in recentTxs {
                // Skip if we've already seen this transaction
                if seenTransactions.contains(tx.txid) {
                    continue
                }
                
                // Track new transaction for statistics
                transactionCount += 1
                totalFees += tx.fee ?? 0
                
                // Get transaction value
                let txValue = tx.value ?? 0
                totalValue += txValue
                
                // Create LiveTransactionItem
                let feeRate = Double(tx.fee ?? 0) / Double(tx.vsize ?? 1)
                let item = LiveTransactionItem(
                    id: tx.txid,
                    timestamp: Date(),
                    vsize: tx.vsize ?? 0,
                    fee: tx.fee ?? 0,
                    feeRate: feeRate,
                    value: txValue
                )
                
                newTransactions.append(item)
                seenTransactions.insert(tx.txid)
            }
            
            // Add new transactions and limit to max
            DispatchQueue.main.async {
                self.transactions.insert(contentsOf: newTransactions, at: 0)
                if self.transactions.count > self.maxTransactions {
                    self.transactions = Array(self.transactions.prefix(self.maxTransactions))
                }
                self.lastUpdated = Date()
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func formatBitcoin(_ satoshis: Int) -> String {
        let bitcoinValue = Double(satoshis) / 100_000_000
        return String(format: "%.4f", bitcoinValue)
    }
}

struct TransactionRow: View {
    let transaction: LiveTransactionItem
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(transaction.id.prefix(8)) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(dateFormatter.string(from: transaction.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Value:")
                    .font(.caption)
                
                Spacer()
                
                Text("\(formatBitcoin(transaction.value)) BTC")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("\(transaction.vsize) vB")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Text("\(transaction.fee) sat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("(\(String(format: "%.1f", transaction.feeRate)) sat/vB)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatBitcoin(_ satoshis: Int) -> String {
        let bitcoinValue = Double(satoshis) / 100_000_000
        return String(format: "%.4f", bitcoinValue)
    }
}

#Preview {
    NavigationView {
        LiveTransactionsView()
    }
}

// MARK: - WebSocket Delegate
extension LiveTransactionsView: MempoolWebSocketDelegate {
    func didConnect() {
        isWebSocketConnected = true
    }
    
    func didDisconnect(error: Error?) {
        isWebSocketConnected = false
        
        if let error = error {
            errorMessage = "WebSocket Error: \(error.localizedDescription)"
        }
    }
    
    func didReceiveTransaction(_ transaction: [String: Any]) {
        // Skip if we've already seen this transaction
        guard let txid = transaction["txid"] as? String, 
              !seenTransactions.contains(txid) else { 
            return 
        }
        
        // Extract transaction details
        let vsize = transaction["vsize"] as? Int ?? 0
        let fee = transaction["fee"] as? Int ?? 0
        let valueOut = transaction["valueOut"] as? Int ?? 0
        
        // Calculate fee rate
        let feeRate = vsize > 0 ? Double(fee) / Double(vsize) : 0.0
        
        // Create transaction item
        let newTransaction = LiveTransactionItem(
            id: txid,
            timestamp: Date(),
            vsize: vsize,
            fee: fee, 
            feeRate: feeRate,
            value: valueOut
        )
        
        // Update stats
        transactionCount += 1
        totalFees += fee
        totalValue += valueOut
        
        // Update UI on main thread
        DispatchQueue.main.async {
            // Add new transaction to the list
            self.transactions.insert(newTransaction, at: 0)
            self.seenTransactions.insert(txid)
            
            // Maintain max transaction limit
            if self.transactions.count > self.maxTransactions {
                self.transactions = Array(self.transactions.prefix(self.maxTransactions))
            }
            
            // Update last updated timestamp
            self.lastUpdated = Date()
        }
    }
}
