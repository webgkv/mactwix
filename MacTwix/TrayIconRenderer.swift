import AppKit
import SwiftUI

/// Programmatic menubar icons from the exact TrayIcon.svg path data.
enum TrayIconRenderer {
    /// The "T" path from twix-3.svg, viewBox="8 58 58 76"
    /// Using SVG coordinate space directly, will transform when drawing.
    private static func tPath() -> NSBezierPath {
        let path = NSBezierPath()
        // M13.965 98.684
        path.move(to: NSPoint(x: 13.965, y: 98.684))
        // l-1.528 8.26 → absolute (12.437, 106.944)
        path.line(to: NSPoint(x: 12.437, y: 106.944))
        // 17.042-10.468 → (29.479, 96.476)
        path.line(to: NSPoint(x: 29.479, y: 96.476))
        // c-1.838 8.04-2.818 15.542-3.85 23.464
        // relative curve: cp1=(29.479-1.838, 96.476+8.04) cp2=(29.479-2.818, 96.476+15.542) end=(29.479-3.85, 96.476+23.464)
        path.curve(to: NSPoint(x: 25.629, y: 119.940),
                   controlPoint1: NSPoint(x: 27.641, y: 104.516),
                   controlPoint2: NSPoint(x: 26.661, y: 112.018))
        // l-.943 7.098 → (25.629-0.943, 119.940+7.098) = (24.686, 127.038)
        path.line(to: NSPoint(x: 24.686, y: 127.038))
        // c0 .002 7.844 2.434 7.844 2.434 → end=(24.686+7.844, 127.038+2.434)=(32.530, 129.472)
        path.curve(to: NSPoint(x: 32.530, y: 129.472),
                   controlPoint1: NSPoint(x: 24.686, y: 127.040),
                   controlPoint2: NSPoint(x: 32.530, y: 129.472))
        // l.075-.502 → (32.605, 128.970)
        path.line(to: NSPoint(x: 32.605, y: 128.970))
        // c1.69-11.35 3.29-21.604 5.758-32.146
        // end=(32.605+5.758, 128.970-32.146)=(38.363, 96.824)
        path.curve(to: NSPoint(x: 38.363, y: 96.824),
                   controlPoint1: NSPoint(x: 34.295, y: 117.620),
                   controlPoint2: NSPoint(x: 35.895, y: 107.366))
        // l.09-.383 → (38.453, 96.441)
        path.line(to: NSPoint(x: 38.453, y: 96.441))
        // -5.403-1.784 → (33.050, 94.657)
        path.line(to: NSPoint(x: 33.050, y: 94.657))
        // 26.309-13.812 → (59.359, 80.845)
        path.line(to: NSPoint(x: 59.359, y: 80.845))
        // 1.979-12.105 → (61.338, 68.740)
        path.line(to: NSPoint(x: 61.338, y: 68.740))
        // -47.373 29.944 → (13.965, 98.684)
        path.line(to: NSPoint(x: 13.965, y: 98.684))
        path.close()
        return path
    }

    static func makeIcon(size: CGFloat = 18, withBolt: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            NSColor.black.setFill()

            let svgOriginX: CGFloat = 8
            let svgOriginY: CGFloat = 58
            let svgWidth: CGFloat = 58
            let svgHeight: CGFloat = 76

            let padding: CGFloat = 1.0
            let drawRect = rect.insetBy(dx: padding, dy: padding)

            let scaleX = drawRect.width / svgWidth
            let scaleY = drawRect.height / svgHeight
            let scale = min(scaleX, scaleY)

            let scaledW = svgWidth * scale
            let scaledH = svgHeight * scale
            let offsetX = drawRect.origin.x + (drawRect.width - scaledW) / 2
            let offsetY = drawRect.origin.y + (drawRect.height - scaledH) / 2

            let transform = NSAffineTransform()
            transform.translateX(by: offsetX, yBy: offsetY)
            transform.scaleX(by: scale, yBy: scale)
            transform.translateX(by: -svgOriginX, yBy: -svgOriginY)

            let path = tPath()
            path.transform(using: transform as AffineTransform)
            path.fill()

            if withBolt {
                drawBolt(in: rect)
            }

            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawBolt(in rect: NSRect) {
        let boltH: CGFloat = 8
        let boltW: CGFloat = 5
        let originX = rect.maxX - boltW - 1
        let originY = rect.maxY - boltH - 1

        let path = NSBezierPath()
        path.move(to: NSPoint(x: originX + 3.0, y: originY))
        path.line(to: NSPoint(x: originX + 1.5, y: originY + boltH * 0.5))
        path.line(to: NSPoint(x: originX + 2.8, y: originY + boltH * 0.5))
        path.line(to: NSPoint(x: originX + 2.0, y: originY + boltH))
        path.line(to: NSPoint(x: originX + 4.0, y: originY + boltH * 0.45))
        path.line(to: NSPoint(x: originX + 2.8, y: originY + boltH * 0.45))
        path.line(to: NSPoint(x: originX + 3.5, y: originY))
        path.close()

        NSColor.black.setFill()
        path.fill()
    }
}
