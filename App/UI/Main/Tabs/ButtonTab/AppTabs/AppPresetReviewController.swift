//
// --------------------------------------------------------------------------
// AppPresetReviewController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import AppKit

/// Sheet that lists the suggested assignments of an app's preset before anything is written.
/// The user can untick a row, change its button, or pick another action for it. Nothing is written until "Add Selected" is clicked.
final class AppPresetReviewController: NSViewController {

    /// Called after the sheet has closed. `rows` are the remap rows to write for the app, empty if the user skipped.
    /// `dontSuggestAgain` is true if the user ticked the checkbox.
    var onFinish: (([[String: Any]], Bool) -> Void)?

    private let app: String
    private let preset: AppPreset
    /// Used to warn about buttons that already have a row for all apps
    private let globalRows: [[String: Any]]

    /// One entry per suggestion, in the same order
    private var checkboxes: [NSButton] = []
    private var buttonPopups: [NSPopUpButton] = []
    private var actionPopups: [NSPopUpButton] = []

    private let warningLabel = NSTextField(wrappingLabelWithString: "")
    private let noteLabel = NSTextField(wrappingLabelWithString: "")
    private let dontSuggestCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let addButton = NSButton(title: "", target: nil, action: nil)

    init(app: String, preset: AppPreset, globalRows: [[String: Any]]) {
        self.app = app
        self.preset = preset
        self.globalRows = globalRows
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("AppPresetReviewController is only created in code")
    }

    override func loadView() {

        let appName = AppTabs.name(for: app)

        let titleLabel = NSTextField(labelWithString: String(format: MFLocalizedString("app-presets.review.title", comment: ""), appName))
        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let introLabel = NSTextField(wrappingLabelWithString: MFLocalizedString("app-presets.review.intro", comment: ""))
        introLabel.textColor = .secondaryLabelColor

        /// Grid with a header row and one row per suggestion
        let grid = NSGridView(numberOfColumns: 3, rows: 0)
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        grid.addRow(with: [NSGridCell.emptyContentView, headerLabel(MFLocalizedString("app-presets.review.column.button", comment: "")), headerLabel(MFLocalizedString("app-presets.review.column.action", comment: ""))])

        for suggestion in preset.suggestions {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(stateChanged(_:)))
            checkbox.state = .on
            let buttonPopup = makeButtonPopup(selected: suggestion.button)
            let actionPopup = makeActionPopup(for: suggestion)
            checkboxes.append(checkbox)
            buttonPopups.append(buttonPopup)
            actionPopups.append(actionPopup)
            grid.addRow(with: [checkbox, buttonPopup, actionPopup])
        }

        /// Notes
        warningLabel.textColor = .systemRed
        noteLabel.textColor = .secondaryLabelColor

        /// Bottom row
        dontSuggestCheckbox.title = String(format: MFLocalizedString("app-presets.review.dont-suggest", comment: ""), appName)

        let skipButton = NSButton(title: MFLocalizedString("app-presets.review.skip", comment: ""), target: self, action: #selector(skipTapped(_:)))
        skipButton.bezelStyle = .rounded
        skipButton.keyEquivalent = "\u{1b}"

        addButton.title = MFLocalizedString("app-presets.review.add", comment: "")
        addButton.bezelStyle = .rounded
        addButton.keyEquivalent = "\r"
        addButton.target = self
        addButton.action = #selector(addTapped(_:))

        let buttonRow = NSStackView(views: [dontSuggestCheckbox, NSView(), skipButton, addButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10

        /// Stack everything
        let root = NSStackView(views: [titleLabel, introLabel, grid, noteLabel, warningLabel, buttonRow])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 16, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false
        root.widthAnchor.constraint(equalToConstant: 580).isActive = true
        buttonRow.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -40).isActive = true
        /// The action popups would otherwise be as wide as their longest library entry and push the grid past the sheet's edges
        grid.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -40).isActive = true
        /// If the sheet is taller than its content, the grid would take the extra height, and it would appear as a gap below the header row
        grid.setContentHuggingPriority(.required, for: .vertical)

        view = root
        preferredContentSize = root.fittingSize

        updateWarnings()
    }

    //
    // MARK: Building the controls
    //

