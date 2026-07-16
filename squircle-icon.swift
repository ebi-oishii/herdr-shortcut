// 正方形のロゴ画像を macOS Big Sur スタイルの squircle アプリアイコン (1024x1024) に加工する。
// 使い方: swift squircle-icon.swift <入力.png> <出力.png>
import AppKit

guard CommandLine.arguments.count == 3,
      let src = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    print("usage: swift squircle-icon.swift <input.png> <output.png>")
    exit(1)
}

let size: CGFloat = 1024
let out = NSImage(size: NSSize(width: size, height: size))
out.lockFocus()

// 1024 キャンバスに 824x824 の squircle（macOS 標準のアイコン余白）
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185).addClip()
src.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)

out.unlockFocus()
let rep = NSBitmapImageRep(data: out.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
