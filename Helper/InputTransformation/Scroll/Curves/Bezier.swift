//
// --------------------------------------------------------------------------
// BezierCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/*
 See the English and German Wiki pages on Bezier Curves:
    https://en.wikipedia.org/wiki/Bézier_curve#Derivative
 */

import Cocoa
import simd // Vector stuff
//import CocoaLumberjack // Doesn't work for some reason
import ReactiveCocoa
import ReactiveSwift

/// This class works similar to the AnimationCurve class I copied from WebKit
/// The difference is that this doesn't have fixed start and end controlPoints at (0,0) and (1,1), and the number of  control points isn't locked at 4
///
/// It's also likely muchhh slower than the Apple code, because in the Apple code they somehow transform the bezier curve into a polynomial which allows them to samlpe the curve value and derivative in a single line of c code.
/// We, on the other hand, use De-Casteljau's algorithm, which has nested for-loops and is probably in O(n*2) (Where n is the number of controlPoints describing the curve)
/// Edit: Actually, from my (superficial) testing using the Apple Time Profiler, this seems to be faster than AnimationCurve.m! Not sure how that's possible'
/// Edit2: Using simple time profiling with CACurrentMediatime(), the Swift implementation is 50 - 200 times slower than the Objc implementation. That's closer to what I expected.
///     I tested on the same curve, with a 0.001 epsilon on my Early 2015 MBP
///     BezierCurve.swift usually took around 0.0001s (= 100 microseconds = 0.1 ms) to get y(x), while AnimationCurve.m usually took around 0.000001s (= 1 microsecond = 0.001 ms)
///     -> 60 fps is 16.66 ms per frame so the Swift implemenation should be fast enough
/// Edit3: Did some more optimitzations by implementing formulas for the polynomial form of the Bezier Curve and precalculating the coefficients, very similar to how the Apple code does it. Now it's super fast to evaluate!
///     With the new algorithms Swift is only around 5 times slower than ObjC.
///         (Another thing that affected these results is that before I was building for Debug and for these tests I was building for release. - that made Swift a lot faster while barely affecting C IIRC - Edit: Yep, when running an unoptimized DEBUG build, Swift is still around 40 times slower than C)
///     Swift now takes around 0.01 ms to evaluate testing with a 0.08 epsilon, which is very important becuase 0.1 ms was way to slow (irony). I officially overengineered this lol.

/// For optimization, we usually only evaluate the x or the y values for our functions, even though these functions are formally defined to work on points. That's what the MFAxis parameters in some of these functions are for

/// It would be quite a bit nicer to have this be a struct instead of a class because of value semantics and less weird rules around initializing. But alas Swift structs aresn't compatible with Objc

/// # references
/// De-Casteljau's algorithm | German Wikipedia
///     https://en.wikipedia.org/wiki/De_Casteljau%27s_algorithm
/// AnimationCurve.m | Apple Webkit
///     I can't find this on Google anymore but it's included with this Project
///     Edit: I since renamed it to CubicUnitBezier
/// Visual editor for higher order Bezier Curves | Desmos
///     https://www.desmos.com/calculator/xlpbe9bgll
///     https://www.desmos.com/calculator/jbhmbwqnf3
///      ^ edited to only have 5 control point, not 10
/// Article on how to implement cubic bezier curves more efficiently for games
///     http://devmag.org.za/2011/04/05/bzier-curves-a-tutorial/
/// Paper which containts info on how to differentiate the De Casteljau formula
///     It should be faster than the derivative of the explicit form which we currently use
///     https://www.clear.rice.edu/comp360/lectures/old/BezText.pdf

@objc class Bezier: NSObject, RealFunction {

    typealias Point = Vector;
    let xAxis = kMFAxisHorizontal
    let yAxis = kMFAxisVertical
    
    // Control points
    
    let controlPoints: [Point]
    let controlPointsX: [Double]
    let controlPointsY: [Double]
    func controlPoints(_ axis: MFAxis) -> [Double] { /// Would be more elegant to use a dict or an enum (enums do that in Swift I think?)
        if axis == xAxis { return controlPointsX }
        else if axis == yAxis { return controlPointsY }
        assert(false, "Invalid axis")
        return [] // This will never happen. Just to silence compiler
    }
    
