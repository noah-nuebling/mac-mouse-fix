//
// --------------------------------------------------------------------------
// CurveVisualizer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// [Jun 2 2025]
///     Made this as a quick and dirty way to visualize point-arrays during development, such as the arrays retrieved from Curve.traceAsPoints()
///     Specifically, I made this as an alternative to `Bezier.getMinEpsilon()` (which is a heuristic for finding a usable epsilon for the Bezier algorithm) (But this should be useful for visualizing any curve!)
///

#if DEBUG /// I wanted to control this with a locally declared `MF_TEST` constant like we're doing in objc, but I don't know how to do that in Swift. || Maybe remove this from build targets if you don't use it so it doesn't slow down builds.


import SwiftUI
import Charts
import simd

@available(macOS 15.0, *)
struct CurveVisualizer_View: View {
    
    var curveTrace1: [P] = []
    var curveTrace2: [P] = []
    
    @State private var gestureZoom  = 1.0
    @State private var viewZoom     = 1.0
    @State private var gesturePos   = CGSizeZero
    @State private var viewPos      = CGSizeZero
    
    var body: some View {

        Chart { /// Taken largely from here: https://developer.apple.com/documentation/charts/chart
            
            ForEach(curveTrace1, id: \.self) { item in
                LineMark(
                    x: PlottableValue.value(Text(verbatim: "X"), item.x.native),
                    y: PlottableValue.value(Text(verbatim: "Y"), item.y.native),
                    series: .value(Text(verbatim: "Plot"), "1")
                )
                .foregroundStyle(.blue)
            }
            ForEach(curveTrace2, id: \.self) { item in
                LineMark(
                    x: PlottableValue.value(Text(verbatim: "X"), item.x.native),
                    y: PlottableValue.value(Text(verbatim: "Y"), item.y.native),
                    series: .value(Text(verbatim: "Plot"), "2")
                )
                .foregroundStyle(.red)
            }
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    gestureZoom = value.magnification
                    if (viewZoom*gestureZoom <= 0.1) { /// If we zoom out too far everything breaks [Jun 2 2025]
                        gestureZoom = 0.1/viewZoom
                    }
                }
                .onEnded { value in
                    viewZoom *= gestureZoom
                    gestureZoom = 1
                }
        )
        .gesture(
            DragGesture()
                .onChanged({ value in
                    
                    if ((viewZoom*gestureZoom) < 1.0) { /// If we allow panning while zoomed out everything seems to breaks. Not sure why [Jun 2 2025]. (Are these bugs in the framework?)
                        gesturePos = CGSizeZero;
                        viewPos = CGSizeZero
                    }
                    else {
                        gesturePos = CGSizeMake(Math.clamp(value.translation.width*(viewZoom*gestureZoom), (-1000, 1000)), Math.clamp(value.translation.height*(viewZoom*gestureZoom), (-1000, 1000)))
                    }
                })
                .onEnded({ value in
                    viewPos = CGSizeMake(viewPos.width+gesturePos.width, viewPos.height+gesturePos.height)
                    gesturePos = CGSizeZero
                })
        )
        .transformEffect(.identity.translatedBy(x: viewPos.width+gesturePos.width, y: viewPos.height+gesturePos.height).scaledBy(x: viewZoom*gestureZoom, y: viewZoom*gestureZoom))
    }
}

@available(macOS 15.0, *)
@objc class CurveVisualizer: NSObject { /// This object creates and interface for outside code to interact with the SwiftUI view
    
    static var _viewCtrl: NSHostingController<CurveVisualizer_View>? = nil
    
    private static func _initPlot() {
        /// Create and draw the SwiftUI Plot if necessary
        if _viewCtrl == nil {

            /// Get viewController for our SwiftUI view
            _viewCtrl = NSHostingController(rootView: CurveVisualizer_View())
            
            /// Create window with our viewController
            let window = NSWindow.init(contentViewController: _viewCtrl!)
            window.setContentSize(NSMakeSize(400, 300))
            window.title = "MMF Curve Visualizer"
            
            /// Create windowController with our window
            let windowCtrl = NSWindowController(window: window)
            
            /// Show window
            windowCtrl.showWindow(nil)
        }
    }
    
    @objc class func setCurveTrace1(_ trace: [P]) { /// Interface – call this to create a window that draws the curve
        MFCFRunLoopPerform(CFRunLoopGetMain(), nil) {
            _initPlot()
            _viewCtrl!.rootView.curveTrace1 = trace
        }
    }
    @objc class func setCurveTrace2(_ trace: [P]) { /// Interface
        MFCFRunLoopPerform(CFRunLoopGetMain(), nil) {
            _initPlot()
            _viewCtrl!.rootView.curveTrace2 = trace
        }
    }
}

#Preview {
//    CurveVisualizer_View()
}

#endif
