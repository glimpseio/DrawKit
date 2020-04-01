//
//  ContentView.swift
//  SwiftDraw
//
//  Created by Marc Prud'hommeaux on 3/31/20.
//  Copyright © 2020 Glimpse I/O. All rights reserved.
//

import DKDrawKit
import Combine
import SwiftUI

struct ContentView: View {
    var body: some View {
        HSplitView {
            // TODO: outline
            VStack(spacing: 0) {
                ToolButtons()
                Divider()
                DrawingView()
            }
            InspectorView()
                .frame(width: 250)
        }
    }
}

extension View {

    func onNotification(name: NSNotification.Name, perform action: @escaping (Any?) -> ()) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: name)) {
            action($0.object)
        }
    }

    func inspectorGroup<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        GroupBox(label: Text(title).font(.headline)) {
            VStack {
                content()
            }
        }.padding()
    }
}


extension DKDrawing {
    /// The selection for the current active drawing layer
    @objc var selection: Set<DKDrawableObject> {
        get { ((activeLayer as? DKObjectDrawingLayer)?.selection).faulted }
        set { (activeLayer as? DKObjectDrawingLayer)?.selection = newValue }
    }
}

extension Set {
    subscript<T>(any path: ReferenceWritableKeyPath<Element, T>, default defaultValue: T) -> T {
        get {
            self.map({ $0[keyPath: path] }).first ?? defaultValue
        }

        set {
            for i in self.indices {
                self[i][keyPath: path] = newValue
            }
        }
    }
}

struct DrawableSelectionView : View {
    @Binding var drawing: DKDrawing
    var selection: Binding<Set<DKDrawableObject>> { $drawing.selection }
    var selectionAngles: Binding<CGFloat> { selection[any: \.angle, default: 1] }

    @State private var updateView = 0 // hack to force update on events

    var body: some View {
        inspectorGroup("Selection") {
            Text("\(selection.wrappedValue.count) items selected")

            if !selection.wrappedValue.isEmpty {
                Slider(value: selectionAngles, in: -(.pi)...(.pi))
            }
        }
        .onNotification(name: .dkLayerSelectionDidChange) { _ in
            self.updateView += 1
        }
        .onReceive(drawing.publisher(for: \.selection)) { value in
            self.updateView += 1
        }
    }


}

struct DrawingInspectorView : View {
    @Binding var drawing: DKDrawing
    @State private var updateView = 0 // hack to force update on events

    var body: some View {
        Group {
            inspectorGroup("Size") {
                inspectorRow("Width", path: \.drawingSize) {
                    TextField("Width", value: $drawing.drawingSize.width, formatter: NumberFormatter())
                    Stepper("", value: $drawing.drawingSize.width, in: 0...(.infinity))
                }

                inspectorRow("Height", path: \.drawingSize) {
                    TextField("Height", value: $drawing.drawingSize.height, formatter: NumberFormatter())
                    Stepper("", value: $drawing.drawingSize.height, in: 0...(.infinity))
                }
            }

            inspectorGroup("Snapping") {
                Group {
                    inspectorRow(nil, path: \.snapsToGrid) {
                        Toggle("Snap to Grid", isOn: $drawing.snapsToGrid)
                    }

                    inspectorRow(nil, path: \.snapsToGuides) {
                        Toggle("Snap to Guides", isOn: $drawing.snapsToGuides)
                    }
                }
            }

            DrawableSelectionView(drawing: $drawing)
                .onReceive(drawing.publisher(for: \.selection)) { value in
                    // print("##### selection changed")
//                    self.updateView += 1 // force a view update when the keypath changes
                }

            Button("Clear Selection") {
                print("selection", self.drawing.selection)
                self.drawing.selection.removeAll() // clear the selection
            }
        }
    }

    func inspectorRow<Value, Content: View>(_ label: LocalizedStringKey?, path keyPath: KeyPath<DKDrawing, Value>, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            label.flatMap { label in
                Text(label).frame(width: 70, alignment: .trailing)
            }
            content()
        }
        .onReceive(drawing.publisher(for: keyPath)) { value in
            self.updateView += 1 // force a view update when the keypath changes
        }
    }
}

struct InspectorView : View {
    @EnvironmentObject var doc: Document
    @State var text: String = "Value"

