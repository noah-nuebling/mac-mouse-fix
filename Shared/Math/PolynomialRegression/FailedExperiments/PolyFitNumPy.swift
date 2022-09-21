//
// --------------------------------------------------------------------------
// PolyFitNumPy.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

//import Foundation
//import PythonKit
//import PythonSupport ///
//import NumPySupport
//
//func fit(points: [P], polynomialDegree: Int) -> [Double] {
//    
//    /// Init stuff
//    PythonSupport.initialize()
//    NumPySupport.sitePackagesURL.insertPythonPath()
//    let numpy = Python.import("numpy")
//    
//    /// Use numpy polyfit
//    let coefficients = numpy.polyfit(points.map { $0.x }, points.map { $0.y }, polynomialDegree)
//    
//    /// Return
//    return Array<Double>(coefficients)!
//}
