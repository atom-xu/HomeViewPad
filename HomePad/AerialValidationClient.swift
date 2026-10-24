import Foundation
import AVFoundation
import UIKit

@MainActor func makeAerialStore() -> AerialStore {
    #if DEBUG
    let args = ProcessInfo.processInfo.arguments
    if args.contains("--uitesting") && args.contains("--aerial-fixture") {
        let failure = args.contains("--aerial-fixture-failure")
        let slow = args.contains("--aerial-fixture-slow")
        let directory = URL.applicationSupportDirectory.appending(path: "AerialTestData", directoryHint: .isDirectory)
        let suite = "HomePad.AerialValidation"
        let defaults = UserDefaults(suiteName: suite)!
        if args.contains("--aerial-fixture-reset") {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        let client = AerialMediaClient(download: { _, destination, progress in
            if slow { try await Task.sleep(for: .seconds(20)) }
            if failure { throw URLError(.notConnectedToInternet) }
            progress(0.5)
            try await AerialValidationMovie.write(to: destination)
            progress(1)
        }, prepare: AerialMediaClient.live.prepare)
        return AerialStore(defaults: defaults, directory: directory,
                           client: client, validationFixture: true)
    }
    #endif
    return AerialStore()
}

#if DEBUG
/// Synthetic video is never used by normal launches or Release builds.
enum AerialValidationMovie {
    static func write(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 640, AVVideoHeightKey: 360
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 640, kCVPixelBufferHeightKey as String: 360
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
        do {
            for index in 0..<24 {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
                    try await Task.sleep(for: .milliseconds(10))
                }
                var buffer: CVPixelBuffer?
                guard let pool = adaptor.pixelBufferPool,
                      CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else { throw CocoaError(.fileWriteUnknown) }
                CVPixelBufferLockBaseAddress(buffer, [])
                let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 640, height: 360, bitsPerComponent: 8,
                                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
                context?.setFillColor(CGColor(red: 0.05, green: 0.25, blue: 0.3, alpha: 1))
                context?.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
                context?.setFillColor(CGColor(red: 0.35, green: 0.65, blue: 0.6, alpha: 1))
                context?.fill(CGRect(x: index * 28 - 180, y: 0, width: 200, height: 360))
                CVPixelBufferUnlockBaseAddress(buffer, [])
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 8)) else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
            }
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        } catch { writer.cancelWriting(); throw error }
    }
}
#endif
