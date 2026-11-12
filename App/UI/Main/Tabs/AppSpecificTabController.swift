//
// --------------------------------------------------------------------------
// AppSpecificTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// 'App-specific' tab  [Nov 2026]
///
/// MMF 3 port of MMF 2's `More... > App-specific settings...` panel (See `App/UI/Unused/Overrides/OverridePanel.m`).
/// Lets the user turn off scrolling features for individual apps.
///
/// Config format (same shape MMF 2 used):
///     AppOverrides
///         <bundleID>                      (Raw bundleID as dict key – we don't go through coolKeyPaths here since bundleIDs contain periods)
///             meta
///                 orderKey  : Int         (Order of rows in the table)
///             Root                        (Mirrors the config root. Overrides are applied by the Helper in `Config.m > loadOverridesForApp()`)
///                 Scroll
///                     smooth              : "off"
///                     reverseDirection    : false
///                     modifiers
///                         horizontal      : 0
///                         zoom            : 0
///
/// Most overrides can only turn features *off*. Smooth scrolling is the exception: its checkbox has three states that each set an explicit smoothness for the app,
///     even while smooth scrolling is off in the Scrolling tab:  off -> `off`,  mixed (–) -> `regular`,  on (✓) -> `high`.
///     See `ScrollConfig.swift > App-specific overrides` for why.
///
/// The UI is built in code. The storyboard only provides an empty `wrapperView` (which `TabViewController` needs for its tab-switching animations).

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import UniformTypeIdentifiers

// MARK: - Features

private enum AppSpecificFeature: String, CaseIterable {

    case smooth, reverse, horizontal, zoom

    /// KeyPath inside `AppOverrides.<bundleID>.Root`  (and inside the config root for the global value)
    var keyPath: [String] {
        switch self {
        case .smooth:     return ["Scroll", "smooth"]
        case .reverse:    return ["Scroll", "reverseDirection"]
        case .horizontal: return ["Scroll", "modifiers", "horizontal"]
        case .zoom:       return ["Scroll", "modifiers", "zoom"]
        }
    }

    /// The override value that turns the feature off
    var offValue: NSObject {
        switch self {
        case .smooth:              return "off" as NSString
        case .reverse:             return false as NSNumber
        case .horizontal, .zoom:   return 0 as NSNumber
        }
    }

    /// Smooth scrolling uses a three-state checkbox (see top of file). The other features are plain on/off.
    var isThreeState: Bool { self == .smooth }
    
    /// Whether the user can interact with this column's checkboxes
    ///     The three-state smooth checkbox sets explicit values, so it works even while smooth scrolling is off in the Scrolling tab.
    func isToggleable() -> Bool { return isThreeState || isGloballyOn() }
    
    /// Smoothness <-> checkbox state (smooth column only)
    static func smoothState(for smoothness: String) -> NSControl.StateValue {
        switch smoothness {
        case "off":  return .off
        case "high": return .on
        default:     return .mixed /// "regular" (and the hidden experimental "low")
        }
    }
    static func smoothness(for state: NSControl.StateValue) -> String {
        switch state {
        case .off: return "off"
        case .on:  return "high"
        default:   return "regular"
        }
    }
    
    /// The value to store as override, given a checkbox state. `nil` -> remove the override (follow the Scrolling tab)
    func overrideValue(for state: NSControl.StateValue) -> NSObject? {
        if isThreeState { return Self.smoothness(for: state) as NSString } /// Always explicit
        let enabled = (state == .on)
        if enabled == isGloballyOn() { return nil }
        return enabled ? nil : offValue
    }
    
    func isOff(_ value: Any?) -> Bool {
        guard let value = value as? NSObject else { return false }
        return value.isEqual(offValue)
    }

    /// Whether the feature is on in the global settings (Scrolling tab). Per-app overrides can only turn features off, so if it's globally off, the checkbox is meaningless.
    func isGloballyOn() -> Bool {
        let v = config(keyPath.joined(separator: "."))
        return v != nil && !isOff(v)
    }

