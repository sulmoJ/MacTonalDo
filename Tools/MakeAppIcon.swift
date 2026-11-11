import AppKit
import CoreGraphics
import Foundation

// MacTonalDo 앱 아이콘을 그려 .iconset 폴더로 내보낸다.
// 직접 돌릴 일은 없다. Tools/make-icon.sh 가 컴파일해서 부른다.
//
// 맥 앱 아이콘 격자를 따른다. 1024 캔버스 안에 824 크기의 둥근 사각형, 모서리 185.4.

let canvas: CGFloat = 1024
let bodyInset: CGFloat = 100
let bodySide = canvas - bodyInset * 2
let corner: CGFloat = 185.4

func makeContext(_ pixels: Int) -> CGContext {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let c = CGContext(data: nil, width: pixels, height: pixels,
                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.setAllowsAntialiasing(true)
    c.interpolationQuality = .high
    return c
}

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

let goldTop = rgb(255, 203, 71)
let goldBottom = rgb(240, 138, 12)
let ink = rgb(255, 255, 255)
let inkSoft = rgb(255, 255, 255, 0.92)

func bodyPath() -> CGPath {
    CGPath(roundedRect: CGRect(x: bodyInset, y: bodyInset, width: bodySide, height: bodySide),
           cornerWidth: corner, cornerHeight: corner, transform: nil)
}

func fillBody(_ c: CGContext) {
    c.saveGState()
    c.addPath(bodyPath())
    c.clip()
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let grad = CGGradient(colorsSpace: space, colors: [goldTop, goldBottom] as CFArray,
                          locations: [0, 1])!
    c.drawLinearGradient(grad,
                         start: CGPoint(x: 0, y: canvas - bodyInset),
                         end: CGPoint(x: 0, y: bodyInset),
                         options: [])
    c.restoreGState()
}

/// 위쪽에 아주 옅은 광택 한 겹. 평평해 보이지 않게만 한다.
func addSheen(_ c: CGContext) {
    c.saveGState()
    c.addPath(bodyPath())
    c.clip()
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let grad = CGGradient(colorsSpace: space,
                          colors: [rgb(255, 255, 255, 0.26), rgb(255, 255, 255, 0)] as CFArray,
                          locations: [0, 1])!
    c.drawLinearGradient(grad,
                         start: CGPoint(x: 0, y: canvas - bodyInset),
                         end: CGPoint(x: 0, y: canvas * 0.52),
                         options: [])
    c.restoreGState()
}

/// 체크 표시. 굵고 끝이 둥글다.
func strokeCheck(_ c: CGContext, width: CGFloat, scale: CGFloat, dy: CGFloat) {
    let center = CGPoint(x: canvas / 2, y: canvas / 2 + dy)
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: center.x + x * scale, y: center.y + y * scale)
    }
    let path = CGMutablePath()
    path.move(to: p(-210, 20))
    path.addLine(to: p(-60, -135))
    path.addLine(to: p(215, 170))

    c.saveGState()
    c.setLineCap(.round)
    c.setLineJoin(.round)
    c.setLineWidth(width * scale)
    c.setStrokeColor(ink)
    c.addPath(path)
    c.strokePath()
    c.restoreGState()
}

/// 체크 아래 목록 줄 두 개.
func strokeLines(_ c: CGContext) {
    c.saveGState()
    c.setLineCap(.round)
    c.setLineWidth(56)
    c.setStrokeColor(inkSoft)
    for (i, y) in [CGFloat(380), CGFloat(272)].enumerated() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 332, y: y))
        path.addLine(to: CGPoint(x: i == 0 ? 692 : 568, y: y))
        c.addPath(path)
    }
    c.strokePath()
    c.restoreGState()
}

/// 32px 이하에서는 목록 줄이 뭉개져 얼룩으로만 보인다.
/// 그래서 작은 크기는 체크 하나만 크게 그린다. 애플 기본 아이콘들도 이렇게 한다.
func draw(_ c: CGContext, pixels: Int) {
    fillBody(c)
    addSheen(c)

    if pixels <= 32 {
        strokeCheck(c, width: 128, scale: 1.0, dy: -10)
    } else {
        strokeCheck(c, width: 118, scale: 0.70, dy: 108)
        strokeLines(c)
    }
}

func render(pixels: Int) -> CGImage {
    let c = makeContext(pixels)
    c.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    draw(c, pixels: pixels)
    return c.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("쓰는 법: swift Tools/MakeAppIcon.swift <나갈 폴더>\n".utf8))
    exit(2)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// iconutil 이 기대하는 이름과 크기.
let wanted: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, pixels) in wanted {
    try write(render(pixels: pixels), to: outDir.appendingPathComponent("\(name).png"))
}

print("아이콘 \(wanted.count) 장: \(outDir.path)")
