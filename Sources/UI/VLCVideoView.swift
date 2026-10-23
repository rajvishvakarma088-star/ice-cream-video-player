import SwiftUI
import AppKit

public struct VLCVideoView: NSViewRepresentable {
    @ObservedObject var player = VLCPlayerEngine.shared
    var onDoubleClick: (() -> Void)?
    var onDropFiles: (([URL]) -> Void)?
    
    public init(onDoubleClick: (() -> Void)? = nil, onDropFiles: (([URL]) -> Void)? = nil) {
        self.onDoubleClick = onDoubleClick
        self.onDropFiles = onDropFiles
    }
    
    public func makeNSView(context: Context) -> VideoHostNSView {
        let hostView = VideoHostNSView()
        hostView.onDoubleClick = onDoubleClick
        hostView.onDropFiles = onDropFiles
        player.attachVideoSurface(to: hostView)
        return hostView
    }
    
    public func updateNSView(_ hostView: VideoHostNSView, context: Context) {
        hostView.onDoubleClick = onDoubleClick
        hostView.onDropFiles = onDropFiles
        player.attachVideoSurface(to: hostView)
    }
    
    public static func dismantleNSView(_ hostView: VideoHostNSView, coordinator: ()) {
        VLCPlayerEngine.shared.detachVideoSurface(from: hostView)
    }
}

public class VideoHostNSView: NSView {
    public var onDoubleClick: (() -> Void)?
    public var onDropFiles: (([URL]) -> Void)?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        registerForDraggedTypes([.fileURL])
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        registerForDraggedTypes([.fileURL])
    }
    
    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        for subview in subviews {
            subview.frame = bounds
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            super.mouseUp(with: event)
        }
    }
    
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !items.isEmpty else {
            return false
        }
        onDropFiles?(items)
        return true
    }
}

public class VideoSurfaceNSView: NSView {
    public var onDoubleClick: (() -> Void)?
    public var onDropFiles: (([URL]) -> Void)?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        registerForDraggedTypes([.fileURL])
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        registerForDraggedTypes([.fileURL])
    }
    
    public override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            super.mouseUp(with: event)
        }
    }
    
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !items.isEmpty else {
            return false
        }
        onDropFiles?(items)
        return true
    }
}
