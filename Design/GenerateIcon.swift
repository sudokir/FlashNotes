import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func render(size: Int, destination: URL) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { fatalError("Unable to create icon bitmap") }

    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    context.setFillColor(CGColor(gray: 0.035, alpha: 1))
    context.addPath(roundedRect(CGRect(x: 62, y: 62, width: 900, height: 900), radius: 214))
    context.fillPath()

    context.saveGState()
    context.translateBy(x: 512, y: 512)
    context.rotate(by: 8 * .pi / 180)
    context.translateBy(x: -512, y: -512)
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.42))
    context.setLineWidth(38)
    context.addPath(roundedRect(CGRect(x: 286, y: 291, width: 453, height: 482), radius: 63))
    context.strokePath()
    context.restoreGState()

    let front = roundedRect(CGRect(x: 262, y: 227, width: 500, height: 466), radius: 63)
    context.setFillColor(CGColor(gray: 0.035, alpha: 1))
    context.addPath(front)
    context.fillPath()
    context.setStrokeColor(CGColor(gray: 1, alpha: 1))
    context.setLineWidth(38)
    context.addPath(front)
    context.strokePath()

    context.setLineWidth(34)
    context.setLineCap(.round)
    for (start, end) in [
        (CGPoint(x: 365, y: 553), CGPoint(x: 659, y: 553)),
        (CGPoint(x: 365, y: 459), CGPoint(x: 659, y: 459)),
        (CGPoint(x: 365, y: 365), CGPoint(x: 553, y: 365)),
    ] {
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }

    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.move(to: CGPoint(x: 616, y: 693))
    context.addLine(to: CGPoint(x: 616, y: 550))
    context.addLine(to: CGPoint(x: 664, y: 582))
    context.addLine(to: CGPoint(x: 712, y: 550))
    context.addLine(to: CGPoint(x: 712, y: 672))
    context.addLine(to: CGPoint(x: 691, y: 693))
    context.closePath()
    context.fillPath()

    guard let image = context.makeImage(),
          let destinationWriter = CGImageDestinationCreateWithURL(
              destination as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil
          ) else { fatalError("Unable to encode icon PNG") }
    CGImageDestinationAddImage(destinationWriter, image, nil)
    guard CGImageDestinationFinalize(destinationWriter) else {
        fatalError("Unable to write icon PNG")
    }
}

for (filename, size) in sizes {
    try render(size: size, destination: outputDirectory.appendingPathComponent(filename))
}
