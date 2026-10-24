import AppKit
import Foundation
let path = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        let body = NSBezierPath(roundedRect: NSRect(x: p * 0.08, y: p * 0.08, width: p * 0.84, height: p * 0.84), xRadius: p * 0.19, yRadius: p * 0.19)
        NSGradient(starting: NSColor(red: 0.44, green: 0.49, blue: 1, alpha: 1), ending: NSColor(red: 0.28, green: 0.33, blue: 0.85, alpha: 1))!.draw(in: body, angle: -90)
        NSColor.white.setStroke()
        let display = NSBezierPath(roundedRect: NSRect(x: p * 0.24, y: p * 0.36, width: p * 0.52, height: p * 0.36), xRadius: p * 0.04, yRadius: p * 0.04)
        display.lineWidth = p * 0.035; display.stroke()
        let stand = NSBezierPath()
        stand.move(to: NSPoint(x: p * 0.5, y: p * 0.35)); stand.line(to: NSPoint(x: p * 0.5, y: p * 0.26))
        stand.move(to: NSPoint(x: p * 0.38, y: p * 0.26)); stand.line(to: NSPoint(x: p * 0.62, y: p * 0.26))
        stand.lineWidth = p * 0.035; stand.lineCapStyle = .round; stand.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(path)/icon_\(size)x\(size)\(suffix).png"))
    }
}