    var globalModifierFlags: CGEventFlags? {
        switch self {
        case .horizontal, .zoom:
            guard let n = config(keyPath.joined(separator: ".")) as? NSNumber else { return nil }
            return CGEventFlags(rawValue: n.uint64Value)
        default:
            return nil
        }
    }

    var title: String {
        let base: String
        switch self {
        case .smooth:     base = MFLocalizedString("app-specific.column.smooth",     comment: "Column header in the 'App-specific' tab. Checkbox: whether smooth scrolling is used in this app. Keep it short.")
        case .reverse:    base = MFLocalizedString("app-specific.column.reverse",    comment: "Column header in the 'App-specific' tab. Checkbox: whether 'Reverse direction' (from the Scrolling tab) is used in this app. Keep it short.")
        case .horizontal: base = MFLocalizedString("app-specific.column.horizontal", comment: "Column header in the 'App-specific' tab. Checkbox: whether holding the keyboard modifier for horizontal scrolling (Scrolling > Keyboard Modifiers) works in this app. A modifier symbol like ⇧ is shown in front of this. Keep it short.")
        case .zoom:       base = MFLocalizedString("app-specific.column.zoom",       comment: "Column header in the 'App-specific' tab. Checkbox: whether holding the keyboard modifier for zooming (Scrolling > Keyboard Modifiers) works in this app. A modifier symbol like ⌘ is shown in front of this. Keep it short.")
        }
        if let flags = globalModifierFlags, flags.rawValue != 0 {
            let mods = UIStrings.getKeyboardModifierString(flags)
            if !mods.isEmpty { return "\(mods) \(base)" }
        }
        return base
    }
}

// MARK: - Row model

private struct AppSpecificRow {
    let bundleID: String
    let name: String
    let icon: NSImage
    let isInstalled: Bool
    let orderKey: Int
}

// MARK: - Table view (handles delete key)

private class AppSpecificTableView: NSTableView {
    var onDelete: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.unicodeScalars.first?.value
        if key == UInt32(NSDeleteCharacter) || key == UInt32(NSDeleteFunctionKey) || key == UInt32(NSBackspaceCharacter) {
            onDelete?()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Label that lets clicks and drags through
///     The empty-state label sits on top of the table. Without this, dropping an app onto the middle of the empty table would fail.

private class PassthroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }
}

// MARK: - Controller