    // Polynomial coefficients
    
    var polynomialCoefficients: [Point] // Needs to be var to fill it based on other instance properties in initializer bc Swift is weird
    var polynomialCoefficientsX: [Double]
    var polynomialCoefficientsY: [Double]
    func polynomialCoefficients(_ axis: MFAxis) -> [Double] {
        if axis == xAxis { return polynomialCoefficientsX }
        else if axis == yAxis { return polynomialCoefficientsY }
        assert(false, "Invalid axis")
        return []
    }
    
    let maxDegreeForPolynomialApproach: Int = 20
    /// ^ Wikipedia says that "high order curves may lack numeric stability" in polynomial form, and to use Casteljau instead if that happens. Not sure where exactly we should make the cutoff
    
    let defaultEpsilon: Double // Epsilon to be used when none is specified in evaluate(at:) call
    
    var degree: Int {
        controlPoints.count - 1
    }
    var n: Int { degree }
    
    var startPoint: Point {
        return controlPoints.first!
    }
    var endPoint: Point {
        return controlPoints.last!
    }
    
    let xValueRange: Interval
    
    // MARK: Init
    
    /// Helper functions for Init functions
    
    private class func convertNSPointsToPoints(_ controlNSPoints: [NSPoint]) -> [Bezier.Point] {
        /// Helper function for objc  init functions
        /// Unused - remove
        
        return controlNSPoints.map { (pointNS) -> Point in
            var point: Point = Point.init()
            point.x = Double(pointNS.x)
            point.y = Double(pointNS.y)
            return point
        }
    }
    private class func convertPointArraysToPoints(_ controlPointsAsArrays: [[Double]]) -> [Bezier.Point] {
        /// Helper function for objc  init functions
        
        return controlPointsAsArrays.map { (pointArray: [Double]) -> Point in
            var point: Point = Point.init()
            point.x = Double(pointArray[0])
            point.y = Double(pointArray[1])
            return point
        }
    }
    
    // Objc compatible wrappers for the Swift init functions
    
    @objc convenience init(controlPointsAsArrays: [[Double]],
                               xInterval: Interval = Interval.unitInterval(),
                               yInterval: Interval = Interval.unitInterval()) {
        /// `controlPointsAsArrays` is expected to have this structure: `[[x,y],[x,y],[x,y],...]`
        
        
        let controlPoints: [Point] = Bezier.convertPointArraysToPoints(controlPointsAsArrays)
        self.init(controlPoints: controlPoints, xInterval: xInterval, yInterval: yInterval)
    }
    @objc convenience init(controlPointsAsArrays: [[Double]]) {
        
        let controlPoints: [Point] = Bezier.convertPointArraysToPoints(controlPointsAsArrays)
        self.init(controlPoints: controlPoints)
    }
    
    // Swift init
    
    convenience init(controlPoints: [Point],
                     defaultEpsilon: Double = 0.08,
                     xInterval: Interval,
                     yInterval: Interval) {
        /**
        This convenience initializer scales the controlPoints' x values to xInterval and the y values to yInterval before creating a curve
         More specifically scales the x values of all controlpoints from the interval spanning from the first to the last controlpoints' x values, and does the same for y values.
         */
        
        assert(controlPoints.count >= 2, "There need to be at least 2 controlPoints") // Code duplication, but idk how to avoid it here
        
        let pFirst = controlPoints.first!
        let pLast = controlPoints.last!
        
        let xIntervalOrigin = Interval.init(start: pFirst.x, end: pLast.x) // Should we use Interval.init(lower:upper) instead, to make sure the x values are ascending?
        let yIntervalOrigin = Interval.init(start: pFirst.y, end: pLast.y)
        
        let pointsInTargetInterval: [Point] = controlPoints.map { (point: Point) -> Point in
            let x = Math.scale(value: point.x, from: xIntervalOrigin, to: xInterval)
            let y = Math.scale(value: point.y, from: yIntervalOrigin, to: yInterval)
            
            return Point(x: x, y: y)
        }
        
        self.init(controlPoints: pointsInTargetInterval, defaultEpsilon: defaultEpsilon)
        
    }
    