    var body: some View {
        ScrollView {
            DrawingInspectorView(drawing: $doc.drawing)
        }
    }
}

struct ToolButtons : View {
    @EnvironmentObject var doc: Document
    @State var toolController: DKToolController? = nil

    var body: some View {
        HStack {
            Group {
                actionButton("􀋒", action: .standardSelection)
            }
            Divider()
            Group {
                actionButton("􀂒", action: .standardRectangle)
                actionButton("􀝶", action: .standardRoundRectangle)
                actionButton("􀀀", action: .standardOval)
                actionButton("􀝝", action: .standardRegularPolygonPath)
                actionButton("􀌤", action: .standardSpeechBalloon)
            }
            Divider()
            Group {
                actionButton("􀋥", action: .standardStraightLinePath)
                actionButton("􀅶", action: .standardTextBox)
                actionButton("􀈐", action: .standardFreehandPath)
            }


//            actionButton("…", action: .standardRoundEndedRectangle)
//            actionButton("…", action: .standardBezierPath)
//            actionButton("…", action: .standardIrregularPolygonPath)
//            actionButton("…", action: .standardArc)
//            actionButton("…", action: .standardWedge)
//            actionButton("…", action: .standardRing)
//            actionButton("…", action: .standardTextPath)
//            actionButton("…", action: .standardAddPathPoint)
//            actionButton("…", action: .standardDeletePathPoint)
//            actionButton("…", action: .standardDeletePathSegment)
//            actionButton("…", action: .standardZoom)
        }
        .frame(height: 30)
        .onNotification(name: .dkDidChangeTool) { obj in
            self.toolController = nil // force an update
            self.toolController = obj as? DKToolController
        }
    }

    func actionButton(_ icon: String, action name: DKToolName) -> some View {
        Button(icon) { self.selectTool(name) }
            .font(.headline)
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            .foregroundColor(toolController?.drawingTool.registeredName == name ? Color.accentColor : Color.primary) // highlight the selected tool
    }

    func selectTool(_ name: DKToolName) {
        guard let tool = DKToolRegistry.shared.drawingTool(withName: name) else {
            return print("could not find tool", name)
        }
        doc.toolController?.drawingTool = tool
    }
}

struct DrawingView : NSViewRepresentable {
    @EnvironmentObject var doc: Document

    typealias NSViewType = NSScrollView

    func makeNSView(context: Context) -> NSViewType {
        context.coordinator.setup(document: doc)

        let view = context.coordinator.drawingView

        let scrollView = NSScrollView()
        scrollView.documentView = view
        scrollView.allowsMagnification = true

        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true

        scrollView.backgroundColor = .clear

        view.awakeFromNib() // set up the rulers

        return scrollView
    }

    func updateNSView(_ view: NSViewType, context: Context) {
    }

