//
//  MFObserverBenchmarks.swift
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 31.07.24.
//

import Foundation
import Combine
import QuartzCore


class TestObjectKVO: NSObject {
    @objc dynamic var value: Int = 0
}
class TestObjectSwift: NSObject {
    @Published var value: Int = 0
}
class TestObjectSwift4: NSObject {
    @Published var value1: Int = 0
    @Published var value2: Int = 0
    @Published var value3: Int = 0
    @Published var value4: Int = 0
}


@objc class ObservationBenchmarksSwift: NSObject {
    
    @objc class func runPureSwiftTest(iterations: Int) -> TimeInterval {
        
        /// Ts
        let startTime = CACurrentMediaTime()
        
        /// MutableData
        var valuesFromCallback = [Int]()
        var sumFromCallback = 0
        
        /// Setup callback
        var value1 = 0
        let callback =  { (newValue: Int) in
            valuesFromCallback.append(newValue)
            sumFromCallback += newValue
            if (newValue % 2 == 0) {
                sumFromCallback <<= 2
            }
        }
        /// Change value
        for i in 0..<iterations {
            value1 = i
            callback(value1)
        }
        
        /// Ts
        let endTime = CACurrentMediaTime()
        
        /// Log
        print("pureSwift - count: \(valuesFromCallback.count), sum: \(sumFromCallback)")
        
        /// Return bench time
        return endTime - startTime
    }
    
    @objc class func runSwiftKVOTest(iterations: Int) -> TimeInterval {
            /// Ts
        let startTime = Date()
        
        /// MutableData
        var valuesFromCallback = [Int]()
        var sumFromCallback = 0
        
        do {
            /// Setup callback
            let testObject = TestObjectKVO()
            let cancellable = testObject.observe(\.value, options: [.new, .initial]) { testObject, change in
                let newValue = change.newValue!
                valuesFromCallback.append(newValue)
                sumFromCallback += newValue
                if (newValue % 2 == 0) {
                    sumFromCallback <<= 2
                }
            }
            
            /// Change value
            for i in 0..<iterations {
                testObject.value = i
            }
        } /// Do block might cause testObject & its observation to be destroyed here, making it easier to analyze assembly
        
        /// Ts
        let endTime = Date()
        
        /// Log
        print("SwiftKVO - count: \(valuesFromCallback.count), sum: \(sumFromCallback)")
        
        /// Return bench time
        return endTime.timeIntervalSince(startTime)
    }
    
    @objc class func runCombineTest(iterations: Int) -> TimeInterval {
        
        /// Ts
        let startTime = Date()
        
        /// MutableData
        var valuesFromCallback = [Int]()
        var sumFromCallback = 0
        
        /// Setup callback
        let testObject = TestObjectSwift()
        let cancellable = testObject.$value.sink(receiveValue: { newValue in
            valuesFromCallback.append(newValue)
            sumFromCallback += newValue
            if (newValue % 2 == 0) {
                sumFromCallback <<= 2
            }
        })
        
        /// Change value
        for i in 0..<iterations {
            testObject.value = i
        }
        
        /// Ts
        let endTime = Date()
        
        /// Log
        print("Combine - count: \(valuesFromCallback.count), sum: \(sumFromCallback)")
        
        /// Return bench time
        return endTime.timeIntervalSince(startTime)
    }
    
    @objc class func runPureSwiftTest_ObserveLatest(iterations: Int) -> TimeInterval {
        
        let startTime = CACurrentMediaTime()
        
        var sumFromCallback = 0
        
        var v1 = 0
        var v2 = 0
        var v3 = 0
        var v4 = 0
        
        let callback = { (value1, value2, value3, value4) in
            sumFromCallback += value1 + value2 + value3 + value4
            if (value1 + value2 + value3 + value4) % 2 == 0 {
                sumFromCallback <<= 8
            }
        }
        
        for i in 1..<iterations {
            v1 = i
            callback(v1, v2, v3, v4)
            v2 = i * 2
            callback(v1, v2, v3, v4)
            v3 = i * 3
            callback(v1, v2, v3, v4)
            v4 = i * 4
            callback(v1, v2, v3, v4)
        }
        
        let endTime = CACurrentMediaTime()
        
        print("pureSwift - ObserveLatest - sum: \(sumFromCallback)")
        
        return endTime - startTime
    }

    
    @objc class func runCombineTest_ObserveLatest(iterations: Int) -> TimeInterval {
        
        let startTime = Date()
        
        var sumFromCallback = 0
        
        let testObject = TestObjectSwift4()
        let publisher1 = testObject.$value1
        let publisher2 = testObject.$value2
        let publisher3 = testObject.$value3
        let publisher4 = testObject.$value4
        
        let combinedPublisher = Publishers.CombineLatest4(
            publisher1,
            publisher2,
            publisher3,
            publisher4
        )
        let cancellable = combinedPublisher.sink { value1, value2, value3, value4 in
            sumFromCallback += value1 + value2 + value3 + value4
            if (value1 + value2 + value3 + value4) % 2 == 0 {
                sumFromCallback <<= 8
            }
        }
        
        for i in 1..<iterations {
            testObject.value1 = i
            testObject.value2 = i * 2
            testObject.value3 = i * 3
            testObject.value4 = i * 4
            
        }
        
        let endTime = Date()
        
        print("Combine - ObserveLatest - sum: \(sumFromCallback)")
        
        return endTime.timeIntervalSince(startTime)
    }
    
    @objc class func runCombineTest_Strings(iterations: Int) -> TimeInterval {
        
        ///
        /// The checksum for this is correct in Debug builds but alwys 0 in release builds WTF? Combine bug?
        ///     Either way this is slower than our KVO wrapper even if it doesn't do anything and the checksum is zero 😎
        ///
        
        let startTime = CACurrentMediaTime()
        var checkSum: Int = 0
        
        class TestStringsSwift: NSObject {
            @Published var string1 = "Hello"
            @Published var string2 = "World"
        }
        
        let testObject = TestStringsSwift()
        
        var cancellables = Set<AnyCancellable>()
        
        testObject.$string1.dropFirst()
            .sink { [weak testObject] newValue in
                guard let testObject = testObject else { return }
                guard let lastChar: UInt16 = newValue.utf16.last else { return }
                
                testObject.string2.append(String(format:"\(lastChar + 1)"))
                testObject.string2.append(String(format:"\(lastChar + 2)"))
            }
            .store(in: &cancellables)
        
        testObject.$string2.dropFirst()
            .sink { newValue in
                let lastChar = newValue.utf16.last!
                checkSum += Int(lastChar)
            }
            .store(in: &cancellables)
        
        for i in 0..<iterations {
            testObject.string1.append(String(i))
        }
        
        let endTime = CACurrentMediaTime()
        print("Combine - strings - count: \(iterations), checksum: \(checkSum)")
        
        return endTime - startTime
    }
}