    init(controlPoints: [Point], defaultEpsilon: Double = 0.08) {
        
        /**
         - You should make sure you only pass in control points describing curves where
            - 1. The x values of the first and last point are the two extreme (minimal and maximal) x values among all control points x values
            - 2. The curves x values are monotonically increasing / decreasing along the y axis, so that there are no x coordinates for which there are several points on the curve
                - This actually implies 1.
                - There is a proper mathsy name for this but I forgot
                - If it's not the case, it won't necessarily throw an error, but things might behave unpredicably.
         */
        
        
        
        /// Make sure that there are at least 2 points
        
        assert(controlPoints.count >= 2, "There need to be at least 2 controlPoints");
        
        /// Set defaultEpsilon
        
        self.defaultEpsilon = defaultEpsilon
        
        /// Fill self.controlPoints
        
        self.controlPoints = controlPoints
        
        /// Fill self.controlPointsX and self.controlPointsY
        
        var controlPointsX: [Double] = []
        var controlPointsY: [Double] = []
        
        for point in controlPoints {
            controlPointsX.append(point.x)
            controlPointsY.append(point.y)
        }
        
        self.controlPointsX = controlPointsX
        self.controlPointsY = controlPointsY
        
        /// Get x values of the start and end points!
        
        let startX = controlPointsX.first!
        let endX = controlPointsX.last!
        
        /// Get x value range
        /// This (and other parts of the code which rely on `xValueRange`) assumes that the curves extreme x values are startX and endX
        /// You should only pass in curves where that's the case
        
        self.xValueRange = Interval.init(lower: startX, upper: endX)
        
        /// Set polynomialCoefficients to anything so we can call super.init()
        /// Only after we called super init, can we access instance properties, which we want to use for calculating the real polynomialCoefficients
        
        self.polynomialCoefficients = []
        self.polynomialCoefficientsX = []
        self.polynomialCoefficientsY = []
        
        /// Init super
        
        super.init()
        
        /// Precalculate coefficients of the polynomial form of the Bezier Curve
        /// Formula according to English Wikipedia
        
        let P: [Point] = self.controlPoints /// To make maths formulas more readable
        
        /// Fill out the polynomialCoefficient arrays with placeholder values, so we can simply go
        ///   `array[i] = v`, later, instead of having to use `array.append(v)`
        ///   This is super ugly but there doesn't seem to be a better way in swift
        ///     Ideally we'd just allocate space for n+1 elements in the array instead of this but that doesn't seem to be possible in Swift
        
        let placeholderPoint = Point.init(x:-1, y:-1)
        let placeholderPointArray: [Point] = [Point](repeating: placeholderPoint, count: n+1)
        let placeholderDoubleArray: [Double] = [Double](repeating: -1.0, count: n+1)
        
        self.polynomialCoefficients = placeholderPointArray
        self.polynomialCoefficientsX = placeholderDoubleArray
        self.polynomialCoefficientsY = placeholderDoubleArray
        
        for j in 0...n {
            
            /// Get product
            
            var product: Int = 1
            if 0 <= j-1 { // Otherwise the range can be be 0...-1 which, just means "skip this" in Maths, but Swift doesn't like it
                for m in 0...j-1 {
                    product *= n-m
                }
            }
            
            /// Get sum
            
            var sumX: Double = 0
            var sumY: Double = 0
            
            for i in 0...j {
                let a: Double = pow(-1, Double(i+j)) / Double(fac(i) * fac(j-i))
                sumX += a * P[i].x
                sumY += a * P[i].y
            }
            
            /// Put it all together
            
            let xCoefficient: Double = Double(product) * sumX
            let yCoefficient: Double = Double(product) * sumY
            
            /// Fill instance properties
            
            self.polynomialCoefficientsX[j] = xCoefficient
            self.polynomialCoefficientsY[j] = yCoefficient
            self.polynomialCoefficients[j] = Point.init(x: xCoefficient, y: yCoefficient)
        }
    }
    
    // MARK: Sample curve
    
