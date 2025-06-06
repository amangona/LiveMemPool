//
//  TransactionSearchView.swift
//  LiveMemPool
//
//  Created by Abe Mangona on 5/14/25.
//

import SwiftUI
import MempoolKit

struct TransactionSearchView: View {
    @State private var searchText = ""
    @State private var transaction: MempoolKit.Transaction? = nil
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
        VStack {
            HStack {
                TextField("Transaction ID (txid)", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: {
                    searchTransaction()
                }) {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(searchText.isEmpty || isLoading)
            }
            .padding()
            
            if isLoading {
                ProgressView()
                    .padding()
            } else if let tx = transaction {
                List {
                    Section(header: Text("Transaction Details")) {
                        InfoRow(label: "TXID", value: tx.txid)
                        InfoRow(label: "Status", value: tx.status.confirmed ? "Confirmed" : "Unconfirmed")
                        if tx.status.confirmed, let blockHeight = tx.status.block_height {
                            InfoRow(label: "Block Height", value: "\(blockHeight)")
                        }
                        InfoRow(label: "Size", value: "\(tx.size) bytes")
                        InfoRow(label: "Weight", value: "\(tx.weight) WU")
                        InfoRow(label: "Fee", value: "\(tx.fee) sats")
                    }
                    
                    Section(header: Text("Inputs")) {
                        ForEach(tx.vin.indices, id: \.self) { index in
                            let input = tx.vin[index]
                            VStack(alignment: .leading) {
                                if let prevout = input.prevout {
                                    Text("From: \(prevout.scriptpubkey_address ?? "Unknown")")
                                        .fontWeight(.medium)
                                    Text("Amount: \(Double(prevout.value ?? 0) / 100_000_000) BTC")
                                        .foregroundColor(.secondary)
                                }
                                Divider()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Section(header: Text("Outputs")) {
                        ForEach(tx.vout.indices, id: \.self) { index in
                            let output = tx.vout[index]
                            VStack(alignment: .leading) {
                                Text("To: \(output.scriptpubkey_address ?? "Unknown")")
                                    .fontWeight(.medium)
                                Text("Amount: \(Double(output.value) / 100_000_000) BTC")
                                    .foregroundColor(.secondary)
                                Divider()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } else if !errorMessage.isNil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .padding()
                    
                    Text(errorMessage!)
                        .foregroundColor(.red)
                }
                .padding()
            } else {
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("Enter a Bitcoin transaction ID to see details")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Spacer()
        }
        .navigationTitle("Transaction Search")
    }
    
    private func searchTransaction() {
        guard !searchText.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        transaction = nil
        
        Task {
            do {
                transaction = try await mempool.transaction(txid: searchText)
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}

extension Optional {
    var isNil: Bool {
        self == nil
    }
}

#Preview {
    NavigationView {
        TransactionSearchView()
    }
}