    private func headerLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeButtonPopup(selected button: Int) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        for number in AppPreset.selectableButtons {
            popup.addItem(withTitle: UIStrings.getButtonString(MFMouseButtonNumber(UInt32(number)), context: kMFButtonStringUsageContextActionTableGroupRow))
            popup.lastItem?.tag = number
        }
        popup.selectItem(withTag: button)
        popup.target = self
        popup.action = #selector(stateChanged(_:))
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        return popup
    }

    /// The preset's own action comes first. Then come the other actions the shortcut library knows for this app.
    ///     If the library has the preset's action, its name is used, because the button table shows that name once the row is added.
    private func makeActionPopup(for suggestion: AppPresetSuggestion) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)

        var presetTitle = "\(MFLocalizedString(suggestion.titleKey, comment: ""))  \(suggestion.symbols)"
        var otherEntries: [(title: String, effect: [String: Any])] = []
        for entry in ShortcutLibrary.effectsMenuEntries(forBundleID: app) {
            guard let entry = entry as? [String: Any],
                  let ui = entry["ui"] as? String,
                  let effect = entry["dict"] as? [String: Any] else { continue }
            let title = "\(ui)  \(entry["tool"] as? String ?? "")"
            if (effect as NSDictionary).isEqual(suggestion.effect as NSDictionary) {
                presetTitle = title
                continue
            }
            otherEntries.append((title: title, effect: effect))
        }

        popup.addItem(withTitle: presetTitle)
        popup.lastItem?.representedObject = suggestion.effect
        for entry in otherEntries {
            popup.addItem(withTitle: entry.title)
            popup.lastItem?.representedObject = entry.effect
        }

        popup.target = self
        popup.action = #selector(stateChanged(_:))
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        popup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        (popup.cell as? NSPopUpButtonCell)?.lineBreakMode = .byTruncatingTail
        return popup
    }

    //
    // MARK: State
    //

    /// The checked rows, with the button and effect the user picked for each
    private func checkedSelections() -> [(button: Int, effect: [String: Any])] {
        var result: [(button: Int, effect: [String: Any])] = []
        for index in checkboxes.indices where checkboxes[index].state == .on {
            guard let button = buttonPopups[index].selectedItem?.tag,
                  let effect = actionPopups[index].selectedItem?.representedObject as? [String: Any] else { continue }
            result.append((button: button, effect: effect))
        }
        return result
    }

    /// True if a button already has a row for all apps. Such a row has no modifiers.
    private func isSetForAllApps(_ button: Int) -> Bool {
        return globalRows.contains { row in
            let trigger = row["trigger"] as? [String: Any]
            let modifiers = row["modifiers"] as? [String: Any] ?? [:]
            return (trigger?["button"] as? Int) == button && modifiers.isEmpty
        }
    }

    @objc private func stateChanged(_ sender: Any?) {
        updateWarnings()
    }

    private func updateWarnings() {

        let selections = checkedSelections()
        let buttons = selections.map { $0.button }

        /// Two checked rows on the same button can't both be written
        let duplicates = Set(buttons.filter { button in buttons.filter { $0 == button }.count > 1 })
        warningLabel.stringValue = MFLocalizedString("app-presets.review.duplicate", comment: "")
        warningLabel.isHidden = duplicates.isEmpty

        /// Buttons that also have a row for all apps. The rows here take precedence in this app.
        let overlapping = Array(Set(buttons.filter { isSetForAllApps($0) })).sorted()
        let names = overlapping.map { UIStrings.getButtonString(MFMouseButtonNumber(UInt32($0)), context: kMFButtonStringUsageContextActionTableGroupRow) }
        noteLabel.stringValue = String(format: MFLocalizedString("app-presets.review.global-overlap", comment: ""), names.joined(separator: ", "), AppTabs.name(for: app))
        noteLabel.isHidden = overlapping.isEmpty

        addButton.isEnabled = !selections.isEmpty && duplicates.isEmpty
    }

    //
    // MARK: Actions
    //

    @objc private func addTapped(_ sender: NSButton) {
        let rows = checkedSelections().map { AppPreset.remapRow(button: $0.button, effect: $0.effect, app: app) }
        finish(rows: rows)
    }

    @objc private func skipTapped(_ sender: NSButton) {
        finish(rows: [])
    }

    private func finish(rows: [[String: Any]]) {
        if let window = view.window, let sheetParent = window.sheetParent {
            sheetParent.endSheet(window)
        }
        onFinish?(rows, dontSuggestCheckbox.state == .on)
    }
}