    /// - Parameters:
    ///   - axis: Axis which to sample. Either `xAxis` or `yAxis`
    ///   - t: Where to evaluate the curve. Valid values ranges from 0 to 1
    /// - Returns: The x or y value for the input t
    private func sampleCurve(onAxis axis: MFAxis, atT t: Double) -> Double {
        /// The polynomial approach should be very fast but apparentaly becomes "numerically unstable" for larger control point counts. (src. Wikipedia)
        ///     So for a larger degree we use the slower Casteljau algorithm instead
        
        if degree <= maxDegreeForPolynomialApproach {
            return sampleCurvePolynomial(axis, t)
        } else {
            return sampleCurveCasteljau(axis, t)
        }
    }
    
    fileprivate func sampleCurvePolynomial(_ axis: MFAxis, _ t: Double) -> Double {
        
        let C: [Double] = self.polynomialCoefficients(axis)
        
        var sum: Double = 0
        
        /// Applying Horners Rule for optimization
        /// Horners Rule: https://www.math10.com/en/algebra/horner.html
        /// Original Formula: https://wikimedia.org/api/rest_v1/media/math/render/svg/1263b2329c8a60a78a433731dfd88b55d6a37eb0
        for j in (1...n).reversed() {
            sum += C[j]
            sum *= t
        }
        sum += C[0]
        
        return sum
    }
    
    fileprivate func sampleCurveCasteljau(_ axis: MFAxis, _ t: Double) -> Double {
        /// Evaluate at t with De-Casteljau's algorithm. I thonk it's in O(n!) or something?
        
        // Extract x or y values from controlPoints
        
        var points1D: [Double] = controlPoints(axis)
        
        // Apply De-Casteljau's algorithm
        
        var pointsCount = points1D.count;
        
        while true {
            pointsCount -= 1
            for i in 0..<pointsCount {
                // Interpolate between the points at i and at i-1. Write the result into points at i
                points1D[i] = simd_mix(points1D[i], points1D[i+1], t)
            }
            if pointsCount == 1 { // We evaluated the point
                break
            }
        }
        
        return points1D[0]
    }
    
    // MARK: Derivative
    
    private func sampleDerivative(on axis: MFAxis, at t: Double) -> Double {
        /// See sampleCurve(onAxis:atT:) for context
        /// The explicit algorithm is even slower than Casteljau's algorithm, but it should work the same and couldn't be bothered to implement Casteljau here, too.
        
        if degree <= maxDegreeForPolynomialApproach {
            return sampleDerivativePolynomial(axis, t)
        } else {
            return sampleDerivativeExplicit(axis, t)
        }
        
    }
    
    private func sampleDerivativePolynomial(_ axis: MFAxis, _ t: Double) -> Double {
        
        let C: [Double] = self.polynomialCoefficients(axis)
        
        var sum: Double = 0
        
        /// We take the derivative of the original formula and get
        ///     ```
        ///     B'(t) = sum_{j=1}^{n} t^{j-1} * j * C_j
        ///     ```
        ///     To optimize, we then we apply Horners rule and arrive at the algorithm below
        ///     Also see: original formula: https://wikimedia.org/api/rest_v1/media/math/render/svg/1263b2329c8a60a78a433731dfd88b55d6a37eb0
        
        for j in (2...n).reversed() {
            sum += C[j] * Double(j)
            sum *= t
        }
        sum += C[1]
        
        return sum
        
    }
    
    private func sampleDerivativeExplicit(_ axis: MFAxis, _ t: Double) -> Double {
        /// Implemented according to the explicit derivative formula found on English Wikipedia
        
        let points1D: [Double] = controlPoints(axis)
        
        var sum: Double = 0
        
        for i in 0...n-1 {
            
            sum += bernsteinBasisPolynomial(i, n-1, t) * (points1D[i+1] - points1D[i]) // Maybe we
        }
        
        return Double(n) * sum
    }
    
    // MARK: Bernstein Basis Polynomial
    
    private func bernsteinBasisPolynomial(_ i: Int, _ n: Int, _ t: Double) -> Double {
        /// Helper function for eplicit definitions
        
        assert((0...n).contains(i))
        
        let a: Double = Double(Math.choose(n, i))
        let b: Double = pow(t, Double(i))
        let c: Double = pow(1-t, Double(n-i))
        
        return a * b * c
    }
    
    
    // MARK: Get t(x)
    
