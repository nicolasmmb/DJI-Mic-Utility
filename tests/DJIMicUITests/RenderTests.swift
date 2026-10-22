import AppKit
import SwiftUI
import Testing
@testable import DJIMicUI

@Test @MainActor func rendersPanelSections() throws {
    let model = AppModel.preview
    let content = VStack(alignment: .leading, spacing: 20) {
        ReceiverSectionView(model: model)
        ForEach(model.snapshot.sortedTransmitters) { transmitter in
            TransmitterSectionView(model: model, transmitter: transmitter)
        }
        Divider()
        MoreSettingsView(model: model, isExpanded: .constant(true))
    }
    .padding(16)
    .frame(width: 380, alignment: .leading)

    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    renderer.proposedSize = ProposedViewSize(width: 380, height: 620)

    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        Issue.record("could not render panel sections")
        return
    }

    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("djimic-sections.png")
    try png.write(to: url)
    #expect(png.count > 10_000)
}

@Test @MainActor func rendersMenuBarPanel() throws {
    let model = AppModel.preview
    let renderer = ImageRenderer(content: MenuBarPanel(model: model))
    renderer.scale = 2
    renderer.proposedSize = ProposedViewSize(width: 380, height: 700)

    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        Issue.record("could not render the menu bar panel")
        return
    }

    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("djimic-panel.png")
    try png.write(to: url)
    #expect(png.count > 10_000)
}

@Test @MainActor func rendersHostingViewSnapshot() throws {
    _ = NSApplication.shared
    let model = AppModel.preview
    let view = MenuBarPanel(model: model)
    let hosting = NSHostingView(rootView: view)
    hosting.appearance = NSAppearance(named: .aqua)
    hosting.frame = NSRect(x: 0, y: 0, width: 380, height: 700)

    let window = NSWindow(
        contentRect: hosting.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.appearance = NSAppearance(named: .aqua)
    window.backgroundColor = .windowBackgroundColor
    window.contentView = hosting
    window.layoutIfNeeded()
    hosting.layoutSubtreeIfNeeded()
    hosting.displayIfNeeded()

    guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
        Issue.record("could not create bitmap rep")
        return
    }
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        Issue.record("could not encode snapshot")
        return
    }
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("djimic-hosting.png")
    try png.write(to: url)
    #expect(png.count > 10_000)
}

@Test @MainActor func rendersMoreSettingsSnapshot() throws {
    _ = NSApplication.shared
    let model = AppModel.preview
    let content = MoreSettingsView(model: model, isExpanded: .constant(true))
        .padding(16)
        .frame(width: 380, alignment: .leading)
    let hosting = NSHostingView(rootView: content)
    hosting.appearance = NSAppearance(named: .aqua)
    hosting.frame = NSRect(x: 0, y: 0, width: 380, height: 520)

    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .aqua)
    window.backgroundColor = .windowBackgroundColor
    window.contentView = hosting
    window.layoutIfNeeded()
    hosting.layoutSubtreeIfNeeded()
    hosting.displayIfNeeded()

    guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
        Issue.record("could not create bitmap rep")
        return
    }
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        Issue.record("could not encode snapshot")
        return
    }
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("djimic-more.png")
    try png.write(to: url)
    #expect(png.count > 10_000)
}
