import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// macOS Big Sur-style squircle: content area 824x824 centered on 1024 canvas
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let squircle = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

// Dark terminal-style gradient background
let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.22, alpha: 1.0),
    ending: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.13, alpha: 1.0)
)!
squircle.addClip()
gradient.draw(in: rect, angle: -90)

// Subtle top highlight line
ctx.resetClip()
squircle.addClip()
let highlight = NSBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 3), xRadius: 182, yRadius: 182)
NSColor(white: 1.0, alpha: 0.08).setStroke()
highlight.lineWidth = 6
highlight.stroke()

// Terminal title bar dots
let dotColors = [
    NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.34, alpha: 1),
    NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.18, alpha: 1),
    NSColor(calibratedRed: 0.15, green: 0.79, blue: 0.25, alpha: 1),
]
for (i, c) in dotColors.enumerated() {
    let d = CGRect(x: rect.minX + 70 + CGFloat(i) * 68, y: rect.maxY - 120, width: 40, height: 40)
    c.setFill()
    NSBezierPath(ovalIn: d).fill()
}

// Big sheep emoji in the center (the "herd")
let sheep = "🐑" as NSString
let sheepAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 400)
]
let sheepSize = sheep.size(withAttributes: sheepAttrs)
sheep.draw(
    at: NSPoint(x: (size - sheepSize.width) / 2, y: (size - sheepSize.height) / 2 - 10),
    withAttributes: sheepAttrs
)

// Green shell prompt "❯ herdr" at the bottom
let promptFont = NSFont.monospacedSystemFont(ofSize: 96, weight: .bold)
let prompt = "❯" as NSString
let promptAttrs: [NSAttributedString.Key: Any] = [
    .font: promptFont,
    .foregroundColor: NSColor(calibratedRed: 0.30, green: 0.90, blue: 0.50, alpha: 1),
]
let name = " herdr" as NSString
let nameAttrs: [NSAttributedString.Key: Any] = [
    .font: promptFont,
    .foregroundColor: NSColor(white: 0.92, alpha: 1),
]
let promptSize = prompt.size(withAttributes: promptAttrs)
let nameSize = name.size(withAttributes: nameAttrs)
let totalWidth = promptSize.width + nameSize.width
let baseX = (size - totalWidth) / 2
let baseY = rect.minY + 90
prompt.draw(at: NSPoint(x: baseX, y: baseY), withAttributes: promptAttrs)
name.draw(at: NSPoint(x: baseX + promptSize.width, y: baseY), withAttributes: nameAttrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to encode png")
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