    private func solveForT(x: Double, epsilon: Double) -> Double {
        /// This function is mostly copied from AnimationCurve.m by Apple
        /// It's a numerical inverse finder. It basically finds the parameter t for a function value x through educated guesses
        
        let initialGuess: Double = Math.scale(value: x, from: self.xValueRange, to: Interval.unitInterval())
        /// ^ Our initial guess for t.
        /// In Apples AnimationCurve.m this was set to x which is an informed guess. We extended the same logic to a general case. (In the Apple implementation, the xValueRange is implicitly 0...1)
        
        /// Try Newtons method
        /// Newtons method finds an input for which the output is 0
        /// So to use this for finding x, we need to shift the curve along the xAxis such the the desired x value is at 0
        /// To achieve that, we subtract x from the sampleCurve() result. We don't need to apply this shifting to sampleDerivative(), because shifting along the xAxis won't affect the derivative with respect to x. (If this sound weird remember the function parameter is t and the output is a point (x,y))
        
        let maxNewtonIterations: Int = 8
        var t = initialGuess
        
        for _ in 1...maxNewtonIterations {
            
            let sampledXShifted = sampleCurve(onAxis: xAxis, atT: t) - x
            
            let error = abs(sampledXShifted)
            if error < epsilon {
//                print("Solved for t in \(i) Newton iterations\n") /// Debug
                return t
            }
            
            let sampledDerivative = sampleDerivative(on: xAxis, at: t)
            
            if abs(sampledDerivative) < 1e-6 {
                break
            }
            
            t = t - sampledXShifted / sampledDerivative
            
            /// v In some scenarios, t will be joltet way outside the valid range of [0,1]. If that happens, newtons method will then sometimes find another t where sampleX = x, but with t outside [0,1]. To prevent this, we force t to be inside [0,1] here. Not sure if this has other bad sideeffects.
            
            if (t > 1) {t = 1}
            else if (t < 0) {t = 0}
        }
        
        print("Couldn't solve for t using Newton's method. Using bisection instead") /// Debug
        
        // Try bisection method for reliability
        
        t = initialGuess
        
        var searchRange = Interval.unitInterval()
        
        if (t <= searchRange.lower) {
            return searchRange.lower
        } else if searchRange.upper <= t {
            return searchRange.upper
        }
        
        while (searchRange.lower < searchRange.upper) {
            
            let sampledX = sampleCurve(onAxis: xAxis, atT: t)
            
            if fabs(sampledX - x) < epsilon {
//                print("Found t using bisection! t:\(t)")
                return t
            }
            if sampledX < x {
                searchRange = Interval(lower: t, upper: searchRange.upper)
            } else {
                searchRange = Interval(lower: searchRange.lower, upper: t)
            }
            t = Math.scale(value: 0.5, from: Interval.unitInterval(), to: searchRange)
        }
        
        
        // Failure
        
//        print("Bisection failed, too. Failed to solve for x = \(x). Resulting t = \(t)")  // TODO: Can't import CocoaLumberjack right now. Use that instead when possible
        
        return t
        
    }
    
    // MARK: Evaluate
    /// Get y(x)
    
    @objc func evaluate(at x: Double) -> Double {
        self.evaluate(at: x, epsilon: self.defaultEpsilon)
    }
    
    @objc func evaluate(at x: Double, epsilon: Double) -> Double {
        
        let t: Double = solveForT(x: x, epsilon: epsilon)
        let y: Double = sampleCurve(onAxis: yAxis, atT: t)
        
        return y
    }
        
    
    // MARK: Debug
    
    @objc func trace(nOfSamples: Int) -> String {
        /// Sample bezier curve `nOfSamples` times, and return results as string
        
        var trace: Array<Point> = Array()
        
        for i in 0..<nOfSamples {
            
            let x = Math.scale(value: Double(i), from: Interval(location: 0, length: Double(nOfSamples-1)), to: xValueRange)
            let y = evaluate(at: x, epsilon: defaultEpsilon)
            
            trace.append(Point(x: x, y: y))
            
        }
        
        var traceStr: String = String()
        
        for p in trace {
            traceStr.append("(\(p.x),\(p.y))\n")
        }
        
        return traceStr
        
    }

}
