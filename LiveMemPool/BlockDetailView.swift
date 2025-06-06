//
//  BlockDetailView.swift
//  LiveMemPool
//
//  Created by Abe Mangona on 5/14/25.
//

import SwiftUI
import MempoolKit

struct BlockDetailView: View {
    var blockHeight: Int
    @State private var blockInfo: MempoolKit.Block? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    let mempool = Mempool()
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            } else if let block = blockInfo {
                Section(header: Text("Block Information")) {
                    InfoRow(label: "Height", value: "\(block.height)")
                    InfoRow(label: "Hash", value: block.id)
                    InfoRow(label: "Timestamp", value: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(block.timestamp))))
                    InfoRow(label: "Size", value: "\(block.size) bytes")
                    InfoRow(label: "Weight", value: "\(block.weight) WU")
                }
                
                Section(header: Text("Mining Details")) {
                    InfoRow(label: "Miner", value: block.extras?.pool.name ?? "Unknown")
                    InfoRow(label: "Transactions", value: "\(block.tx_count)")
                    if let reward = block.extras?.reward {
                        InfoRow(label: "Reward", value: "\(Double(reward) / 100_000_000) BTC")
                    }
                    if let fee = block.extras?.totalFees {
                        InfoRow(label: "Total Fees", value: "\(Double(fee) / 100_000_000) BTC")
                    }
                }
            }
            
            if let error = errorMessage {
                Section(header: Text("Error")) {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Block #\(blockHeight)")
        .onAppear {
            loadBlockData()
        }
        .refreshable {
            loadBlockData()
        }
    }
    
    private func loadBlockData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // First get the block hash for the current height
                let blockHash = try await mempool.blockHeight(blockHeight: blockHeight)
                
                // Get detailed block information
                blockInfo = try await mempool.block(blockHash: blockHash)
                
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationView {
        BlockDetailView(blockHeight: 730000)
    }
}