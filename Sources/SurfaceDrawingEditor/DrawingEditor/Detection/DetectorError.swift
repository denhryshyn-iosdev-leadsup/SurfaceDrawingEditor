//
//  DetectorError.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 26.02.2026.
//

import Foundation

// MARK: - Errors

public enum DetectorError: Error, LocalizedError {
    case modelNotFound(String)
    case modelNotLoaded
    case invalidImage
    case noResults

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let n): return "Model '\(n)' not found"
        case .modelNotLoaded: return "Model not loaded"
        case .invalidImage: return "Invalid image"
        case .noResults: return "No results"
        }
    }
}
