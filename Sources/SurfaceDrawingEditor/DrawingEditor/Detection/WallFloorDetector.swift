//
//  WallFloorDetector.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 17.02.2026.
//

import CoreML
import Vision
import UIKit
import Accelerate

// MARK: - Detector
final class WallFloorDetector {

    private let modelSize = CGSize(width: 1024, height: 1024)
    private var request: VNCoreMLRequest?
    private let minCoverage: Float = 0.01

    init(modelFileName: String = "segformer_b2_ade20k") throws {
        guard let url = Bundle.main.url(forResource: modelFileName, withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: modelFileName, withExtension: "mlpackage") else {
            throw DetectorError.modelNotFound(modelFileName)
        }

        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        let model = try MLModel(contentsOf: url, configuration: config)
        let visionModel = try VNCoreMLModel(for: model)
        let req = VNCoreMLRequest(model: visionModel)
        req.imageCropAndScaleOption = .scaleFill
        self.request = req
        //print("✅ Loaded: \(modelFileName)")
    }

    func detect(image: UIImage) async throws -> [DetectedSurface] {
        let resized = image.resizedTo(modelSize)
        guard let cgImg = resized.cgImage else { throw DetectorError.invalidImage }
        let segMap = try await runModel(on: cgImg)
        return extractSurfaces(from: segMap)
    }

    private func runModel(on cgImage: CGImage) async throws -> MLMultiArray {
        guard let request = request else { throw DetectorError.modelNotLoaded }

        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                guard let results = request.results, !results.isEmpty else {
                    continuation.resume(throwing: DetectorError.noResults)
                    return
                }
                for result in results {
                    if let obs = result as? VNCoreMLFeatureValueObservation,
                       let arr = obs.featureValue.multiArrayValue {
                        //print("📊 Output: \(obs.featureName) \(arr.shape)")
                        continuation.resume(returning: arr)
                        return
                    }
                }
                continuation.resume(throwing: DetectorError.noResults)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func extractSurfaces(from output: MLMultiArray) -> [DetectedSurface] {
        let shape = output.shape.map { $0.intValue }
        let w: Int, h: Int, numCls: Int, isLogits: Bool

        switch shape.count {
        case 4: numCls = shape[1]; h = shape[2]; w = shape[3]; isLogits = true
        case 3: numCls = 1; h = shape[1]; w = shape[2]; isLogits = false
        case 2: numCls = 1; h = shape[0]; w = shape[1]; isLogits = false
        default: return []
        }

        let totalPx = w * h
        let ptr = output.dataPointer.bindMemory(to: Float32.self, capacity: output.count)

        // Argmax map
        var classMap = [Int32](repeating: 0, count: totalPx)
        if isLogits {
            let stride = totalPx
            DispatchQueue.concurrentPerform(iterations: h) { row in
                for col in 0..<w {
                    let px = row * w + col
                    var maxV: Float32 = -Float.infinity, maxC: Int32 = 0
                    for c in 0..<numCls {
                        let v = ptr[c * stride + px]
                        if v > maxV { maxV = v; maxC = Int32(c) }
                    }
                    classMap[px] = maxC
                }
            }
        } else {
            for i in 0..<totalPx { classMap[i] = Int32(ptr[i]) }
        }

        // Ищем поверхности - сохраняем только индексы
        var result: [DetectedSurface] = []
        for surface in SurfaceType.allCases {
            let indices = Set(surface.ade20kIndices)
            var maskIdx: [Int] = []
            maskIdx.reserveCapacity(totalPx / 10)  // оценка

            for i in 0..<totalPx {
                if indices.contains(Int(classMap[i])) {
                    maskIdx.append(i)
                }
            }

            let coverage = Float(maskIdx.count) / Float(totalPx)
            guard coverage >= minCoverage else { continue }

            result.append(DetectedSurface(
                type: surface,
                maskIndices: maskIdx,
                maskWidth: w,
                maskHeight: h,
                coveragePercent: coverage * 100
            ))
            //print("✅ \(surface.displayName): \(String(format: "%.1f", coverage*100))% (\(maskIdx.count) px)")
        }

        return result
    }
}
