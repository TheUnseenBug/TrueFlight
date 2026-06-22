//
//  Throw.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import Foundation

// MARK: - Throw Model
struct Throw: Codable, Identifiable {
    var id = UUID()
    let userId: String
    let timestamp: TimeInterval
    let maxSpin: Double      // rad/s
    let maxAccel: Double    // Gs
    let throwType: String
    let speed: Double
    let hyzer: Double       // degrees
    let noseAngle: Double   // degrees
    let spinDirection: String  // "Backhand" or "Forehand"
    let launchAngle: Double    // degrees
    var discMass: Double = 0.175  // kg, configurable per throw
    
    var flightStability: Double {
        // Flight stability based on aerodynamic Magnus effect
        // Units: spin (rad/s), speed (km/h), maxAccel (Gs)
        // Convert speed to m/s for physics calculations
        let speedMs = speed / 3.6
        
        // Disc specifications
        let discDiameter = 0.21  // meters (standard disc)
        let discArea = .pi * (discDiameter/2)*(discDiameter/2)
        let discMass = self.discMass  // Use actual disc mass from this throw
        
        // Magnus lift coefficient based on spin rate
        // Higher spin = more Magnus effect = more lift
        // C_L ranges from 0 (no spin) to ~0.5 (high spin)
        let spinParameter = maxSpin / (2 * speedMs + 0.1)  // Avoid division by zero
        let magnusCoeff = min(0.5, spinParameter * 0.08)  // Physics-based scaling
        
        // Air density at sea level
        let airDensity = 1.225  // kg/m³
        
        // Magnus force: F_magnus = 0.5 * rho * v^2 * A * C_L
        let magforces = 0.5 * airDensity * speedMs * speedMs * discArea * magnusCoeff
        let weight = discMass * 9.81
        
        // Stability ratio: how well Magnus lift counteracts gravitational drop
        // Ratio near 1.0 = stable, < 0.5 = turnover, > 1.5 = overstable
        let stabilityRatio = magforces / (weight + 0.001)
        
        // Wobble: deviation from ideal stable flight (0.8-1.2 range)
        let idealStability = 1.0
        return abs(stabilityRatio - idealStability) * 100
    }
    
    var flightCharacteristic: String {
        // Classify throw based on Magnus effect and acceleration
        let speedMs = speed / 3.6
        let spinParameter = maxSpin / (2 * speedMs + 0.1)
        let spinToAccelRatio = maxSpin / (maxAccel + 0.5)
        
        if spinParameter < 0.3 {
            return "Turnover (Understable)"
        } else if spinParameter > 1.0 && maxAccel > 3.0 {
            return "Overstable (Meathook)"
        } else if spinToAccelRatio > 0.8 && spinToAccelRatio < 1.2 {
            return "Stable (Straight)"
        } else if spinParameter < 0.5 {
            return "Understable"
        } else {
            return "Stable"
        }
    }
    
    var dateFormatted: String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var wobble: Double {
        // Use flightStability as a proxy for wobble magnitude
        flightStability
    }
    
    init(
        userId: String,
        timestamp: TimeInterval,
        maxSpin: Double,
        maxAccel: Double,
        throwType: String,
        speed: Double,
        hyzer: Double,
        noseAngle: Double,
        spinDirection: String,
        launchAngle: Double,
        discMass: Double = 0.175
    ) {
        self.id = UUID()
        self.userId = userId
        self.timestamp = timestamp
        self.maxSpin = maxSpin
        self.maxAccel = maxAccel
        self.throwType = throwType
        self.speed = speed
        self.hyzer = hyzer
        self.noseAngle = noseAngle
        self.spinDirection = spinDirection
        self.launchAngle = launchAngle
        self.discMass = discMass
    }
}
