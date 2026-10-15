// Encode an actual simulator recording. With capture markers, cut waiting and time-compress to 15 seconds.
// Usage: swift scripts/video_to_gif.swift input.mov output.gif [markers.json]
import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

guard (3...4).contains(CommandLine.arguments.count) else { fatalError("Usage: video_to_gif.swift input.mov output.gif [markers.json]") }
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let asset = AVURLAsset(url: input)
let duration = CMTimeGetSeconds(try await asset.load(.duration))
guard duration.isFinite, duration > 1 else { fatalError("Recording has no usable duration") }
let edited = CommandLine.arguments.count == 4
let fps = edited ? 20.0 : 12.5
var times: [Double] = []
if edited {
    let markers = try JSONDecoder().decode([String: Double].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
    guard let photos = markers["PHOTOS"], let second = markers["PHOTO_2"], let third = markers["PHOTO_3"], let returning = markers["RETURN"],
          photos > 0, second > photos + 5, third > second + 5, returning > third else { fatalError("Missing or unordered capture markers") }
    // 7.5s controls/clock + 2s first photo + 1.5s each transition + 2.5s return/navigation.
    let segments: [(Double, Double, Int)] = [(0.1, photos, 150), (photos, photos + 4, 40),
                                           (second - 1, second + 2, 30), (third - 1, third + 2, 30),
                                           (returning, duration - 0.1, 50)]
    for (start, end, frames) in segments {
        let last = min(end, duration - 0.1)
        guard start >= 0, last > start else { fatalError("Capture segment outside video") }
        for index in 0..<frames { times.append(start + (last - start) * Double(index) / Double(frames)) }
    }
} else {
    times = (0..<Int((duration - 0.2) * fps)).map { 0.1 + Double($0) / fps }
}
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: 880, height: 880)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = CMTime(seconds: 0.04, preferredTimescale: 600)
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, times.count, nil) else { fatalError("Cannot open GIF output") }
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for time in times {
    let (image, _) = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps, kCGImagePropertyGIFUnclampedDelayTime: 1 / fps]] as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else { fatalError("GIF encoding failed") }
print("GIF: \(times.count) frames at \(fps) fps; playback \(Double(times.count) / fps)s; source \(duration)s; \(output.path)")
