// WindowFeature/WindowAction.swift
// Supported window management actions in MacKit.

import Foundation

/// The discrete window manipulation actions supported by MacKit.
public enum WindowAction: String, Sendable, CaseIterable {
    case snapLeft
    case snapRight
    case maximize
    case center
    case restore

    public var displayTitle: String {
        switch self {
        case .snapLeft: return "Snap Left"
        case .snapRight: return "Snap Right"
        case .maximize: return "Maximize"
        case .center: return "Center"
        case .restore: return "Restore"
        }
    }

    public var systemImageName: String {
        switch self {
        case .snapLeft: return "rectangle.lefthalf.filled"
        case .snapRight: return "rectangle.righthalf.filled"
        case .maximize: return "rectangle.fill"
        case .center: return "rectangle.center.inset.filled"
        case .restore: return "arrow.uturn.backward.circle"
        }
    }
}

