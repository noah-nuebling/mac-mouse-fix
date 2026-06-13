//
// --------------------------------------------------------------------------
// RemapTableController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

@objc(RemapTableController)
public class RemapTableController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @objc public var dataModel: [Any] {
        get {
            return _dataModel
        }
        set {
            _dataModel = newValue
        }
    }
    private var _dataModel: [Any] = []
    
    @objc public var groupedDataModel: [Any] {
        let baseDataModelHasChanged: Bool
        if baseDataModel_FromLastGroupedDataModelAccess == nil {
            baseDataModelHasChanged = true
        } else if !NSArray(array: baseDataModel_FromLastGroupedDataModelAccess!).isEqual(to: _dataModel) {
            baseDataModelHasChanged = true
        } else {
            baseDataModelHasChanged = false
        }
        
        if baseDataModelHasChanged {
            if let deepCopy = SharedUtility.deepCopy(of: _dataModel) as? [Any] {
                baseDataModel_FromLastGroupedDataModelAccess = deepCopy
                let newGrouped = dataModelByInsertingButtonGroupRows(into: _dataModel)
                groupedDataModel_FromLastGroupedDataModelAccess = newGrouped
                return newGrouped
            }
        }
        return groupedDataModel_FromLastGroupedDataModelAccess ?? []
    }
    
    private var baseDataModel_FromLastGroupedDataModelAccess: [Any]?
    private var groupedDataModel_FromLastGroupedDataModelAccess: [Any]?
    
    public var tableView: NSTableView {
        return self.view as! NSTableView
    }
    
    public var scrollView: NSScrollView? {
        guard let clipView = self.tableView.superview as? NSClipView else { return nil }
        return clipView.superview as? NSScrollView
    }
    
    public var dataSource: RemapTableTranslator? {
        return self.tableView.dataSource as? RemapTableTranslator
    }
    
    @IBOutlet weak var addRemoveControl: MFSegmentedControl?
    
    private var effectiveAppearanceIsInitialized = false
    private var initialAppearance: NSAppearance.Name = .init("")
    
    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        assert(MainAppState.shared.remapTableController == nil, "RemapTableController should only be instantiated once.")
        MainAppState.shared.remapTableController = self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        assert(MainAppState.shared.remapTableController == nil, "RemapTableController should only be instantiated once.")
        MainAppState.shared.remapTableController = self
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        self.scrollView?.autohidesScrollers = true
        self.scrollView?.scrollerStyle = .overlay
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        DDLogDebug("RemapTableView did load.")
        
        guard let scrollView = self.scrollView else { return }
        
        if #available(macOS 26.0, *) {
            scrollView.frame = scrollView.frame.insetBy(dx: 1, dy: 1)
        } else if #available(macOS 10.14, *) {
            // Do nothing
        } else {
            scrollView.frame = scrollView.frame.insetBy(dx: 2, dy: 2)
        }
        
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.layer?.borderWidth = 1.0
        
        if #available(macOS 26.0, *) {
            scrollView.layer?.cornerRadius = 7.0
            scrollView.layer?.cornerCurve = .continuous
            if runningPreRelease() {
                DispatchQueue.main.async {
                    if let contentView = MainAppState.shared.window?.contentView {
                        assert(contentView.prefersCompactControlSizeMetrics)
                    }
                }
            }
        } else {
            scrollView.layer?.cornerRadius = CGFloat(MFNSBoxCornerRadius())
        }
        
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        
        updateBorderColor(isInitialAppearance: true)
        
        if #available(macOS 10.14, *) {
            NSApp.addObserver(self, forKeyPath: "effectiveAppearance", options: .new, context: nil)
        }
        
        RemapTableTranslator.initialize(with: self.tableView)
        self.initSorting()
        self.loadDataModelFromConfig()
        self.sortDataModel()
        self.tableView.reloadData()
        
        (self.tableView as? RemapTableView)?.coolDidLoad()
        self.updateAddRemoveControl()
    }
    
    deinit {
        if #available(macOS 10.14, *) {
            NSApp.removeObserver(self, forKeyPath: "effectiveAppearance")
        }
    }
    
    private func updateBorderColor(isInitialAppearance: Bool) {
        guard let scrollView = self.scrollView else { return }
        
        var isDarkMode = false
        if #available(macOS 10.14, *) {
            isDarkMode = NSApp.effectiveAppearance.name == .darkAqua
        }
        
        scrollView.layer?.borderColor = NSColor.blue.cgColor
        
        if isInitialAppearance {
            if #available(macOS 10.14, *) {
                scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
            } else {
                scrollView.layer?.borderColor = NSColor.gridColor.cgColor
            }
        } else {
            if isDarkMode {
                scrollView.layer?.borderColor = NSColor(red: 57.0/255.0, green: 57.0/255.0, blue: 57.0/255.0, alpha: 1.0).cgColor
            } else {
                scrollView.layer?.borderColor = NSColor(red: 227.0/255.0, green: 227.0/255.0, blue: 227.0/255.0, alpha: 1.0).cgColor
            }
        }
        scrollView.needsDisplay = true
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "effectiveAppearance" {
            guard let newAppearance = change?[.newKey] as? NSAppearance else { return }
            
            if !effectiveAppearanceIsInitialized {
                effectiveAppearanceIsInitialized = true
                initialAppearance = self.tableView.effectiveAppearance.name
            } else {
                let isInitial = initialAppearance == newAppearance.name
                updateBorderColor(isInitialAppearance: isInitial)
                self.tableView.updateLayer()
                self.tableView.reloadData()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    @objc public func loadDataModelFromConfig() {
        self.dataModel = Config.shared.config[kMFConfigKeyRemaps] as? [Any] ?? []
    }
    
    @objc public func writeDataModelToConfig() {
        DDLogDebug("TRM remap table store remaps")
        setConfig(kMFConfigKeyRemaps, self.dataModel as NSArray)
        commitConfig()
    }
    
    private func reloadDataWithTemporaryDataModel(_ tempDataModel: [Any]) {
        let store = self.dataModel
        self.dataModel = tempDataModel
        self.tableView.reloadData()
        self.tableView.displayIfNeeded()
        if #available(macOS 10.14, *) { } else {
            self.tableView.needsLayout = true
            self.tableView.layoutSubtreeIfNeeded()
        }
        self.dataModel = store
    }
    
    @IBAction public func handleKeystrokeMenuItemSelected(_ sender: Any) {
        guard let item = sender as? NSMenuItem, let menu = item.menu else { return }
        var rowOfSender = -1
        
        for row in 0..<self.groupedDataModel.count {
            if let cell = self.tableView.view(atColumn: 1, row: row, makeIfNecessary: true),
               let pb = cell.subviews.first as? NSPopUpButton,
               pb.menu == menu {
                rowOfSender = row
                break
            }
        }
        
        assert(rowOfSender != -1)
        rowOfSender = RemapTableUtility.baseDataModelIndex(fromGroupedDataModelIndex: rowOfSender, withGroupedDataModel: self.groupedDataModel)
        
        guard var dataModelWithCaptureCell = SharedUtility.deepCopy(of: self.dataModel) as? [[AnyHashable: Any]] else { return }
        dataModelWithCaptureCell[rowOfSender][kMFRemapsKeyEffect] = ["drawKeyCaptureView": true]
        self.reloadDataWithTemporaryDataModel(dataModelWithCaptureCell)
    }
    
    private func storeEffectsFromUIInDataModel() {
        let localGroupedModel = self.groupedDataModel
        var localDataModel = self.dataModel
        var row = 0
        for rowGrouped in 0..<localGroupedModel.count {
            if let dict = localGroupedModel[rowGrouped] as? [AnyHashable: Any],
               NSDictionary(dictionary: dict).isEqual(to: RemapTableUtility.buttonGroupRowDict) {
                continue
            }
            
            if let cell = self.tableView.view(atColumn: 1, row: rowGrouped, makeIfNecessary: true) {
                if cell.identifier == NSUserInterfaceItemIdentifier("effectCell") {
                    if let pb = cell.subviews.first(where: { $0 is NSPopUpButton }) as? NSPopUpButton,
                       row < localDataModel.count,
                       let rowDict = localDataModel[row] as? [AnyHashable: Any] {
                        let effectDictForSelected = RemapTableTranslator.getEffectDictBasedOnSelectedItem(in: pb, rowDict: rowDict)
                        print("DEBUG storeEffects: rowGrouped=\(rowGrouped), row=\(row), selectedIndex=\(pb.indexOfSelectedItem), selectedTitle=\(pb.selectedItem?.title ?? "nil"), effectDictForSelected=\(String(describing: effectDictForSelected))")
                        var mutableRowDict = rowDict
                        mutableRowDict[kMFRemapsKeyEffect] = effectDictForSelected
                        localDataModel[row] = mutableRowDict
                    }
                } else if cell.identifier == NSUserInterfaceItemIdentifier("keyCaptureCell") {
                    // Do nothing for key capture cells, their state is already managed in dataModel
                } else {
                    assert(false, "Unknown cell identifier: \(String(describing: cell.identifier))")
                }
            }
            row += 1
        }
        self.dataModel = localDataModel
    }
    
    @objc public func writeToConfig() {
        self.storeEffectsFromUIInDataModel()
        self.writeDataModelToConfig()
    }
    
    @IBAction public func updateTableAndWriteToConfig(_ sender: Any?) {
        if let menuItem = sender as? RemapTableMenuItem,
           let represented = menuItem.representedObject as? [AnyHashable: Any],
           let effectDict = represented["dict"] as? [AnyHashable: Any],
           let host = menuItem.host {
            let rowGrouped = RemapTableUtility.row(ofCell: host, in: self.tableView)
            let baseRow = RemapTableUtility.baseDataModelIndex(fromGroupedDataModelIndex: rowGrouped, withGroupedDataModel: self.groupedDataModel)
            if baseRow < self.dataModel.count,
               var baseRowDict = self.dataModel[baseRow] as? [AnyHashable: Any] {
                print("DEBUG: updateTableAndWriteToConfig matching menuItem - baseRow=\(baseRow), effectDict=\(effectDict)")
                baseRowDict[kMFRemapsKeyEffect] = effectDict
                self.dataModel[baseRow] = baseRowDict
                self.writeDataModelToConfig()
                
                self.tableView.reloadData(forRowIndexes: IndexSet(integer: rowGrouped), columnIndexes: IndexSet(integersIn: 0..<2))
                return
            }
        }
        
        self.writeToConfig()
        
        if let menuItem = sender as? RemapTableMenuItem, let host = menuItem.host {
            let row = RemapTableUtility.row(ofCell: host, in: self.tableView)
            self.tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<2))
        } else {
            self.tableView.reloadData()
        }
    }
    
    @IBAction public func submenuItemClicked(_ item: NSMenuItem) {
        var rootItem = item
        while true {
            if let nextRoot = rootItem.parent {
                rootItem = nextRoot
            } else {
                break
            }
        }
        guard let rootMenu = rootItem.menu else { return }
        
        var clickedRow = -1
        for row in 0..<self.tableView.numberOfRows {
            if let effectCell = self.tableView.view(atColumn: 1, row: row, makeIfNecessary: true),
               let pb = effectCell.subviews.first as? NSPopUpButton,
               pb.menu == rootMenu {
                clickedRow = row
                break
            }
        }
        
        if clickedRow == -1 {
            DDLogError("Couldn't find clickedRow in submenu item IBAction")
            return
        }
        
        let clickedRowInBaseDataModel = RemapTableUtility.baseDataModelIndex(fromGroupedDataModelIndex: clickedRow, withGroupedDataModel: self.groupedDataModel)
        
        if let itemModel = item.representedObject as? [AnyHashable: Any],
           var mutableRowDict = self.dataModel[clickedRowInBaseDataModel] as? [AnyHashable: Any] {
            mutableRowDict[kMFRemapsKeyEffect] = itemModel["dict"]
            self.dataModel[clickedRowInBaseDataModel] = mutableRowDict
        }
        
        self.writeDataModelToConfig()
        self.tableView.reloadData()
    }
    
    @objc public func reloadAll() {
        let allRowsOld = IndexSet(integersIn: 0..<self.groupedDataModel.count)
        self.loadDataModelFromConfig()
        self.sortDataModel()
        
        let allRows = IndexSet(integersIn: 0..<self.groupedDataModel.count)
        self.tableView.removeRows(at: allRowsOld, withAnimation: [])
        self.tableView.insertRows(at: allRows, withAnimation: [])
        
        (self.tableView as? RemapTableView)?.updateSizeWithAnimation()
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        self.updateAddRemoveControl()
    }
    
    private func updateAddRemoveControl() {
        if self.tableView.selectedRow == -1 {
            self.addRemoveControl?.setEnabled(false, forSegment: 1)
        } else {
            self.addRemoveControl?.setEnabled(true, forSegment: 1)
        }
    }
    
    @IBAction func addRemoveControl(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            self.addButtonAction()
        } else {
            if self.tableView.selectedRowIndexes.count == 0 { return }
            assert(self.tableView.selectedRowIndexes.count == 1)
            let selectedRow = self.tableView.selectedRowIndexes.first!
            self.removeRow(selectedRow)
        }
    }
    
    @IBAction func inRowRemoveButtonAction(_ sender: RemapTableButton) {
        guard let host = sender.host else { return }
        let result = RemapTableUtility.row(ofCell: host, in: self.tableView)
        sender.host = nil
        if result != -1 {
            self.coolRemoveRow(result)
        }
    }
    
    private func coolRemoveRow(_ row: Int) {
        self.removeRow(row)
        (self.tableView as? RemapTableView)?.updateSizeWithAnimation()
    }
    
    private func removeRow(_ rowToRemove: Int) {
        let capturedButtonsBefore = RemapTableUtility.getCapturedButtonsAndExcludeButtonsThatAreOnlyCaptured(byModifier: false)
        let dataModelRowToRemove = RemapTableUtility.baseDataModelIndex(fromGroupedDataModelIndex: rowToRemove, withGroupedDataModel: self.groupedDataModel)
        
        guard let removedRowDict = self.dataModel[dataModelRowToRemove] as? [AnyHashable: Any] else { return }
        
        var mutableDataModel = self.dataModel
        mutableDataModel.remove(at: dataModelRowToRemove)
        self.dataModel = mutableDataModel
        self.writeDataModelToConfig()
        self.loadDataModelFromConfig()
        
        let rowsToRemoveWithAnimation = NSMutableIndexSet(index: rowToRemove)
        let removedRowTriggerButton = RemapTableUtility.triggerButton(forRow: removedRowDict)
        var buttonIsStillTriggerInDataModel = false
        for item in self.dataModel {
            if let rowDict = item as? [AnyHashable: Any],
               RemapTableUtility.triggerButton(forRow: rowDict) == removedRowTriggerButton {
                buttonIsStillTriggerInDataModel = true
                break
            }
        }
        if !buttonIsStillTriggerInDataModel {
            rowsToRemoveWithAnimation.add(rowToRemove - 1)
        }
        
        self.tableView.removeRows(at: rowsToRemoveWithAnimation as IndexSet, withAnimation: .slideUp)
        
        let capturedButtonsAfter = RemapTableUtility.getCapturedButtonsAndExcludeButtonsThatAreOnlyCaptured(byModifier: false)
        CaptureToasts.showButtonCaptureToastWith(before: capturedButtonsBefore, after: capturedButtonsAfter)
    }
    
    private func addButtonAction() {
        // [AddWindowController begin] is disabled in ObjC
    }
    
    @objc public func addRow(withHelperPayload payload: [AnyHashable: Any]) {
        let capturedButtonsBefore = RemapTableUtility.getCapturedButtonsAndExcludeButtonsThatAreOnlyCaptured(byModifier: false)
        self.tableView.window?.makeFirstResponder(self.tableView)
        
        var rowDictToAdd = payload
        
        let existingIndexes = (self.groupedDataModel as NSArray).indexesOfObjects(passingTest: { (tableEntryObj, idx, stop) -> Bool in
            guard let tableEntry = tableEntryObj as? [AnyHashable: Any] else { return false }
            if NSDictionary(dictionary: tableEntry).isEqual(to: RemapTableUtility.buttonGroupRowDict) {
                return false
            }
            
            let triggerMatches: Bool
            if let entryTrigger = tableEntry[kMFRemapsKeyTrigger], let addTrigger = rowDictToAdd[kMFRemapsKeyTrigger] {
                if let entryDict = entryTrigger as? [AnyHashable: Any], let addDict = addTrigger as? [AnyHashable: Any] {
                    triggerMatches = NSDictionary(dictionary: entryDict).isEqual(to: addDict)
                } else if let entryStr = entryTrigger as? String, let addStr = addTrigger as? String {
                    triggerMatches = entryStr == addStr
                } else {
                    triggerMatches = false
                }
            } else {
                triggerMatches = false
            }
            
            let entryPrecond = tableEntry[kMFRemapsKeyModificationPrecondition] as? [AnyHashable: Any]
            let addPrecond = rowDictToAdd[kMFRemapsKeyModificationPrecondition] as? [AnyHashable: Any]
            let modificationPreconditionMatches = NSDictionary(dictionary: entryPrecond ?? [:]).isEqual(to: addPrecond ?? [:])
            
            return triggerMatches && modificationPreconditionMatches
        })
        
        assert(existingIndexes.count <= 1, "Duplicate remap triggers found in table")
        var toHighlightIndexSet: IndexSet
        
        if existingIndexes.count == 0 {
            if let firstEffect = RemapTableTranslator.getEffectsTable(forRemapsTableEntry: rowDictToAdd).first as? [AnyHashable: Any] {
                rowDictToAdd[kMFRemapsKeyEffect] = firstEffect["dict"]
            }
            self.dataModel = self.dataModel + [rowDictToAdd]
            self.sortDataModel()
            
            let insertedIndex = self.groupedDataModel.firstIndex(where: { (item) -> Bool in
                guard let dict = item as? [AnyHashable: Any] else { return false }
                return NSDictionary(dictionary: dict).isEqual(to: rowDictToAdd)
            }) ?? 0
            
            let toInsertWithAnimationIndexSet = NSMutableIndexSet(index: insertedIndex)
            toHighlightIndexSet = IndexSet(integer: insertedIndex)
            
            var buttonIsNewlyTriggerInDataModel = true
            let triggerButtonForAddedRow = RemapTableUtility.triggerButton(forRow: rowDictToAdd)
            for item in self.dataModel {
                guard let rowDict = item as? [AnyHashable: Any] else { continue }
                if NSDictionary(dictionary: rowDict).isEqual(to: rowDictToAdd) { continue }
                if RemapTableUtility.triggerButton(forRow: rowDict) == triggerButtonForAddedRow {
                    buttonIsNewlyTriggerInDataModel = false
                    break
                }
            }
            
            if buttonIsNewlyTriggerInDataModel {
                toInsertWithAnimationIndexSet.add(insertedIndex - 1)
            }
            
            self.tableView.insertRows(at: toInsertWithAnimationIndexSet as IndexSet, withAnimation: .slideDown)
            (self.tableView as? RemapTableView)?.updateSizeWithAnimation()
            self.writeToConfig()
        } else {
            toHighlightIndexSet = existingIndexes
        }
        
        self.tableView.selectRowIndexes(toHighlightIndexSet, byExtendingSelection: false)
        self.tableView.scrollRowToVisible(toHighlightIndexSet.first!)
        
        var clickMonitor: Any? = nil
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return event }
            self.tableView.deselectAll(nil)
            if let monitor = clickMonitor {
                NSEvent.removeMonitor(monitor)
                clickMonitor = nil
            }
            return event
        }
        
        let openPopupRow = toHighlightIndexSet.first!
        let popUpButton = RemapTableUtility.getPopUpButton(atRow: UInt(openPopupRow), from: self.tableView)
        let delay = existingIndexes.count == 1 ? 0.0 : 0.2
        popUpButton.perform(#selector(NSButton.performClick(_:)), with: nil as Any?, afterDelay: delay)
        
        let capturedButtonsAfter = RemapTableUtility.getCapturedButtonsAndExcludeButtonsThatAreOnlyCaptured(byModifier: false)
        CaptureToasts.showButtonCaptureToastWith(before: capturedButtonsBefore, after: capturedButtonsAfter)
    }
    
    // MARK: - Data source
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let rowDict = self.groupedDataModel[row] as? [AnyHashable: Any] else { return nil }
        
        if NSDictionary(dictionary: rowDict).isEqual(to: RemapTableUtility.buttonGroupRowDict) {
            let buttonGroupCell = self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("buttonGroupCell"), owner: self)
            if let groupTextField = (buttonGroupCell?.nextKeyView ?? buttonGroupCell?.subviews.first) as? NSTextField {
                let nextRowDict = self.groupedDataModel[row + 1] as? [AnyHashable: Any] ?? [:]
                let groupButtonNumber = RemapTableUtility.triggerButton(forRow: nextRowDict)
                let btnStrOpt = UIStrings.getButtonString(groupButtonNumber, context: kMFButtonStringUsageContextActionTableGroupRow)
                let btnStr = (btnStrOpt as NSString?)?.firstCaptialized() as String? ?? ""
                groupTextField.stringValue = "  \(btnStr)"
                
                if #available(macOS 11.0, *) { } else {
                    if let superview = groupTextField.superview {
                        for c in superview.constraints {
                            if c.firstAttribute == .leading || c.secondAttribute == .leading {
                                c.constant += 8
                                break
                            }
                        }
                    }
                }
            }
            return buttonGroupCell
        }
        
        guard let deepCopy = SharedUtility.deepCopy(of: rowDict) as? [AnyHashable: Any],
              let col = tableColumn else { return nil }
        
        if col.identifier.rawValue == "trigger" {
            return RemapTableTranslator.getTriggerCell(withRowDict: deepCopy, row: row)
        } else if col.identifier.rawValue == "effect" {
            return RemapTableTranslator.getEffectCell(withRowDict: deepCopy, row: UInt(row), tableViewEnabled: tableView.isEnabled)
        } else {
            let exc = NSException(name: NSExceptionName("Unknown column identifier"),
                                  reason: "TableView is requesting data for a column with an unknown identifier",
                                  userInfo: ["requested data for column": col])
            exc.raise()
            return nil
        }
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return self.groupedDataModel.count
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let rowDict = self.groupedDataModel[row] as? [AnyHashable: Any] else { return 38 }
        
        var height: CGFloat = 0
        if NSDictionary(dictionary: rowDict).isEqual(to: RemapTableUtility.buttonGroupRowDict) {
            let buttonGroupCell = self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("buttonGroupCell"), owner: self)
            height = buttonGroupCell?.frame.size.height ?? 22
            if height <= 0 {
                height = 22
            }
        } else {
            let colwidth = self.tableView.tableColumns[0].width
            let deepCopy = SharedUtility.deepCopy(of: rowDict) as? [AnyHashable: Any] ?? rowDict
            let triggerCellView = RemapTableTranslator.getTriggerCell(withRowDict: deepCopy, row: row)
            triggerCellView.setFrameSize(NSSize(width: colwidth, height: triggerCellView.frame.size.height))
            triggerCellView.layoutSubtreeIfNeeded()
            height = triggerCellView.frame.size.height
            if height <= 0 {
                height = 38
            }
        }
        return height
    }
    
    @objc public func sortDataModel() {
        self.dataModel = self.sortedDataModel(self.dataModel)
    }
    
    private func sortedDataModel(_ dataModel: [Any]) -> [Any] {
        return (dataModel as NSArray).sortedArray(using: self.tableView.sortDescriptors)
    }
    
    private func getTriggerValues(_ tableEntryMutable: NSMutableDictionary, btn: inout Int32, lvl: inout Int32, dur: inout String, type: inout String) {
        guard let trigger = tableEntryMutable[kMFRemapsKeyTrigger] else { return }
        if !(trigger is String) {
            type = "button"
            if let trigDict = trigger as? [AnyHashable: Any] {
                btn = (trigDict[kMFButtonTriggerKeyButtonNumber] as? NSNumber)?.int32Value ?? 0
                lvl = (trigDict[kMFButtonTriggerKeyClickLevel] as? NSNumber)?.int32Value ?? 0
                dur = (trigDict[kMFButtonTriggerKeyDuration] as? String) ?? ""
            }
        } else {
            if let preconds = tableEntryMutable[kMFRemapsKeyModificationPrecondition] as? [AnyHashable: Any],
               let buttons = preconds[kMFModificationPreconditionKeyButtons] as? [Any],
               var buttonPreconds = SharedUtility.deepCopy(of: buttons) as? [[AnyHashable: Any]],
               let lastButtonPress = buttonPreconds.last {
                buttonPreconds.removeLast()
                
                let mutablePreconds = NSMutableDictionary(dictionary: preconds)
                mutablePreconds[kMFModificationPreconditionKeyButtons] = buttonPreconds
                tableEntryMutable[kMFRemapsKeyModificationPrecondition] = mutablePreconds
                
                btn = (lastButtonPress[kMFButtonModificationPreconditionKeyButtonNumber] as? NSNumber)?.int32Value ?? 0
                lvl = (lastButtonPress[kMFButtonModificationPreconditionKeyClickLevel] as? NSNumber)?.int32Value ?? 0
                dur = ""
                
                if (trigger as? String) == kMFTriggerDrag {
                    type = "drag"
                } else if (trigger as? String) == kMFTriggerScroll {
                    type = "scroll"
                }
            }
        }
    }
    
    private func initSorting() {
        let sd = NSSortDescriptor(key: nil, ascending: true) { [weak self] (obj1, obj2) -> ComparisonResult in
            guard let self = self,
                  let tableEntry1 = obj1 as? [AnyHashable: Any],
                  let tableEntry2 = obj2 as? [AnyHashable: Any] else { return .orderedSame }
            
            let tableEntryMutable1 = NSMutableDictionary(dictionary: SharedUtility.deepMutableCopy(of: tableEntry1) as? [AnyHashable: Any] ?? [:])
            let tableEntryMutable2 = NSMutableDictionary(dictionary: SharedUtility.deepMutableCopy(of: tableEntry2) as? [AnyHashable: Any] ?? [:])
            
            var btn1: Int32 = 0
            var lvl1: Int32 = 0
            var dur1 = ""
            var type1 = ""
            self.getTriggerValues(tableEntryMutable1, btn: &btn1, lvl: &lvl1, dur: &dur1, type: &type1)
            
            var btn2: Int32 = 0
            var lvl2: Int32 = 0
            var dur2 = ""
            var type2 = ""
            self.getTriggerValues(tableEntryMutable2, btn: &btn2, lvl: &lvl2, dur: &dur2, type: &type2)
            
            if btn1 > btn2 { return .orderedDescending }
            if btn1 < btn2 { return .orderedAscending }
            
            let preconds1 = tableEntryMutable1[kMFRemapsKeyModificationPrecondition] as? [AnyHashable: Any] ?? [:]
            let preconds2 = tableEntryMutable2[kMFRemapsKeyModificationPrecondition] as? [AnyHashable: Any] ?? [:]
            
            let buttonSequence1 = preconds1[kMFModificationPreconditionKeyButtons] as? [Any] ?? []
            let buttonSequence2 = preconds2[kMFModificationPreconditionKeyButtons] as? [Any] ?? []
            let iterMax = min(buttonSequence1.count, buttonSequence2.count)
            DDLogInfo("DEBUG - buttonSequence1: \(buttonSequence1), buttonSequence2: \(buttonSequence2), iterMax: \(iterMax)")
            
            for i in 0..<iterMax {
                guard let buttonPress1 = buttonSequence1[i] as? [AnyHashable: Any],
                      let buttonPress2 = buttonSequence2[i] as? [AnyHashable: Any] else { continue }
                
                let b1 = (buttonPress1[kMFButtonModificationPreconditionKeyButtonNumber] as? NSNumber)?.int32Value ?? 0
                let b2 = (buttonPress2[kMFButtonModificationPreconditionKeyButtonNumber] as? NSNumber)?.int32Value ?? 0
                let l1 = (buttonPress1[kMFButtonModificationPreconditionKeyClickLevel] as? NSNumber)?.int32Value ?? 0
                let l2 = (buttonPress2[kMFButtonModificationPreconditionKeyClickLevel] as? NSNumber)?.int32Value ?? 0
                
                if b1 > b2 { return .orderedDescending }
                if b1 < b2 { return .orderedAscending }
                if l1 > l2 { return .orderedDescending }
                if l1 < l2 { return .orderedAscending }
            }
            
            if buttonSequence1.count > buttonSequence2.count { return .orderedDescending }
            if buttonSequence1.count < buttonSequence2.count { return .orderedAscending }
            
            let modifierFlags1 = (preconds1[kMFModificationPreconditionKeyKeyboard] as? NSNumber)?.intValue ?? 0
            let modifierFlags2 = (preconds2[kMFModificationPreconditionKeyKeyboard] as? NSNumber)?.intValue ?? 0
            
            if modifierFlags1 > modifierFlags2 { return .orderedDescending }
            if modifierFlags1 < modifierFlags2 { return .orderedAscending }
            
            let orderedTypes = ["button", "scroll", "drag"]
            let typeIndex1 = orderedTypes.firstIndex(of: type1) ?? 0
            let typeIndex2 = orderedTypes.firstIndex(of: type2) ?? 0
            
            if typeIndex1 > typeIndex2 { return .orderedDescending }
            if typeIndex1 < typeIndex2 { return .orderedAscending }
            
            if lvl1 > lvl2 { return .orderedDescending }
            if lvl1 < lvl2 { return .orderedAscending }
            
            let orderedDurations = [kMFButtonTriggerDurationClick, kMFButtonTriggerDurationHold]
            let durationIndex1 = orderedDurations.firstIndex(of: dur1) ?? 0
            let durationIndex2 = orderedDurations.firstIndex(of: dur2) ?? 0
            
            if durationIndex1 > durationIndex2 { return .orderedDescending }
            if durationIndex1 < durationIndex2 { return .orderedAscending }
            
            assert(false)
            return .orderedSame
        }
        self.tableView.sortDescriptors = [sd]
    }
    
    private func dataModelByInsertingButtonGroupRows(into dataModel: [Any]) -> [Any] {
        var groupedDataModel: [Any] = dataModel
        
        var currentButton: Int = -1
        var r = 0
        var insertedCount = 0
        var firstHasBeenOmitted = true
        
        for item in dataModel {
            guard let rowDict = item as? [AnyHashable: Any] else { continue }
            let rowButton = Int(RemapTableUtility.triggerButton(forRow: rowDict).rawValue)
            
            if rowButton > currentButton {
                currentButton = rowButton
                if !firstHasBeenOmitted {
                    firstHasBeenOmitted = true
                } else {
                    groupedDataModel.insert(RemapTableUtility.buttonGroupRowDict, at: r + insertedCount)
                    insertedCount += 1
                }
            } else if rowButton < currentButton {
                let exc = NSException(name: NSExceptionName("DataModelNotSortedByButtonException"), reason: nil, userInfo: ["dataModel": dataModel])
                exc.raise()
            }
            r += 1
        }
        
        return groupedDataModel
    }
    
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let rowDict = self.groupedDataModel[row] as? [AnyHashable: Any] else { return nil }
        if NSDictionary(dictionary: rowDict).isEqual(to: RemapTableUtility.buttonGroupRowDict) {
            return ButtonGroupRowView()
        }
        return nil
    }
    
    private func isGroupRow(_ row: Int) -> Bool {
        guard let rowDict = self.groupedDataModel[row] as? [AnyHashable: Any] else { return false }
        return NSDictionary(dictionary: rowDict).isEqual(to: RemapTableUtility.buttonGroupRowDict)
    }
    
    public func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return self.isGroupRow(row)
    }
    
    public func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return !self.isGroupRow(row) && self.tableView.isEnabled
    }
    
    public func tableView(_ tableView: NSTableView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, row: Int) {
        if self.isGroupRow(row) {
            if let cellView = cell as? NSTableCellView {
                cellView.textField?.textColor = .labelColor
            }
        }
    }
}
