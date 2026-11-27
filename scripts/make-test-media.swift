// Makes fake camera roll items for the iOS simulator: 60 geotagged photos and 8 geotagged
// videos in Sydney over six days, plus one video with no GPS (to check videos without a
// location still show up). Nothing real is used; the pictures are coloured cards with labels.
//
// Usage:  swift scripts/make-test-media.swift <output-folder>
//         xcrun simctl addmedia booted <output-folder>/*
import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

let out = CommandLine.arguments[1]
// Sydney Opera House-ish
let lat = -33.8568, lon = 151.2153

func image(_ color: NSColor, _ label: String) -> CGImage {
    let w = 1080, h = 1920
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(color.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current = ns
    (label as NSString).draw(at: NSPoint(x: 100, y: 900), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 160), .foregroundColor: NSColor.white])
    return ctx.makeImage()!
}

let palette: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemTeal, .systemBrown]
for i in 0..<60 { let c = palette[i % palette.count]
    let url = URL(fileURLWithPath: "\(out)/p\(i+1).jpg")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    let date = String(format: "2026:03:%02d %02d:%02d:00", 10 + i / 10, 9 + i % 10, i % 60)
    let props: [CFString: Any] = [
        kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: abs(lat), kCGImagePropertyGPSLatitudeRef: "S",
            kCGImagePropertyGPSLongitude: lon, kCGImagePropertyGPSLongitudeRef: "E"],
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: date],
    ]
    CGImageDestinationAddImage(dest, image(c, "PHOTO \(i+1)"), props as CFDictionary)
    CGImageDestinationFinalize(dest)
}

// Geotagged video, 3 s
for v in 0..<8 {
let vurl = URL(fileURLWithPath: "\(out)/v\(v+1).mov")
try? FileManager.default.removeItem(at: vurl)
let writer = try! AVAssetWriter(outputURL: vurl, fileType: .mov)
let loc = AVMutableMetadataItem()
loc.keySpace = .quickTimeMetadata
loc.key = AVMetadataKey.quickTimeMetadataKeyLocationISO6709 as NSString
loc.value = String(format: "%+08.4f%+09.4f/", lat, lon) as NSString
let cd = AVMutableMetadataItem()
cd.keySpace = .quickTimeMetadata
cd.key = AVMetadataKey.quickTimeMetadataKeyCreationDate as NSString
cd.value = String(format: "2026-03-%02dT%02d:30:00+1100", 10 + v * 6 / 8, 10 + v % 8) as NSString
writer.metadata = [loc, cd]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1080, AVVideoHeightKey: 1920])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
let frame = image(.systemPurple, "VIDEO \(v+1)")
for f in 0..<90 {
    while !input.isReadyForMoreMediaData { usleep(1000) }
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, 1080, 1920, kCVPixelFormatType_32ARGB, nil, &pb)
    CVPixelBufferLockBaseAddress(pb!, [])
    let c = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: 1080, height: 1920, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    c.draw(frame, in: CGRect(x: 0, y: 0, width: 1080, height: 1920))
    CVPixelBufferUnlockBaseAddress(pb!, [])
    adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: 30))
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print("done", writer.status.rawValue, writer.error as Any)
}

// One video with no GPS, filmed while photos were being taken nearby.
do {
    let url = URL(fileURLWithPath: "\(out)/no-gps.mov")
    try? FileManager.default.removeItem(at: url)
    let writer = try! AVAssetWriter(outputURL: url, fileType: .mov)
    let created = AVMutableMetadataItem()
    created.keySpace = .quickTimeMetadata
    created.key = AVMetadataKey.quickTimeMetadataKeyCreationDate as NSString
    created.value = "2026-03-12T12:15:00+1100" as NSString
    writer.metadata = [created]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1080, AVVideoHeightKey: 1920])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
    writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
    let frame = image(.systemPink, "NO GPS")
    for f in 0..<90 {
        while !input.isReadyForMoreMediaData { usleep(1000) }
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, 1080, 1920, kCVPixelFormatType_32ARGB, nil, &pb)
        CVPixelBufferLockBaseAddress(pb!, [])
        let c = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: 1080, height: 1920, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        c.draw(frame, in: CGRect(x: 0, y: 0, width: 1080, height: 1920))
        CVPixelBufferUnlockBaseAddress(pb!, [])
        adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: 30))
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    print("no-gps video:", writer.status == .completed ? "ok" : "failed \(String(describing: writer.error))")
}