    static func dismantleNSView(_ view: NSViewType, coordinator: Coordinator) {
        coordinator.drawingView.drawing?.removeController(coordinator.toolController)
        coordinator.cancellables.removeAll() // remove all notifications
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        let drawingView = DKDrawingView()
        lazy var toolController = DKToolController(view: drawingView)
        var cancellables = Set<AnyCancellable>()

        /// Set the current tool to the selection tool
        func setSelectionTool() {
            toolController.setDrawingToolWithName(.standardSelection)
        }

        /// Associates the view controller with the document.
        func setup(document doc: Document) {
            doc.drawing.addController(toolController)
            doc.drawing.knobs = .standardKnobs()

            func addNotification<T>(name: NSNotification.Name, receiveValue: @escaping (T, UserInfo) -> ()) {
                NotificationCenter.default.publisher(for: name).sink(receiveValue: { note in
                    guard let obj = note.object as? T else {
                        print(#function, "notification", name, "argument expected", T.self, "received", note.object as Any)
                        return
                    }
                    receiveValue(obj, note.userInfo ?? [:])
                }).store(in: &cancellables)
            }

            addNotification(name: .dkCategoryManagerDidAddKeyToCategory, receiveValue: categoryManagerDidAddKeyToCategory)
            addNotification(name: .dkCategoryManagerDidAddObject, receiveValue: categoryManagerDidAddObject)
            addNotification(name: .dkCategoryManagerDidCreateNewCategory, receiveValue: categoryManagerDidCreateNewCategory)
            addNotification(name: .dkCategoryManagerDidDeleteCategory, receiveValue: categoryManagerDidDeleteCategory)
            addNotification(name: .dkCategoryManagerDidRemoveKeyFromCategory, receiveValue: categoryManagerDidRemoveKeyFromCategory)
            addNotification(name: .dkCategoryManagerDidRemoveObject, receiveValue: categoryManagerDidRemoveObject)
            addNotification(name: .dkCategoryManagerDidRenameCategory, receiveValue: categoryManagerDidRenameCategory)
            addNotification(name: .dkCategoryManagerWillAddKeyToCategory, receiveValue: categoryManagerWillAddKeyToCategory)
            addNotification(name: .dkCategoryManagerWillAddObject, receiveValue: categoryManagerWillAddObject)
            addNotification(name: .dkCategoryManagerWillCreateNewCategory, receiveValue: categoryManagerWillCreateNewCategory)
            addNotification(name: .dkCategoryManagerWillDeleteCategory, receiveValue: categoryManagerWillDeleteCategory)
            addNotification(name: .dkCategoryManagerWillRemoveKeyFromCategory, receiveValue: categoryManagerWillRemoveKeyFromCategory)
            addNotification(name: .dkCategoryManagerWillRemoveObject, receiveValue: categoryManagerWillRemoveObject)
            addNotification(name: .dkDidChangeToolAutoRevertState, receiveValue: didChangeToolAutoRevertState)
            addNotification(name: .dkDidChangeTool, receiveValue: didChangeTool)
            addNotification(name: .dkDrawableDidChange, receiveValue: drawableDidChange)
            addNotification(name: .dkDrawableDoubleClick, receiveValue: drawableDoubleClick)
            addNotification(name: .dkDrawableStyleWasAttached, receiveValue: drawableStyleWasAttached)
            addNotification(name: .dkDrawableStyleWillBeDetached, receiveValue: drawableStyleWillBeDetached)
            addNotification(name: .dkDrawableSubselectionChanged, receiveValue: drawableSubselectionChanged)
            addNotification(name: .dkDrawingActiveLayerDidChange, receiveValue: drawingActiveLayerDidChange)
            addNotification(name: .dkDrawingActiveLayerWillChange, receiveValue: drawingActiveLayerWillChange)
            addNotification(name: .dkDrawingDidChangeMargins, receiveValue: drawingDidChangeMargins)
            addNotification(name: .dkDrawingDidChangeSize, receiveValue: drawingDidChangeSize)
            addNotification(name: .dkDrawingMouseDownLocation, receiveValue: drawingMouseDownLocation)
            addNotification(name: .dkDrawingMouseDraggedLocation, receiveValue: drawingMouseDraggedLocation)
            addNotification(name: .dkDrawingMouseMovedLocation, receiveValue: drawingMouseMovedLocation)
            addNotification(name: .dkDrawingMouseUpLocation, receiveValue: drawingMouseUpLocation)
            addNotification(name: .dkDrawingToolCreatedObjectsStyleDidChange, receiveValue: drawingToolCreatedObjectsStyleDidChange)
            addNotification(name: .dkDrawingToolWasRegistered, receiveValue: drawingToolWasRegistered)
            addNotification(name: .dkDrawingToolWillMakeNewObject, receiveValue: drawingToolWillMakeNewObject)
            addNotification(name: .dkDrawingUnitsDidChange, receiveValue: drawingUnitsDidChange)
            addNotification(name: .dkDrawingUnitsWillChange, receiveValue: drawingUnitsWillChange)
            addNotification(name: .dkDrawingViewDidBeginTextEditing, receiveValue: drawingViewDidBeginTextEditing)
            addNotification(name: .dkDrawingViewDidChangeScale, receiveValue: drawingViewDidChangeScale)
            addNotification(name: .dkDrawingViewDidCreateAutoDrawing, receiveValue: drawingViewDidCreateAutoDrawing)
            addNotification(name: .dkDrawingViewDidEndTextEditing, receiveValue: drawingViewDidEndTextEditing)
            addNotification(name: .dkDrawingViewRulersChanged, receiveValue: drawingViewRulersChanged)
            addNotification(name: .dkDrawingViewTextEditingContentsDidChange, receiveValue: drawingViewTextEditingContentsDidChange)
            addNotification(name: .dkDrawingViewWillChangeScale, receiveValue: drawingViewWillChangeScale)
            addNotification(name: .dkDrawingViewWillCreateAutoDrawing, receiveValue: drawingViewWillCreateAutoDrawing)
            addNotification(name: .dkDrawingWillBeSavedOrExported, receiveValue: drawingWillBeSavedOrExported)
            addNotification(name: .dkDrawingWillChangeMargins, receiveValue: drawingWillChangeMargins)
            addNotification(name: .dkDrawingWillChangeSize, receiveValue: drawingWillChangeSize)
            addNotification(name: .dkLayerDidAddObject, receiveValue: layerDidAddObject)
            addNotification(name: .dkLayerDidRemoveObject, receiveValue: layerDidRemoveObject)
            addNotification(name: .dkLayerDidReorderObjects, receiveValue: layerDidReorderObjects)
            addNotification(name: .dkLayerGroupDidAddLayer, receiveValue: layerGroupDidAddLayer)
            addNotification(name: .dkLayerGroupDidRemoveLayer, receiveValue: layerGroupDidRemoveLayer)
            addNotification(name: .dkLayerGroupDidReorderLayers, receiveValue: layerGroupDidReorderLayers)
            addNotification(name: .dkLayerGroupNumberOfLayersDidChange, receiveValue: layerGroupNumberOfLayersDidChange)
            addNotification(name: .dkLayerGroupWillReorderLayers, receiveValue: layerGroupWillReorderLayers)
            addNotification(name: .dkLayerKeyObjectDidChange, receiveValue: layerKeyObjectDidChange)
            addNotification(name: .dkLayerLockStateDidChange, receiveValue: layerLockStateDidChange)
            addNotification(name: .dkLayerNameDidChange, receiveValue: layerNameDidChange)
            addNotification(name: .dkLayerSelectionDidChange, receiveValue: layerSelectionDidChange)
            addNotification(name: .dkLayerSelectionHighlightColourDidChange, receiveValue: layerSelectionHighlightColourDidChange)
            addNotification(name: .dkLayerVisibleStateDidChange, receiveValue: layerVisibleStateDidChange)
            addNotification(name: .dkLayerWillAddObject, receiveValue: layerWillAddObject)
            addNotification(name: .dkLayerWillRemoveObject, receiveValue: layerWillRemoveObject)
            addNotification(name: .dkMetadataDidChange, receiveValue: metadataDidChange)
            addNotification(name: .dkMetadataWillChange, receiveValue: metadataWillChange)
            addNotification(name: .dkNotificationGradientDidAddColorStop, receiveValue: gradientDidAddColorStop)
            addNotification(name: .dkNotificationGradientDidChange, receiveValue: gradientDidChange)
            addNotification(name: .dkNotificationGradientDidRemoveColorStop, receiveValue: gradientDidRemoveColorStop)
            addNotification(name: .dkNotificationGradientWillAddColorStop, receiveValue: gradientWillAddColorStop)
            addNotification(name: .dkNotificationGradientWillChange, receiveValue: gradientWillChange)
            addNotification(name: .dkNotificationGradientWillRemoveColorStop, receiveValue: gradientWillRemoveColorStop)
            addNotification(name: .dkObserverRelayDidReceiveChange, receiveValue: observerRelayDidReceiveChange)
            addNotification(name: .dkRasterizerPropertyDidChange, receiveValue: rasterizerPropertyDidChange)
            addNotification(name: .dkRasterizerPropertyWillChange, receiveValue: rasterizerPropertyWillChange)
            addNotification(name: .dkSelectionToolDidFinishEditingObject, receiveValue: selectionToolDidFinishEditingObject)
            addNotification(name: .dkSelectionToolDidFinishMovingObjects, receiveValue: selectionToolDidFinishMovingObjects)
            addNotification(name: .dkSelectionToolDidFinishSelectionDrag, receiveValue: selectionToolDidFinishSelectionDrag)
            addNotification(name: .dkSelectionToolWillStartEditingObject, receiveValue: selectionToolWillStartEditingObject)
            addNotification(name: .dkSelectionToolWillStartMovingObjects, receiveValue: selectionToolWillStartMovingObjects)
            addNotification(name: .dkSelectionToolWillStartSelectionDrag, receiveValue: selectionToolWillStartSelectionDrag)
            addNotification(name: .dkStyleDidChange, receiveValue: styleDidChange)
            addNotification(name: .dkStyleLockStateChanged, receiveValue: styleLockStateChanged)
            addNotification(name: .dkStyleNameChanged, receiveValue: styleNameChanged)
            addNotification(name: .dkStyleRegistryDidFlagPossibleUIChange, receiveValue: styleRegistryDidFlagPossibleUIChange)
            addNotification(name: .dkStyleSharableFlagChanged, receiveValue: styleSharableFlagChanged)
            addNotification(name: .dkStyleTextAttributesDidChange, receiveValue: styleTextAttributesDidChange)
            addNotification(name: .dkStyleWasAttached, receiveValue: styleWasAttached)
            addNotification(name: .dkStyleWasEditedWhileRegistered, receiveValue: styleWasEditedWhileRegistered)
            addNotification(name: .dkStyleWasRegistered, receiveValue: styleWasRegistered)
            addNotification(name: .dkStyleWasRemovedFromRegistry, receiveValue: styleWasRemovedFromRegistry)
            addNotification(name: .dkStyleWillBeDetached, receiveValue: styleWillBeDetached)
            addNotification(name: .dkStyleWillChange, receiveValue: styleWillChange)
            addNotification(name: .dkWillChangeTool, receiveValue: willChangeTool)

            // missing exported notifications
//            addNotification(name: .dkTextSubstitutorNewString, receiveValue: textSubstitutorNewStringNotification)
//            addNotification(name: .dkUnarchiverProgressContinued, receiveValue: unarchiverProgressContinuedNotification)
//            addNotification(name: .dkUnarchiverProgressFinished, receiveValue: unarchiverProgressFinishedNotification)
//            addNotification(name: .dkUnarchiverProgressStarted, receiveValue: unarchiverProgressStartedNotification)
        }

        typealias UserInfo = [AnyHashable : Any]

        func drawingMouseDownLocation(object: Any, userInfo: UserInfo) {
            // print(#function) // too chatty
        }

        func drawingMouseDraggedLocation(object: Any, userInfo: UserInfo) {
            // print(#function) // too chatty
        }

        func drawingMouseMovedLocation(object: Any, userInfo: UserInfo) {
            // print(#function) // too chatty
        }

        func drawingMouseUpLocation(object: Any, userInfo: UserInfo) {
            // print(#function) // too chatty
        }


        // TODO: DKCategoryManager is generic – what should the argument be?

        typealias CategoryManager = DKCategoryManager<DKDrawing>

        func categoryManagerDidAddKeyToCategory(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerDidAddObject(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerDidCreateNewCategory(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerDidDeleteCategory(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerDidRemoveKeyFromCategory(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerDidRemoveObject(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerDidRenameCategory(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerWillAddKeyToCategory(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerWillAddObject(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerWillCreateNewCategory(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerWillDeleteCategory(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerWillRemoveKeyFromCategory(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }

        func categoryManagerWillRemoveObject(object: CategoryManager, userInfo: UserInfo) {
            print(#function)
        }


        func didChangeToolAutoRevertState(object: DKToolController, userInfo: UserInfo) {
            print(#function)
        }

        func didChangeTool(object: DKToolController, userInfo: UserInfo) {
            print(#function)
        }

        func willChangeTool(object: DKToolController, userInfo: UserInfo) {
            print(#function)
        }


        func drawableDidChange(object: DKDrawableObject, userInfo: UserInfo) {
            print(#function)
        }

        func drawableDoubleClick(object: DKDrawableObject, userInfo: UserInfo) {
            print(#function)
        }

        func drawableStyleWasAttached(object: DKDrawableObject, userInfo: UserInfo) {
            print(#function)
        }

        func drawableStyleWillBeDetached(object: DKDrawableObject, userInfo: UserInfo) {
            print(#function)
        }

        func drawableSubselectionChanged(object: DKDrawableObject, userInfo: UserInfo) {
            print(#function)
        }


        func drawingActiveLayerDidChange(object: DKDrawing, userInfo: UserInfo) {
            print(#function)
        }

        func drawingActiveLayerWillChange(object: DKDrawing, userInfo: UserInfo) {
            print(#function)
        }


        func drawingDidChangeMargins(object: DKDrawing, userInfo: UserInfo) {
            print(#function)
        }

        func drawingDidChangeSize(object: DKDrawing, userInfo: UserInfo) {
            print(#function)
        }

        func drawingToolCreatedObjectsStyleDidChange(object: DKObjectCreationTool, userInfo: UserInfo) {
            print(#function)
        }

        func drawingToolWasRegistered(object: DKDrawingTool, userInfo: UserInfo) {
            print(#function)
        }

        func drawingToolWillMakeNewObject(object: DKDrawingTool, userInfo: UserInfo) {
            print(#function)
        }

        func drawingUnitsDidChange(object: DKDrawing, userInfo: UserInfo) {
            print(#function)
        }

        func drawingUnitsWillChange(object: DKDrawing, userInfo: UserInfo) {
            print(#function)
        }

        func drawingViewDidBeginTextEditing(object: DKDrawingView, userInfo: UserInfo) {
            print(#function)
        }

        func drawingViewDidChangeScale(object: DKDrawingView, userInfo: UserInfo) {
            print(#function)
        }

        func drawingViewDidCreateAutoDrawing(object: DKDrawingView, userInfo: UserInfo) {
            print(#function)
        }

        func drawingViewDidEndTextEditing(object: DKDrawingView, userInfo: UserInfo) {
            print(#function)
        }

        func drawingViewRulersChanged(object: DKDrawingView, userInfo: UserInfo) {
            print(#function)
        }

        func drawingViewTextEditingContentsDidChange(object: DKDrawingView, userInfo: UserInfo) {
            print(#function)
        }

        func drawingViewWillChangeScale(object: DKDrawingView, userInfo: UserInfo) {
            print(#function)
        }

        func drawingViewWillCreateAutoDrawing(object: DKDrawingView, userInfo: UserInfo) {
            print(#function)
        }

        func drawingWillBeSavedOrExported(object: DKDrawing, userInfo: UserInfo) {
            print(#function)
        }

        func drawingWillChangeMargins(object: DKDrawing, userInfo: UserInfo) {
            print(#function)
        }

        func drawingWillChangeSize(object: DKDrawing, userInfo: UserInfo) {
            print(#function)
        }

        func layerDidAddObject(object: DKObjectOwnerLayer, userInfo: UserInfo) {
            print(#function)
            // whenever we add an object we revert our tool to the selection tool
            setSelectionTool()
        }

        func layerDidRemoveObject(object: DKObjectOwnerLayer, userInfo: UserInfo) {
            print(#function)
        }

        func layerDidReorderObjects(object: DKObjectOwnerLayer, userInfo: UserInfo) {
            print(#function)
        }

        func layerGroupDidAddLayer(object: DKLayerGroup, userInfo: UserInfo) {
            print(#function)
        }

        func layerGroupDidRemoveLayer(object: DKLayerGroup, userInfo: UserInfo) {
            print(#function)
        }

        func layerGroupDidReorderLayers(object: DKLayerGroup, userInfo: UserInfo) {
            print(#function)
        }

        func layerGroupNumberOfLayersDidChange(object: DKLayerGroup, userInfo: UserInfo) {
            print(#function)
        }

        func layerGroupWillReorderLayers(object: DKLayerGroup, userInfo: UserInfo) {
            print(#function)
        }

        func layerKeyObjectDidChange(object: DKObjectDrawingLayer, userInfo: UserInfo) {
            print(#function)
        }

        func layerLockStateDidChange(object: DKLayer, userInfo: UserInfo) {
            print(#function)
        }

        func layerNameDidChange(object: DKLayer, userInfo: UserInfo) {
            print(#function)
        }

        func layerSelectionDidChange(object: DKObjectDrawingLayer, userInfo: UserInfo) {
            print(#function)
        }

        func layerSelectionHighlightColourDidChange(object: DKLayer, userInfo: UserInfo) {
            print(#function)
        }

        func layerVisibleStateDidChange(object: DKLayer, userInfo: UserInfo) {
            print(#function)
        }

        func layerWillAddObject(object: DKObjectOwnerLayer, userInfo: UserInfo) {
            print(#function)
        }

        func layerWillRemoveObject(object: DKObjectOwnerLayer, userInfo: UserInfo) {
            print(#function)
        }

        func metadataDidChange(object: DKLayer, userInfo: UserInfo) {
            print(#function)
        }

        func metadataWillChange(object: DKLayer, userInfo: UserInfo) {
            print(#function)
        }

        func gradientDidAddColorStop(object: DKGradient, userInfo: UserInfo) {
            print(#function)
        }

        func gradientDidChange(object: DKGradient, userInfo: UserInfo) {
            print(#function)
        }

        func gradientDidRemoveColorStop(object: DKGradient, userInfo: UserInfo) {
            print(#function)
        }

        func gradientWillAddColorStop(object: DKGradient, userInfo: UserInfo) {
            print(#function)
        }

        func gradientWillChange(object: DKGradient, userInfo: UserInfo) {
            print(#function)
        }

        func gradientWillRemoveColorStop(object: DKGradient, userInfo: UserInfo) {
            print(#function)
        }

        func observerRelayDidReceiveChange(object: GCObservableObject, userInfo: UserInfo) {
            print(#function)
        }

        func rasterizerPropertyDidChange(object: DKRasterizer, userInfo: UserInfo) {
            print(#function)
        }

        func rasterizerPropertyWillChange(object: DKRasterizer, userInfo: UserInfo) {
            print(#function)
        }

        func selectionToolDidFinishEditingObject(object: DKSelectAndEditTool, userInfo: UserInfo) {
            print(#function)
        }

        func selectionToolDidFinishMovingObjects(object: DKSelectAndEditTool, userInfo: UserInfo) {
            print(#function)
        }

        func selectionToolDidFinishSelectionDrag(object: DKSelectAndEditTool, userInfo: UserInfo) {
            print(#function)
        }

        func selectionToolWillStartEditingObject(object: DKSelectAndEditTool, userInfo: UserInfo) {
            print(#function)
        }

        func selectionToolWillStartMovingObjects(object: DKSelectAndEditTool, userInfo: UserInfo) {
            print(#function)
        }

        func selectionToolWillStartSelectionDrag(object: DKSelectAndEditTool, userInfo: UserInfo) {
            print(#function)
        }

        func styleWillChange(object: DKStyle, userInfo: UserInfo) {
            print(#function)
        }

        func styleDidChange(object: DKStyle, userInfo: UserInfo) {
            print(#function)
        }

        func styleLockStateChanged(object: DKStyle, userInfo: UserInfo) {
            print(#function)
        }

        func styleNameChanged(object: DKStyle, userInfo: UserInfo) {
            print(#function)
        }

        func styleRegistryDidFlagPossibleUIChange(object: DKStyleRegistry, userInfo: UserInfo) {
            print(#function)
        }

        func styleSharableFlagChanged(object: DKStyle, userInfo: UserInfo) {
            print(#function)
        }

        func styleTextAttributesDidChange(object: DKStyle, userInfo: UserInfo) {
            print(#function)
        }

        func styleWasEditedWhileRegistered(object: DKStyleRegistry, userInfo: UserInfo) {
            print(#function)
        }

        func styleWasRegistered(object: DKStyleRegistry, userInfo: UserInfo) {
            print(#function)
        }

        func styleWasRemovedFromRegistry(object: DKStyleRegistry, userInfo: UserInfo) {
            print(#function)
        }

        func styleWillBeDetached(object: DKDrawableObject, userInfo: UserInfo) {
            print(#function)
        }

        func styleWasAttached(object: DKDrawableObject, userInfo: UserInfo) {
            print(#function)
        }

    }
}


// MARK: Defaultable Utilities

protocol Defaultable {
    static var defaultValue: Self { get }
}

extension ExpressibleByArrayLiteral {
    static var defaultValue: Self { [] }
}

extension ExpressibleByDictionaryLiteral {
    static var defaultValue: Self { [:] }
}

extension Set : Defaultable { }
extension Array : Defaultable { }
extension ContiguousArray : Defaultable { }
extension Dictionary : Defaultable { }

extension Optional where Wrapped : Defaultable {
    var faulted: Wrapped {
        get {
            self ?? .defaultValue
        }

        _modify {
            var value = self ?? .defaultValue
            yield &value
            self = value
        }
    }
}
