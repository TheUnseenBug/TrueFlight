//
//  QuickStatBox.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

struct QuickStatBox: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
