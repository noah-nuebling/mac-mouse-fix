//
// --------------------------------------------------------------------------
// AppTabPicker.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import AppKit

/// Popover content for the "+" button of the app tab strip.
///     Lists the apps that are open now, filterable by name. Apps that aren't open can be chosen with "Choose Other App…".
final class AppTabPickerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {

    /// Called with the bundle ID of the app the user picked
    var onPickApp: ((String) -> Void)?
    /// Called when the user wants an app that isn't in the list
    var onChooseOtherApp: (() -> Void)?

    private struct Entry {
        let bundleID: String
        let name: String
    }

    private var allEntries: [Entry] = []
    private var shownEntries: [Entry] = []

    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let chooseOtherButton = NSButton()

    override func loadView() {

        let size = NSSize(width: 260, height: 320)
        let root = NSView(frame: NSRect(origin: .zero, size: size))

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = MFLocalizedString("app-tabs.picker.search", comment: "")
        searchField.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked(_:))
        tableView.allowsEmptySelection = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder

        chooseOtherButton.translatesAutoresizingMaskIntoConstraints = false
        chooseOtherButton.title = MFLocalizedString("app-tabs.picker.choose-other", comment: "")
        chooseOtherButton.bezelStyle = .rounded
        chooseOtherButton.target = self
        chooseOtherButton.action = #selector(chooseOtherTapped(_:))

        root.addSubview(searchField)
        root.addSubview(scrollView)
        root.addSubview(chooseOtherButton)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: chooseOtherButton.topAnchor, constant: -10),

            chooseOtherButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            chooseOtherButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            chooseOtherButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
        ])

        self.view = root
        self.preferredContentSize = size
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        allEntries = AppTabPickerViewController.runningAppEntries()
        searchField.stringValue = ""
        applyFilter()
    }

    /// Apps that are open, shown as regular apps (with a Dock icon), without MMF itself
    private static func runningAppEntries() -> [Entry] {
        var seen = Set<String>()
        var entries: [Entry] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier,
                  bundleID != Bundle.main.bundleIdentifier,
                  !seen.contains(bundleID) else { continue }
            seen.insert(bundleID)
            entries.append(Entry(bundleID: bundleID, name: app.localizedName ?? AppTabs.name(for: bundleID)))
        }
        return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            shownEntries = allEntries
        } else {
            shownEntries = allEntries.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        tableView.reloadData()
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    @objc private func rowClicked(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0, row < shownEntries.count else { return }
        onPickApp?(shownEntries[row].bundleID)
    }

    @objc private func chooseOtherTapped(_ sender: Any?) {
        onChooseOtherApp?()
    }

    // MARK: NSTableViewDataSource & NSTableViewDelegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        return shownEntries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let entry = shownEntries[row]

        let cell = NSTableCellView()

        let imageView = NSImageView(image: AppTabs.icon(for: entry.bundleID))
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: entry.name)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail

        cell.addSubview(imageView)
        cell.addSubview(label)
        cell.imageView = imageView
        cell.textField = label

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}
