/*:
 > # IMPORTANT: To use `ReactiveSwift.playground`, please:
 
 1. Retrieve the project dependencies using one of the following terminal commands from the ReactiveSwift project root directory:
    - `git submodule update --init`
 **OR**, if you have [Carthage](https://github.com/Carthage/Carthage) installed
    - `carthage checkout`
 1. Open `ReactiveSwift.xcworkspace`
 1. Build `ReactiveSwift-macOS` scheme
 1. Finally open the `ReactiveSwift.playground`
 1. Choose `View > Show Debug Area`
 */
import ReactiveSwift
import Foundation
/*:
 ## Property
 
 A **property**, represented by the [`PropertyProtocol`](https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/Property.swift) ,
 stores a value and notifies observers about future changes to that value.
 
 - The current value of a property can be obtained from the `value` getter.
 - The `producer` getter returns a [signal producer](SignalProducer) that will send the property’s current value, followed by all changes over time.
 - The `signal` getter returns a [signal](Signal) that will send all changes over time, but not the initial value.
 
 */
scopedExample("Creation") {
    let mutableProperty = MutableProperty(1)
    
    // The value of the property can be accessed via its `value` attribute
    print("Property has initial value \(mutableProperty.value)")
    // The properties value can be observed via its `producer` or `signal attribute`
    // Note, how the `producer` immediately sends the initial value, but the `signal` only sends new values
    mutableProperty.producer.startWithValues {
        print("mutableProperty.producer received \($0)")
    }
    mutableProperty.signal.observeValues {
        print("mutableProperty.signal received \($0)")
    }
    
    print("---")
    print("Setting new value for mutableProperty: 2")
    mutableProperty.value = 2

    print("---")
    // If a property should be exposed for readonly access, it can be wrapped in a Property
    let property = Property(mutableProperty)
    
    print("Reading value of readonly property: \(property.value)")
    property.signal.observeValues {
        print("property.signal received \($0)")
    }
    
    // Its not possible to set the value of a Property
//    readonlyProperty.value = 3
    // But you can still change the value of the mutableProperty and observe its change on the property
    print("---")
    print("Setting new value for mutableProperty: 3")
    mutableProperty.value = 3
    
    // Constant properties can be created by using the `Property(value:)` initializer
    let constant = Property(value: 1)
//    constant.value = 2    // The value of a constant property can not be changed
}
/*:
 ### Binding
 
 The `<~` operator can be used to bind properties in different ways. Note that in
 all cases, the target has to be a binding target, represented by the [`BindingTargetProvider`](https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/UnidirectionalBinding.swift). All mutable property types, represented by the  [`MutablePropertyProtocol`](https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/Property.swift#L38), are inherently binding targets.
 
 * `property <~ signal` binds a [signal](Signal) to the property, updating the
 property’s value to the latest value sent by the signal.
 * `property <~ producer` starts the given [signal producer](SignalProducer),
 and binds the property’s value to the latest value sent on the started signal.
 * `property <~ otherProperty` binds one property to another, so that the destination
 property’s value is updated whenever the source property is updated.
 */
scopedExample("Binding from SignalProducer") {
    let producer = SignalProducer<Int, Never> { observer, _ in
        print("New subscription, starting operation")
        observer.send(value: 1)
        observer.send(value: 2)
    }
    let property = MutableProperty(0)
    property.producer.startWithValues {
        print("Property received \($0)")
    }
 
    // Notice how the producer will start the work as soon it is bound to the property
    property <~ producer
}

scopedExample("Binding from Signal") {
    let (signal, observer) = Signal<Int, Never>.pipe()
    let property = MutableProperty(0)
    property.producer.startWithValues {
        print("Property received \($0)")
    }
    
    property <~ signal
    
    print("Sending new value on signal: 1")
    observer.send(value: 1)
    
    print("Sending new value on signal: 2")
    observer.send(value: 2)
}