class AppSpecificTabController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    /// Outlets
    @IBOutlet weak var wrapperView: NSView!

    /// Views
    private let tableView = AppSpecificTableView()
    private let scrollView = NSScrollView()
    private let addRemoveControl = NSSegmentedControl()
    private let emptyLabel = PassthroughLabel(wrappingLabelWithString: "")
    private let hintLabel = NSTextField(wrappingLabelWithString: "")

    /// Data
    private var rows: [AppSpecificRow] = []

    /// Layout constants
    private let appColumnWidth: CGFloat = 200
    private let featureColumnWidth: CGFloat = 112
    private let tableHeight: CGFloat = 250
    private let margin: CGFloat = 20

    private static let appColumnID = NSUserInterfaceItemIdentifier("app")

    // MARK: Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        buildUI()
        reloadData()

        /// Reload when the config changes
        ///     (E.g. user changes modifiers or turns off smooth scrolling in the Scrolling tab -> column headers / enabled-states change)
        ///     `ReactiveConfig` already dispatches to main.
        ReactiveConfig.shared.signal.take(during: self.reactive.lifetime).observeValues { [weak self] _ in
            self?.reloadData()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        /// Drop keyboard focus when leaving this tab
        ///     Otherwise, after clicking + (which focuses the table), switching tabs makes AppKit move focus into the next tab –
        ///     e.g. into a keyboard-modifier field on the Scrolling tab, which then starts capturing modifiers. [Nov 2026]
        if let window = view.window,
           let responder = window.firstResponder as? NSView,
           responder.isDescendant(of: view) {
            window.makeFirstResponder(nil)
        }
    }
    
    // MARK: Build UI

    private func buildUI() {

        guard let container = wrapperView else { assert(false); return }

        let features = AppSpecificFeature.allCases
        let contentWidth = appColumnWidth + CGFloat(features.count) * featureColumnWidth + 30 /// + intercell spacing & scroller allowance

        /// Hint
        hintLabel.stringValue = MFLocalizedString("app-specific.hint", comment: "Hint at the top of the 'App-specific' tab. Explains that unchecking a box turns off that feature only while the mouse pointer is over that app.")
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        container.addSubview(hintLabel)

        /// Table
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 30
        tableView.intercellSpacing = NSSize(width: 3, height: 2)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.gridStyleMask = [.solidVerticalGridLineMask]
        if #available(macOS 11.0, *) { tableView.style = .fullWidth }
        tableView.onDelete = { [weak self] in self?.removeSelectedApps() }
        tableView.registerForDraggedTypes([.fileURL])

        let appColumn = NSTableColumn(identifier: Self.appColumnID)
        appColumn.title = MFLocalizedString("app-specific.column.app", comment: "Column header in the 'App-specific' tab. The column lists the apps.")
        appColumn.width = appColumnWidth
        appColumn.minWidth = 120
        appColumn.resizingMask = []
        tableView.addTableColumn(appColumn)

        for feature in features {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(feature.rawValue))
            col.width = featureColumnWidth
            col.minWidth = 60
            col.resizingMask = (feature == features.last) ? .autoresizingMask : [] /// Last column absorbs leftover width
            col.headerCell.alignment = .center
            tableView.addTableColumn(col)
        }

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        /// Empty state
        emptyLabel.stringValue = MFLocalizedString("app-specific.empty", comment: "Shown in the empty table of the 'App-specific' tab.")
        emptyLabel.alignment = .center
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(emptyLabel)

        /// +/- control
        addRemoveControl.segmentCount = 2
        addRemoveControl.trackingMode = .momentary
        addRemoveControl.segmentStyle = .smallSquare
        addRemoveControl.setImage(NSImage(named: NSImage.addTemplateName), forSegment: 0)
        addRemoveControl.setImage(NSImage(named: NSImage.removeTemplateName), forSegment: 1)
        addRemoveControl.setWidth(26, forSegment: 0)
        addRemoveControl.setWidth(26, forSegment: 1)
        addRemoveControl.setToolTip(MFLocalizedString("app-specific.add-tooltip",    comment: "Tooltip for the + button in the 'App-specific' tab."), forSegment: 0)
        addRemoveControl.setToolTip(MFLocalizedString("app-specific.remove-tooltip", comment: "Tooltip for the – button in the 'App-specific' tab."), forSegment: 1)
        addRemoveControl.target = self
        addRemoveControl.action = #selector(addRemoveClicked(_:))
        addRemoveControl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(addRemoveControl)

        /// Constraints
        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: margin),
            hintLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: margin),
            hintLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -margin),

            scrollView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: margin),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -margin),
            scrollView.widthAnchor.constraint(equalToConstant: contentWidth),
            scrollView.heightAnchor.constraint(equalToConstant: tableHeight),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor, constant: 10), /// + offset for header
            emptyLabel.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor, constant: -40),

            addRemoveControl.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -1), /// Overlap the border like standard macOS +/- bars
            addRemoveControl.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            addRemoveControl.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -margin),
        ])
        hintLabel.preferredMaxLayoutWidth = contentWidth
    }

    // MARK: Data

    private func appOverrides() -> NSDictionary {
        return (config(kMFConfigKeyAppOverrides) as? NSDictionary) ?? NSDictionary()
    }

    private func reloadData() {

        /// Remember selection
        let selectedIDs = Set(tableView.selectedRowIndexes.compactMap { $0 < rows.count ? rows[$0].bundleID : nil })

        /// Build rows
        let overrides = appOverrides()
        var newRows: [AppSpecificRow] = []
        for (key, value) in overrides {
            guard let bundleID = key as? String, let entry = value as? NSDictionary else { continue }
            let orderKey = ((entry["meta"] as? NSDictionary)?["orderKey"] as? NSNumber)?.intValue ?? Int.max
            newRows.append(Self.makeRow(bundleID: bundleID, orderKey: orderKey))
        }
        newRows.sort { ($0.orderKey, $0.name.lowercased()) < ($1.orderKey, $1.name.lowercased()) }
        rows = newRows

        /// Update column headers (they depend on the global modifier settings)
        for feature in AppSpecificFeature.allCases {
            guard let col = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(feature.rawValue)) else { continue }
            col.title = feature.title
            col.headerToolTip = !feature.isToggleable() ? Self.globallyOffTooltip() : (feature.isThreeState ? Self.smoothStatesTooltip() : feature.title)
        }

        tableView.reloadData()

        /// Restore selection
        let indexes = IndexSet(rows.enumerated().compactMap { selectedIDs.contains($0.element.bundleID) ? $0.offset : nil })
        tableView.selectRowIndexes(indexes, byExtendingSelection: false)

        updateControls()
    }

    private static func makeRow(bundleID: String, orderKey: Int) -> AppSpecificRow {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "", options: [.anchored, .backwards])
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return AppSpecificRow(bundleID: bundleID, name: name, icon: icon, isInstalled: true, orderKey: orderKey)
        } else {
            let icon: NSImage
            if #available(macOS 11.0, *) { icon = NSWorkspace.shared.icon(for: .applicationBundle) }
            else                         { icon = NSWorkspace.shared.icon(forFileType: "com.apple.application-bundle") }
            return AppSpecificRow(bundleID: bundleID, name: bundleID, icon: icon, isInstalled: false, orderKey: orderKey)
        }
    }

    private static func smoothStatesTooltip() -> String {
        return MFLocalizedString("app-specific.smooth-states-tooltip", comment: "Tooltip on the three-state 'Smooth scrolling' checkbox / column header in the 'App-specific' tab. Empty box = off, dash = regular smoothness, checkmark = high smoothness. The smoothness names should match the 'Smoothness' options in the Scrolling tab.")
    }
    
    private static func globallyOffTooltip() -> String {
        return MFLocalizedString("app-specific.globally-off-tooltip", comment: "Tooltip on a disabled checkbox / column header in the 'App-specific' tab. Shown when the feature is turned off for all apps in the Scrolling tab, so there's nothing to turn off per app.")
    }

    private func updateControls() {
        addRemoveControl.setEnabled(tableView.selectedRowIndexes.count > 0, forSegment: 1)
        emptyLabel.isHidden = !rows.isEmpty
    }

    // MARK: Config mutation

    private func mutateAppOverrides(_ body: (NSMutableDictionary) -> Void) {
        let overrides = Self.deepMutableCopy(appOverrides())
        body(overrides)
        setConfig(kMFConfigKeyAppOverrides, overrides)
        commitConfig() /// Writes file, notifies the Helper, and (asynchronously) triggers `ReactiveConfig` -> `reloadData()`
        reloadData()   /// Reload synchronously too, so callers can work with the updated `rows` right away
    }

    private static func deepMutableCopy(_ dict: NSDictionary) -> NSMutableDictionary {
        let result = NSMutableDictionary()
        for (k, v) in dict {
            if let v = v as? NSDictionary { result[k] = deepMutableCopy(v) }
            else                          { result[k] = v }
        }
        return result
    }

    private func checkboxState(_ feature: AppSpecificFeature, bundleID: String) -> NSControl.StateValue {
        /// Effective state for this app: the override if there is one, otherwise the global setting
        var node: Any? = (appOverrides()[bundleID] as? NSDictionary)?["Root"]
        for key in feature.keyPath { node = (node as? NSDictionary)?[key] }
        if feature.isThreeState {
            let smoothness = (node as? String) ?? (config(feature.keyPath.joined(separator: ".")) as? String) ?? "off"
            return AppSpecificFeature.smoothState(for: smoothness)
        }
        if node == nil { return feature.isGloballyOn() ? .on : .off }
        return feature.isOff(node) ? .off : .on
    }

    private func setFeature(_ feature: AppSpecificFeature, state: NSControl.StateValue, bundleIDs: [String]) {
        mutateAppOverrides { overrides in
            for bundleID in bundleIDs {
                guard let entry = overrides[bundleID] as? NSMutableDictionary else { continue }
                if entry["Root"] as? NSMutableDictionary == nil { entry["Root"] = NSMutableDictionary() }
                let root = entry["Root"] as! NSMutableDictionary

                /// Walk to parent dict, creating as needed
                var path: [NSMutableDictionary] = [root]
                for key in feature.keyPath.dropLast() {
                    let parent = path.last!
                    if parent[key] as? NSMutableDictionary == nil { parent[key] = NSMutableDictionary() }
                    path.append(parent[key] as! NSMutableDictionary)
                }
                let leafKey = feature.keyPath.last!
                if let value = feature.overrideValue(for: state) { path.last![leafKey] = value }
                else                                                   { path.last!.removeObject(forKey: leafKey) }

                /// Prune empty dicts (but keep `Root` so the structure stays predictable)
                for (i, key) in feature.keyPath.dropLast().enumerated().reversed() {
                    if path[i + 1].count == 0 { path[i].removeObject(forKey: key) }
                }
            }
        }
    }

    private func addApps(bundleIDs: [String]) {
        let ownIDs: Set<String> = [kMFBundleIDApp, kMFBundleIDHelper]
        let toAdd = bundleIDs.filter { !ownIDs.contains($0) }
        guard !toAdd.isEmpty else { return }

        var newlyAdded: [String] = []
        mutateAppOverrides { overrides in
            var maxOrder = -1
            for case let entry as NSDictionary in overrides.allValues {
                if let n = (entry["meta"] as? NSDictionary)?["orderKey"] as? NSNumber { maxOrder = max(maxOrder, n.intValue) }
            }
            for bundleID in toAdd where overrides[bundleID] == nil {
                maxOrder += 1
                overrides[bundleID] = NSMutableDictionary(dictionary: [
                    "meta": NSMutableDictionary(dictionary: ["orderKey": maxOrder]),
                    "Root": NSMutableDictionary(),
                ])
                newlyAdded.append(bundleID)
            }
        }

        /// Select & reveal what was added (or what was already there)
        let target = Set(newlyAdded.isEmpty ? toAdd : newlyAdded)
        let indexes = IndexSet(rows.enumerated().compactMap { target.contains($0.element.bundleID) ? $0.offset : nil })
        tableView.selectRowIndexes(indexes, byExtendingSelection: false)
        if let last = indexes.last { tableView.scrollRowToVisible(last) }
        view.window?.makeFirstResponder(tableView)
        updateControls()
    }

    private func removeSelectedApps() {
        let ids = tableView.selectedRowIndexes.compactMap { $0 < rows.count ? rows[$0].bundleID : nil }
        guard !ids.isEmpty else { return }
        let firstIndex = tableView.selectedRowIndexes.first ?? 0
        mutateAppOverrides { overrides in
            overrides.removeObjects(forKeys: ids)
        }
        /// Keep a sensible selection for repeated deletion
        if !rows.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: min(firstIndex, rows.count - 1)), byExtendingSelection: false)
        }
        updateControls()
    }

    // MARK: Actions

    @objc private func addRemoveClicked(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 { showAddPanel() }
        else                           { removeSelectedApps() }
    }

    private func showAddPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = MFLocalizedString("app-specific.add-panel.prompt", comment: "Confirm button of the file picker that opens when clicking + in the 'App-specific' tab.")
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        if #available(macOS 11.0, *) { panel.allowedContentTypes = [.applicationBundle] }
        else                         { panel.allowedFileTypes = ["com.apple.application-bundle"] }

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let self = self else { return }
            self.addApps(bundleIDs: panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier })
        }
        if let window = view.window { panel.beginSheetModal(for: window, completionHandler: completion) }
        else                        { panel.begin(completionHandler: completion) }
    }

    @objc private func checkboxToggled(_ sender: NSButton) {

        let row = tableView.row(for: sender)
        guard row >= 0, row < rows.count,
              let featureID = sender.identifier?.rawValue,
              let feature = AppSpecificFeature(rawValue: featureID) else { return }

        /// If the clicked row is part of a multi-selection, apply to all selected rows (like Finder/Mail checkboxes)
        var targets = [rows[row].bundleID]
        if tableView.selectedRowIndexes.contains(row) && tableView.selectedRowIndexes.count > 1 {
            targets = tableView.selectedRowIndexes.compactMap { $0 < rows.count ? rows[$0].bundleID : nil }
        }
        setFeature(feature, state: sender.state, bundleIDs: targets)
    }

    // MARK: NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return rows.count
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        let ids = Self.bundleIDs(from: info)
        guard !ids.isEmpty else { return [] }
        tableView.setDropRow(-1, dropOperation: .on) /// Highlight the whole table
        return .copy
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let ids = Self.bundleIDs(from: info)
        guard !ids.isEmpty else { return false }
        addApps(bundleIDs: ids)
        return true
    }

    private static func bundleIDs(from info: NSDraggingInfo) -> [String] {
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.filter { $0.pathExtension == "app" }.compactMap { Bundle(url: $0)?.bundleIdentifier }
    }

    // MARK: NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        guard let column = tableColumn, row < rows.count else { return nil }
        let item = rows[row]

        if column.identifier == Self.appColumnID {

            let cellID = NSUserInterfaceItemIdentifier("AppSpecificAppCell")
            let cell = (tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView) ?? makeAppCell(identifier: cellID)
            cell.imageView?.image = item.icon
            cell.imageView?.alphaValue = item.isInstalled ? 1.0 : 0.5
            cell.textField?.stringValue = item.name
            cell.textField?.textColor = item.isInstalled ? .labelColor : .secondaryLabelColor
            cell.toolTip = item.isInstalled ? item.bundleID : String(format: MFLocalizedString("app-specific.not-installed-tooltip", comment: "Tooltip on an app in the 'App-specific' tab which isn't installed on this Mac anymore. %@ is the app's bundle identifier."), item.bundleID)
            return cell

        } else if let feature = AppSpecificFeature(rawValue: column.identifier.rawValue) {

            let cellID = NSUserInterfaceItemIdentifier("AppSpecificCheckboxCell")
            let cell = (tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView) ?? makeCheckboxCell(identifier: cellID)
            guard let checkbox = cell.subviews.first as? NSButton else { return cell }
            let toggleable = feature.isToggleable()
            checkbox.identifier = NSUserInterfaceItemIdentifier(feature.rawValue)
            checkbox.allowsMixedState = feature.isThreeState /// Cells are reused across columns, so always set this. Click order with mixed state: off -> mixed -> on -> off
            checkbox.state = checkboxState(feature, bundleID: item.bundleID)
            checkbox.isEnabled = toggleable
            checkbox.toolTip = !toggleable ? Self.globallyOffTooltip() : (feature.isThreeState ? Self.smoothStatesTooltip() : nil)
            checkbox.setAccessibilityLabel("\(feature.title) – \(item.name)")
            return cell
        }
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateControls()
    }

    // MARK: Cell factories

    private func makeAppCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let textField = NSTextField(labelWithString: "")
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        cell.addSubview(imageView)
        cell.addSubview(textField)
        cell.imageView = imageView
        cell.textField = textField

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22),
            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    private func makeCheckboxCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxToggled(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(checkbox)
        NSLayoutConstraint.activate([
            checkbox.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            checkbox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
