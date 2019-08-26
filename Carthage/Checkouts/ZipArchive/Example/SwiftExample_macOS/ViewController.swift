//
//  ViewController.swift
//  SwiftExample_macOS
//
//  Created by Antoine Cœur on 2019/4/26.
//

import Cocoa

#if UseCarthage
import ZipArchive
#else
import SSZipArchive
#endif

class ViewController: NSViewController {

    @IBOutlet weak var passwordField: NSTextField!
    @IBOutlet weak var zipButton: NSButton!
    @IBOutlet weak var unzipButton: NSButton!
    @IBOutlet weak var hasPasswordButton: NSButton!
    @IBOutlet weak var resetButton: NSButton!
    
    @IBOutlet weak var file1: NSTextField!
    @IBOutlet weak var file2: NSTextField!
    @IBOutlet weak var file3: NSTextField!
    @IBOutlet weak var info: NSTextField!
    
    var samplePath: String!
    var zipPath: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        samplePath = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Sample Data").path
        print("Sample path:", samplePath!)
        
        resetPressed(resetButton)
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    // MARK: IBAction
    
    @IBAction func zipPressed(_: NSButton) {
        zipPath = tempZipPath()
        print("Zip path:", zipPath!)
        let password = passwordField.stringValue
        
        let success = SSZipArchive.createZipFile(atPath: zipPath!,
                                                 withContentsOfDirectory: samplePath,
                                                 keepParentDirectory: false,
                                                 compressionLevel: -1,
                                                 password: !password.isEmpty ? password : nil,
                                                 aes: true,
                                                 progressHandler: nil)
        if success {
            print("Success zip")
            info.stringValue = "Success zip"
            unzipButton.isEnabled = true
            hasPasswordButton.isEnabled = true
        } else {
            print("No success zip")
            info.stringValue = "No success zip"
        }
        resetButton.isEnabled = true
    }
    
    @IBAction func unzipPressed(_: NSButton) {
        guard let zipPath = self.zipPath else {
            return
        }
        
        guard let unzipPath = tempUnzipPath() else {
            return
        }
        print("Unzip path:", unzipPath)
        
        let password = passwordField.stringValue
        let success: Bool = SSZipArchive.unzipFile(atPath: zipPath,
                                                   toDestination: unzipPath,
                                                   preserveAttributes: true,
                                                   overwrite: true,
                                                   nestedZipLevel: 1,
                                                   password: !password.isEmpty ? password : nil,
                                                   error: nil,
                                                   delegate: nil,
                                                   progressHandler: nil,
                                                   completionHandler: nil)
        if success != false {
            print("Success unzip")
            info.stringValue = "Success unzip"
        } else {
            print("No success unzip")
            info.stringValue = "No success unzip"
            return
        }
        
        var items: [String]
        do {
            items = try FileManager.default.contentsOfDirectory(atPath: unzipPath)
        } catch {
            return
        }
        
        for (index, item) in items.enumerated() {
            switch index {
            case 0:
                file1.stringValue = item
            case 1:
                file2.stringValue = item
            case 2:
                file3.stringValue = item
            default:
                print("Went beyond index of assumed files")
            }
        }
        
        unzipButton.isEnabled = false
    }
    
    @IBAction func hasPasswordPressed(_: NSButton) {
        guard let zipPath = zipPath else {
            return
        }
        let success = SSZipArchive.isFilePasswordProtected(atPath: zipPath)
        if success {
            print("Yes, it's password protected.")
            info.stringValue = "Yes, it's password protected."
        } else {
            print("No, it's not password protected.")
            info.stringValue = "No, it's not password protected."
        }
    }
    
    @IBAction func resetPressed(_: NSButton) {
        file1.stringValue = ""
        file2.stringValue = ""
        file3.stringValue = ""
        info.stringValue = ""
        zipButton.isEnabled = true
        unzipButton.isEnabled = false
        hasPasswordButton.isEnabled = false
        resetButton.isEnabled = false
    }
    
    // MARK: Private
    
    func tempZipPath() -> String {
        var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        path += "/\(UUID().uuidString).zip"
        return path
    }
    
    func tempUnzipPath() -> String? {
        var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        path += "/\(UUID().uuidString)"
        let url = URL(fileURLWithPath: path)
        
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
        return url.path
    }
}
