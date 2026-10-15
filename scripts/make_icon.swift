import AppKit
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(red: 0.83, green: 0.79, blue: 0.94, alpha: 1).setFill(); NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let tile = NSBezierPath(roundedRect: NSRect(x: 164, y: 164, width: 696, height: 696), xRadius: 150, yRadius: 150)
NSColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1).setFill(); tile.fill()
let house = NSBezierPath(); house.move(to: NSPoint(x: 310, y: 495)); house.line(to: NSPoint(x: 512, y: 685)); house.line(to: NSPoint(x: 714, y: 495)); house.lineWidth = 48; house.lineCapStyle = .round; house.lineJoinStyle = .round
NSColor(red: 0.30, green: 0.24, blue: 0.43, alpha: 1).setStroke(); house.stroke()
let base = NSBezierPath(roundedRect: NSRect(x: 365, y: 335, width: 294, height: 245), xRadius: 28, yRadius: 28)
base.lineWidth = 45; base.stroke()
NSColor(red: 0.30, green: 0.24, blue: 0.43, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 478, y: 320, width: 68, height: 155), xRadius: 20, yRadius: 20).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