scopedExample("Binding from other Property") {
    let property = MutableProperty(0)
    property.producer.startWithValues {
        print("Property received \($0)")
    }
    
    let otherProperty = MutableProperty(0)
    
    // Notice how property receives another value of 0 as soon as the binding is established
    property <~ otherProperty
    
    print("Setting new value for otherProperty: 1")
    otherProperty.value = 1

    print("Setting new value for otherProperty: 2")
    otherProperty.value = 2
}
/*:
 ### Transformations
 
 Properties provide a number of transformations like `map`, `combineLatest` or `zip` for manipulation similar to [signal](Signal) and [signal producer](SignalProducer)
 */
scopedExample("`map`") {
    let property = MutableProperty(0)
    let mapped = property.map { $0 * 2 }
    mapped.producer.startWithValues {
        print("Mapped property received \($0)")
    }
    
    print("Setting new value for property: 1")
    property.value = 1
    
    print("Setting new value for property: 2")
    property.value = 2
}

scopedExample("`skipRepeats`") {
    let property = MutableProperty(0)
    let skipRepeatsProperty = property.skipRepeats()
    
    property.producer.startWithValues {
        print("Property received \($0)")
    }
    skipRepeatsProperty.producer.startWithValues {
        print("Skip-Repeats property received \($0)")
    }
    
    print("Setting new value for property: 0")
    property.value = 0
    print("Setting new value for property: 1")
    property.value = 1
    print("Setting new value for property: 1")
    property.value = 1
    print("Setting new value for property: 0")
    property.value = 0
}

scopedExample("`uniqueValues`") {
    let property = MutableProperty(0)
    let unique = property.uniqueValues()
    property.producer.startWithValues {
        print("Property received \($0)")
    }
    unique.producer.startWithValues {
        print("Unique values property received \($0)")
    }
    
    print("Setting new value for property: 0")
    property.value = 0
    print("Setting new value for property: 1")
    property.value = 1
    print("Setting new value for property: 1")
    property.value = 1
    print("Setting new value for property: 0")
    property.value = 0

}

scopedExample("`combineLatest`") {
    let propertyA = MutableProperty(0)
    let propertyB = MutableProperty("A")
    let combined = propertyA.combineLatest(with: propertyB)
    combined.producer.startWithValues {
        print("Combined property received \($0)")
    }
    
    print("Setting new value for propertyA: 1")
    propertyA.value = 1
    
    print("Setting new value for propertyB: 'B'")
    propertyB.value = "B"
    
    print("Setting new value for propertyB: 'C'")
    propertyB.value = "C"
    
    print("Setting new value for propertyB: 'D'")
    propertyB.value = "D"
    
    print("Setting new value for propertyA: 2")
    propertyA.value = 2
}

scopedExample("`zip`") {
    let propertyA = MutableProperty(0)
    let propertyB = MutableProperty("A")
    let zipped = propertyA.zip(with: propertyB)
    zipped.producer.startWithValues {
        print("Zipped property received \($0)")
    }
    
    print("Setting new value for propertyA: 1")
    propertyA.value = 1
    
    print("Setting new value for propertyB: 'B'")
    propertyB.value = "B"
    
    // Observe that, in contrast to `combineLatest`, setting a new value for propertyB does not cause a new value for the zipped property until propertyA has a new value as well
    print("Setting new value for propertyB: 'C'")
    propertyB.value = "C"
    
    print("Setting new value for propertyB: 'D'")
    propertyB.value = "D"
    
    print("Setting new value for propertyA: 2")
    propertyA.value = 2
}

scopedExample("`flatten`") {
    let property1 = MutableProperty("0")
    let property2 = MutableProperty("A")
    let property3 = MutableProperty("!")
    let property = MutableProperty(property1)
    // Try different merge strategies and see how the results change
    property.flatten(.latest).producer.startWithValues {
        print("Flattened property receive \($0)")
    }
    
    print("Sending new value on property1: 1")
    property1.value = "1"
    
    print("Sending new value on property: property2")
    property.value = property2
    
    print("Sending new value on property1: 2")
    property1.value = "2"
    
    print("Sending new value on property2: B")
    property2.value = "B"
    
    print("Sending new value on property1: 3")
    property1.value = "3"
    
    print("Sending new value on property: property3")
    property.value = property3
    
    print("Sending new value on property3: ?")
    property3.value = "?"
    
    print("Sending new value on property2: C")
    property2.value = "C"
    
    print("Sending new value on property1: 4")
    property1.value = "4"
}
