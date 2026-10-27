//
// --------------------------------------------------------------------------
// AppsTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// The 'Apps' tab. Lets the user turn off individual Mac Mouse Fix features in specific apps. (E.g. smooth scrolling in games, which want the scroll events macOS normally sends.)
///     The list of apps is stored in the config under `AppExclusions`. The Helper applies it in `AppExclusions.m`.
///     The UI is built in code instead of in Main.storyboard to keep it self-contained. The tab is added in `TabViewController.viewDidLoad()`.

import Cocoa
import UniformTypeIdentifiers

class AppsTabController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    /// Model

    struct Entry {
        var identifier: String  /// bundleID – or path of the executable for apps without a bundleID. Keep in sync with `AppExclusions.m`
        var name: String
        var path: String        /// Only used for displaying the icon
        var disabledFeatures: Set<Feature>
    }

    enum Feature: String, CaseIterable {
        /// rawValue is the config key. Keep in sync with `AppExclusions.m`
        case smoothScrolling    = "disableSmoothScrolling"
        case reverseDirection   = "disableReverseDirection"
        case scrollModifiers    = "disableScrollModifiers"
        case buttons            = "disableButtons"

        var title: String {
            switch self {
                case .smoothScrolling:  return MFLocalizedString("apps-tab.feature.smooth-scrolling", comment: "Apps Tab > Checkbox. Turns off smooth scrolling and Mac Mouse Fix's scroll speed in the selected app")
                case .reverseDirection: return MFLocalizedString("apps-tab.feature.reverse-direction", comment: "Apps Tab > Checkbox. Turns off the 'Reverse Direction' setting from the Scrolling tab in the selected app")
                case .scrollModifiers:  return MFLocalizedString("apps-tab.feature.scroll-modifiers", comment: "Apps Tab > Checkbox. Turns off the 'Keyboard Modifiers' scroll actions from the Scrolling tab (zoom, horizontal scroll, etc.) in the selected app")
                case .buttons:          return MFLocalizedString("apps-tab.feature.buttons", comment: "Apps Tab > Checkbox. Turns off everything Mac Mouse Fix does with mouse buttons in the selected app")
            }
        }
        var hint: String {
            switch self {
                case .smoothScrolling:  return MFLocalizedString("apps-tab.feature.smooth-scrolling.hint", comment: "Apps Tab > Hint under the Smooth Scrolling checkbox")
                case .reverseDirection: return MFLocalizedString("apps-tab.feature.reverse-direction.hint", comment: "Apps Tab > Hint under the Reverse Direction checkbox")
                case .scrollModifiers:  return MFLocalizedString("apps-tab.feature.scroll-modifiers.hint", comment: "Apps Tab > Hint under the Keyboard Modifiers checkbox")
                case .buttons:          return MFLocalizedString("apps-tab.feature.buttons.hint", comment: "Apps Tab > Hint under the Buttons checkbox")
            }
        }
    }

    private static let defaultDisabledFeatures: Set<Feature> = [.smoothScrolling] /// For newly added apps
    private static let configKey = "AppExclusions"
    private var entries: [Entry] = []

    /// Views

    private let tableView = NSTableView()
    private let addButton = NSButton()
    private let removeButton = NSButton()
    private let emptyLabel = NSTextField(wrappingLabelWithString: MFLocalizedString("apps-tab.empty", comment: "Apps Tab > Shown in the empty app list"))
    private let detailStack = NSStackView()
    private let detailTitle = NSTextField(labelWithString: "")
    private var featureCheckboxes: [Feature: NSButton] = [:]
    private let noSelectionLabel = NSTextField(wrappingLabelWithString: MFLocalizedString("apps-tab.no-selection", comment: "Apps Tab > Shown on the right when no app is selected"))

    /// Layout constants

    private let listWidth: CGFloat = 210
    private let listHeight: CGFloat = 270
    private let detailWidth: CGFloat = 250
    private let columnSpacing: CGFloat = 20

    // MARK: Lifecycle

    override func loadView() {

        /// Note: TabViewController expects the tab's view to have a single wrapper subview which holds all the content. (See `adjustConstraintsForWindowResizing()` and the fade animations)
        let view = NSView()
        let wrapper = NSView()

        /// Hint
        let hint = NSTextField(wrappingLabelWithString: MFLocalizedString("apps-tab.hint", comment: "Apps Tab > Explanation at the top of the tab"))
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = listWidth + columnSpacing + detailWidth

        /// Table
        let column = NSTableColumn(identifier: .init("app"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        if #available(macOS 11.0, *) { tableView.style = .fullWidth }
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.rowHeight = 34
        tableView.dataSource = self
        tableView.delegate = self

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.preferredMaxLayoutWidth = listWidth - 30

        /// Buttons
        addButton.image = NSImage(named: NSImage.addTemplateName)
        addButton.bezelStyle = .smallSquare
        addButton.target = self
        addButton.action = #selector(showAddMenu(_:))
        addButton.setAccessibilityIdentifier("axAppsTabAddButton")

        removeButton.image = NSImage(named: NSImage.removeTemplateName)
        removeButton.bezelStyle = .smallSquare
        removeButton.target = self
        removeButton.action = #selector(removeSelected(_:))

        /// Detail
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 4

        detailTitle.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        detailTitle.lineBreakMode = .byTruncatingMiddle
        detailTitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailStack.addArrangedSubview(detailTitle)
        detailStack.setCustomSpacing(10, after: detailTitle)

        for feature in Feature.allCases {

            let checkbox = NSButton(checkboxWithTitle: feature.title, target: self, action: #selector(toggleFeature(_:)))
            checkbox.identifier = .init(feature.rawValue)
            featureCheckboxes[feature] = checkbox

            let featureHint = NSTextField(wrappingLabelWithString: feature.hint)
            featureHint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            featureHint.textColor = .secondaryLabelColor
            let hintIndent: CGFloat = 20 /// Align with the checkbox title
            featureHint.preferredMaxLayoutWidth = detailWidth - hintIndent
            let hintContainer = NSView()
            featureHint.translatesAutoresizingMaskIntoConstraints = false
            hintContainer.addSubview(featureHint)
            NSLayoutConstraint.activate([
                featureHint.topAnchor.constraint(equalTo: hintContainer.topAnchor),
                featureHint.bottomAnchor.constraint(equalTo: hintContainer.bottomAnchor),
                featureHint.leadingAnchor.constraint(equalTo: hintContainer.leadingAnchor, constant: hintIndent),
                featureHint.trailingAnchor.constraint(equalTo: hintContainer.trailingAnchor),
            ])

            detailStack.addArrangedSubview(checkbox)
            detailStack.addArrangedSubview(hintContainer)
            detailStack.setCustomSpacing(2, after: checkbox)
            detailStack.setCustomSpacing(12, after: hintContainer)
            hintContainer.widthAnchor.constraint(equalTo: detailStack.widthAnchor).isActive = true
        }

        noSelectionLabel.textColor = .tertiaryLabelColor
        noSelectionLabel.alignment = .center
        noSelectionLabel.preferredMaxLayoutWidth = detailWidth - 20

        /// Layout
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wrapper)
        for v in [hint, scrollView, emptyLabel, addButton, removeButton, detailStack, noSelectionLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(v)
        }
        NSLayoutConstraint.activate([

            wrapper.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            wrapper.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            wrapper.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            wrapper.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            hint.topAnchor.constraint(equalTo: wrapper.topAnchor),
            hint.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            scrollView.widthAnchor.constraint(equalToConstant: listWidth),
            scrollView.heightAnchor.constraint(equalToConstant: listHeight),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),

            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -1), /// Overlap the borders, like in System Settings
            addButton.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 24),
            addButton.heightAnchor.constraint(equalToConstant: 22),
            addButton.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),

            removeButton.topAnchor.constraint(equalTo: addButton.topAnchor),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: -1),
            removeButton.widthAnchor.constraint(equalTo: addButton.widthAnchor),
            removeButton.heightAnchor.constraint(equalTo: addButton.heightAnchor),

            detailStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 2),
            detailStack.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: columnSpacing),
            detailStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            detailStack.widthAnchor.constraint(equalToConstant: detailWidth),
            detailStack.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.bottomAnchor),

            noSelectionLabel.centerXAnchor.constraint(equalTo: detailStack.centerXAnchor),
            noSelectionLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])

        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        entries = Self.loadEntries()
        tableView.reloadData()
        if !entries.isEmpty {
            tableView.selectRowIndexes([0], byExtendingSelection: false)
        }
        updateControls()
    }

    // MARK: Actions

    @objc private func showAddMenu(_ sender: NSButton) {

        let menu = NSMenu()

        let chooseItem = NSMenuItem(title: MFLocalizedString("apps-tab.add.choose", comment: "Apps Tab > + Menu > Opens a file picker"), action: #selector(chooseApp(_:)), keyEquivalent: "")
        chooseItem.target = self
        menu.addItem(chooseItem)

        /// Offer the running apps – that's the easiest way to add games which aren't proper app bundles (e.g. Minecraft)
        let existing = Set(entries.map { $0.identifier })
        var seen = Set<String>()
        let runningEntries = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0 != NSRunningApplication.current }
            .compactMap { Self.entry(for: $0) }
            .filter { !existing.contains($0.identifier) && seen.insert($0.identifier).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        if !runningEntries.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(title: MFLocalizedString("apps-tab.add.running-header", comment: "Apps Tab > + Menu > Header above the list of currently running apps"), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for e in runningEntries {
                let item = NSMenuItem(title: e.name, action: #selector(addRunningApp(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = e
                let icon = Self.icon(for: e)
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
                menu.addItem(item)
            }
        }

        _ = menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func addRunningApp(_ sender: NSMenuItem) {
        guard let e = sender.representedObject as? Entry else { assert(false); return }
        add([e])
    }

    @objc private func chooseApp(_ sender: Any?) {

        guard let window = view.window else { assert(false); return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.application, .unixExecutable]
        } else {
            panel.allowedFileTypes = ["app", "public.unix-executable"]
        }

        panel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            self.add(panel.urls.compactMap { Self.entry(forFileAt: $0) })
        }
    }

    @objc private func removeSelected(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0, row < entries.count else { return }
        entries.remove(at: row)
        saveEntries()
        tableView.reloadData()
        if !entries.isEmpty {
            tableView.selectRowIndexes([min(row, entries.count - 1)], byExtendingSelection: false)
        }
        updateControls()
    }

    @objc private func toggleFeature(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0, row < entries.count,
              let feature = Feature(rawValue: sender.identifier?.rawValue ?? "")
        else { assert(false); return }
        if sender.state == .on {
            entries[row].disabledFeatures.insert(feature)
        } else {
            entries[row].disabledFeatures.remove(feature)
        }
        saveEntries()
        tableView.reloadData(forRowIndexes: [row], columnIndexes: [0]) /// Update the summary
    }

    // MARK: Helpers

    private func add(_ newEntries: [Entry]) {

        var rowToSelect: Int? = nil
        for e in newEntries {
            if let i = entries.firstIndex(where: { $0.identifier == e.identifier }) {
                rowToSelect = i /// Already in the list – just select it
            } else {
                entries.append(e)
                rowToSelect = entries.count - 1
            }
        }
        saveEntries()
        tableView.reloadData()
        if let row = rowToSelect {
            tableView.selectRowIndexes([row], byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
        }
        updateControls()
    }

    private func updateControls() {

        emptyLabel.isHidden = !entries.isEmpty

        let row = tableView.selectedRow
        let selected: Entry? = (row >= 0 && row < entries.count) ? entries[row] : nil

        removeButton.isEnabled = selected != nil
        detailStack.isHidden = selected == nil
        noSelectionLabel.isHidden = selected != nil || entries.isEmpty

        if let selected = selected {
            detailTitle.stringValue = String(format: MFLocalizedString("apps-tab.detail-title", comment: "Apps Tab > Title above the checkboxes for the selected app. %@ is the app name. Each checked feature is turned off in that app."), selected.name)
            for (feature, checkbox) in featureCheckboxes {
                checkbox.state = selected.disabledFeatures.contains(feature) ? .on : .off
            }
        }
    }

    private static func summary(for entry: Entry) -> String {
        let titles = Feature.allCases.filter { entry.disabledFeatures.contains($0) }.map { $0.title }
        if titles.isEmpty {
            return MFLocalizedString("apps-tab.summary.nothing", comment: "Apps Tab > App list > Line under the app name when nothing is turned off for that app")
        }
        return String(format: MFLocalizedString("apps-tab.summary", comment: "Apps Tab > App list > Line under each app name. %@ is a comma-separated list of the features that are turned off, e.g. 'Smooth Scrolling, Buttons'"), titles.joined(separator: ", "))
    }

    private static func entry(for app: NSRunningApplication) -> Entry? {
        /// Same identifier logic as `AppExclusions.m`
        guard let identifier = app.bundleIdentifier ?? app.executableURL?.path else { return nil }
        let path = app.bundleURL?.path ?? app.executableURL?.path ?? ""
        let name = app.localizedName ?? (path as NSString).lastPathComponent
        return Entry(identifier: identifier, name: name, path: path, disabledFeatures: defaultDisabledFeatures)
    }

    private static func entry(forFileAt url: URL) -> Entry? {

        let identifier: String
        if url.pathExtension == "app" {
            guard let bundle = Bundle(url: url),
                  let id = bundle.bundleIdentifier ?? bundle.executableURL?.resolvingSymlinksInPath().path
            else { return nil }
            identifier = id
        } else {
            identifier = url.resolvingSymlinksInPath().path /// `NSRunningApplication.executableURL` has symlinks resolved
        }

        let name = FileManager.default.displayName(atPath: url.path)
        return Entry(identifier: identifier, name: name, path: url.path, disabledFeatures: defaultDisabledFeatures)
    }

    private static func icon(for entry: Entry) -> NSImage {
        if !entry.path.isEmpty, FileManager.default.fileExists(atPath: entry.path) {
            return NSWorkspace.shared.icon(forFile: entry.path)
        }
        if #available(macOS 11.0, *) {
            return NSWorkspace.shared.icon(for: .application)
        } else {
            return NSWorkspace.shared.icon(forFileType: "app")
        }
    }

    // MARK: Config

    private static func loadEntries() -> [Entry] {
        guard let array = config(configKey) as? [NSDictionary] else { return [] } /// Optional key – nil if the user never added any apps.
        return array.compactMap { d in
            guard let identifier = d["identifier"] as? String else { return nil }
            let disabledFeatures = Set(Feature.allCases.filter { d[$0.rawValue] as? Bool ?? false })
            return Entry(identifier: identifier,
                         name: d["name"] as? String ?? identifier,
                         path: d["path"] as? String ?? "",
                         disabledFeatures: disabledFeatures)
        }
    }

    private func saveEntries() {
        let array = NSMutableArray()
        for e in entries {
            let d = NSMutableDictionary(dictionary: [
                "identifier": e.identifier,
                "name": e.name,
                "path": e.path,
            ])
            for feature in Feature.allCases {
                d[feature.rawValue] = e.disabledFeatures.contains(feature)
            }
            array.add(d)
        }
        setConfig(Self.configKey, array)
        commitConfig() /// Writes to file and notifies the Helper
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        return entries.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateControls()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        guard let columnID = tableColumn?.identifier, row < entries.count else { return nil }
        let entry = entries[row]

        let cell = tableView.makeView(withIdentifier: columnID, owner: self) as? AppCellView ?? {
            let cell = AppCellView()
            cell.identifier = columnID
            return cell
        }()

        cell.imageView?.image = Self.icon(for: entry)
        cell.textField?.stringValue = entry.name
        cell.summaryField.stringValue = Self.summary(for: entry)
        cell.toolTip = entry.identifier
        return cell
    }
}

private class AppCellView: NSTableCellView {

    /// Row in the app list: Icon, name, and a summary of what's turned off.

    let summaryField = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)

        let imageView = NSImageView()
        let nameField = NSTextField(labelWithString: "")
        nameField.lineBreakMode = .byTruncatingTail
        summaryField.lineBreakMode = .byTruncatingTail
        summaryField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        summaryField.textColor = .secondaryLabelColor

        for v in [imageView, nameField, summaryField] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),
            nameField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            nameField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            nameField.bottomAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            summaryField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
            summaryField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            summaryField.topAnchor.constraint(equalTo: centerYAnchor, constant: 1),
        ])
        self.imageView = imageView
        self.textField = nameField
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
