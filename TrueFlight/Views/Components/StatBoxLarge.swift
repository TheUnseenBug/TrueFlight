//
//  StatBoxLarge.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

struct StatBoxLarge: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 8) {
                Text(value)
                    .font(.system(size: 48, weight: .bold))
                Text(unit)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}
