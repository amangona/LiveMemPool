//
//  ContentView.swift
//  LiveMemPool
//
//  Created by Abe Mangona on 5/14/25.
//

import SwiftUI
import MempoolKit

struct ContentView: View {
    @State private var currentBlockHeight: Int = 0
    @State private var recommendedFees: RecommendedFees? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedTab = 0
    
    let mempool = Mempool()
    
    init() {
        loadRocketSimConnect()
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NetworkStatusView(
                currentBlockHeight: $currentBlockHeight,
                recommendedFees: $recommendedFees,
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                loadData: loadData
            )
            .tabItem {
                Label("Network", systemImage: "network")
            }
            .tag(0)
            
            NavigationView {
                TransactionSearchView()
            }
            .tabItem {
                Label("Transactions", systemImage: "magnifyingglass")
            }
            .tag(1)
            
            NavigationView {
                AddressTrackerView()
            }
            .tabItem {
                Label("Address", systemImage: "wallet.pass")
            }
            .tag(2)
            
            NavigationView {
                LiveTransactionsView()
            }
            .tabItem {
                Label("Live Feed", systemImage: "arrow.down.doc.fill")
            }
            .tag(3)
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadRocketSimConnect() {
        #if DEBUG
        guard (Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?.load() == true) else {
            print("Failed to load linker framework")
            return
        }
        print("RocketSim Connect successfully linked")
        #endif
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get current block height
                currentBlockHeight = try await mempool.blockTipHeight()
                
                // Get recommended fees
                recommendedFees = try await mempool.recommendedFees()
                
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}

struct NetworkStatusView: View {
    @Binding var currentBlockHeight: Int
    @Binding var recommendedFees: RecommendedFees?
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    var loadData: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Bitcoin Network Status")) {
                    NavigationLink(destination: BlockDetailView(blockHeight: currentBlockHeight)) {
                        VStack(alignment: .leading) {
                            Text("Current Block Height")
                                .font(.headline)
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("\(currentBlockHeight)")
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if let fees = recommendedFees {
                    Section(header: Text("Recommended Fees (sat/vB)")) {
                        FeeInfoRow(priority: "High", blocks: "Next Block", fee: Int(fees.fastestFee))
                        FeeInfoRow(priority: "Medium", blocks: "~3 Blocks", fee: Int(fees.halfHourFee))
                        FeeInfoRow(priority: "Low", blocks: "~1 Hour", fee: Int(fees.hourFee))
                        FeeInfoRow(priority: "Minimum", blocks: "Economy", fee: Int(fees.economyFee))
                        FeeInfoRow(priority: "Baseline", blocks: "Minimum", fee: Int(fees.minimumFee))
                    }
                }
                
                if let error = errorMessage {
                    Section(header: Text("Error")) {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Live Mempool")
            .toolbar {
                Button("Refresh") {
                    loadData()
                }
            }
        }
    }
}

struct FeeInfoRow: View {
    let priority: String
    let blocks: String
    let fee: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(priority)
                    .font(.headline)
                Text(blocks)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(fee)")
                .font(.title3)
                .fontWeight(.bold)
                + Text(" sat/vB")
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
