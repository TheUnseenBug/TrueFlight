//
//  HistoryView.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

struct HistoryView: View {
    let throwsList: [Throw]
    @StateObject private var watchManager = WatchConnectivityManager.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                if throwsList.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Throws Yet")
                            .font(.headline)
                        Text("Start recording throws from your watch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    List(throwsList) { throwRecord in
                        NavigationLink(destination: ThrowDetailView(throwRecord: throwRecord, onDelete: {
                            watchManager.deleteThrow(throwRecord.id)
                        })) {
                            HistoryRow(throwRecord: throwRecord)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("History")
        }
    }
}
