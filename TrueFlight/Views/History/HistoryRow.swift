//
//  HistoryRow.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

struct HistoryRow: View {
    let throwRecord: Throw
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(throwRecord.throwType)
                        .fontWeight(.semibold)
                    Text(throwRecord.dateFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            HStack(spacing: 16) {
                Label(String(format: "%.0f km/h", throwRecord.speed), systemImage: "bolt.fill")
                    .font(.caption)
                Label(String(format: "%.0f rpm", throwRecord.maxSpin * 9.5493), systemImage: "tornado")
                    .font(.caption)
                Label(String(format: "%.0f DEG", throwRecord.noseAngle), systemImage: "arrow.up")
                    .font(.caption)
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
