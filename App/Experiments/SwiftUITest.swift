//
//  SwiftUITest.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 16.06.22.
//

/// Playing around with SwiftUI
///     But Section doesn't create Ventura System Settings-like groupings, and I can't get the Ventura-like small Toggles to work either. (Running on Monterey 12.4)
///     I could make custom ToggleStyle implementations and a custom Section implementation to style things like Ventura, but probably not worth it.

//import SwiftUI
//
//struct SwiftUITest: View {
//    var body: some View {
//        if #available(macOS 12.0, *) {
//            Form {
//                    Section("Settings") {
//                        Toggle("Setting #1", isOn: .constant(true))
//                        Toggle("Setting #2", isOn: .constant(false))
//                    }
//                
//                Section("More Settings") {
//                    Toggle("Setting #3", isOn: .constant(true))
//                    Picker("Select One", selection: .constant("someTag")) {
//                        XXXText("Chocolate").tag("someTag")                   // Put XXX here so that extractLocStrings doesn't try to translate this.
//                        XXXText("Strawberry").tag("anotherTag")
//                        XXXText("Vanilla").tag("totallyOtherTag")
//                    }
//                }
//            }.navigationTitle("Settings Form").pickerStyle(.menu).toggleStyle(.switch)
//        } else {
//            // Fallback on earlier versions
//        }
//            
//    }
//}
//
//struct SwiftUITest_Previews: PreviewProvider {
//    static var previews: some View {
//        SwiftUITest()
//    }
//}
