//
//  Document.swift
//  SwiftDraw
//
//  Created by Marc Prud'hommeaux on 3/31/20.
//  Copyright © 2020 Glimpse I/O. All rights reserved.
//

import Cocoa
import SwiftUI
import DKDrawKit

class Document: DKDrawingDocument, ObservableObject {

    override init() {
        super.init()
    }

    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        true
    }

    override class var autosavesInPlace: Bool {
        true
    }

    /// Returns the first tool controller for this document
    @objc var toolController: DKToolController? {
        self.drawing.controllers.compactMap({ $0 as? DKToolController }).first
    }

    override func makeWindowControllers() {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView().environmentObject(self)

        // Create the window and set the content view.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.contentView = NSHostingView(rootView: contentView)

        let windowController = NSWindowController(window: window)
        self.addWindowController(windowController)
    }

    override func data(ofType typeName: String) throws -> Data {
        try super.data(ofType: typeName)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        try super.read(from: data, ofType: typeName)
    }
}

