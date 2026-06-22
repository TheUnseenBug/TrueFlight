//
//  MetricCard.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

struct MetricCard: View {
    let title: String
    let value: Double
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(alignment: .center, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 24, weight: .bold))
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
