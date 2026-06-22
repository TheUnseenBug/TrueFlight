//
//  ThrowDetailView.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

struct ThrowDetailView: View {
    let throwRecord: Throw
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirm = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(throwRecord.throwType)
                            .font(.system(size: 32, weight: .bold))
                        Text(throwRecord.dateFormatted)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Main Stats Card
                    VStack(spacing: 16) {
                        // Speed and Spin
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Speed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(alignment: .center, spacing: 4) {
                                        Text(String(format: "%.0f", throwRecord.speed))
                                            .font(.system(size: 44, weight: .bold))
                                        Text("km/h")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Spin")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(alignment: .center, spacing: 4) {
                                        Text(String(format: "%.0f", throwRecord.maxSpin * 9.5493))
                                            .font(.system(size: 32, weight: .bold))
                                        Text("rpm")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Launch, Nose, Hyzer, and Wobble
                        HStack {
                             VStack(alignment: .leading, spacing: 4) {
                                Text("Launch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .center, spacing: 4) {
                                    Text(String(format: "%.0f", throwRecord.launchAngle))
                                        .font(.system(size: 28, weight: .bold))
                                    Text("°")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nose")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .center, spacing: 4) {
                                    Text(String(format: "%.0f", throwRecord.noseAngle))
                                        .font(.system(size: 28, weight: .bold))
                                    Text("°")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hyzer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .center, spacing: 4) {
                                    Text(String(format: "%.0f", throwRecord.hyzer))
                                        .font(.system(size: 28, weight: .bold))
                                    Text("°")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wobble")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .center, spacing: 4) {
                                    Text(String(format: "%.1f", throwRecord.wobble))
                                        .font(.system(size: 28, weight: .bold))
                                    Text("rad/s")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                    
                    // Delete Button
                    Button(action: { showDeleteConfirm = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Throw")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundStyle(.white)
                        .background(Color(.systemRed))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .confirmationDialog("Delete Throw", isPresented: $showDeleteConfirm) {
                        Button("Delete", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    } message: {
                        Text("Are you sure you want to delete this throw? This cannot be undone.")
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Throw Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
