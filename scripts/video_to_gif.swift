// Convert an actual simulator recording to a looping README GIF using Apple frameworks.
// Usage: swift scripts/video_to_gif.swift input.mov output.gif
import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else { fatalError("Usage: video_to_gif.swift input.mov output.gif") }
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let asset = AVURLAsset(url: input)
let duration = CMTimeGetSeconds(try await asset.load(.duration))
guard duration.isFinite, duration > 1 else { fatalError("Recording has no usable duration") }
let fps = 12.5
let count = Int((duration - 0.2) * fps)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: 880, height: 880)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = CMTime(seconds: 0.04, preferredTimescale: 600)
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, count, nil) else { fatalError("Cannot open GIF output") }
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for index in 0..<count {
    let (image, _) = try await generator.image(at: CMTime(seconds: 0.1 + Double(index) / fps, preferredTimescale: 600))
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps, kCGImagePropertyGIFUnclampedDelayTime: 1 / fps]] as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else { fatalError("GIF encoding failed") }
print("GIF: \(count) frames at \(fps) fps; \(duration) seconds; \(output.path)")
