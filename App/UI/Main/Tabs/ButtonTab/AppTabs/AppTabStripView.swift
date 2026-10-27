//
// --------------------------------------------------------------------------
// AppTabStripView.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import AppKit

/// The vertical strip on the left of the Buttons tab.
///     The global tab is on top, then one tab per app, then a "+" button right below them.
final class AppTabStripView: NSView {

    static let width: CGFloat = 60

    /// Called with the bundle ID of the tapped app tab. nil is the global tab.
    var onSelectScope: ((String?) -> Void)?
    /// Called with the "+" button, so the app picker can point at it
    var onAddButtonClicked: ((NSButton) -> Void)?
    /// Called with the bundle ID of an app tab that the user wants to remove
    var onRemoveAppTab: ((String) -> Void)?

    private let scrollView = NSScrollView()
    private let tabStack = NSStackView()
    private let addButton = NSButton()
    private var tabButtons: [AppTabButton] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {

        translatesAutoresizingMaskIntoConstraints = false

        /// Tabs (scrollable, in case there are many apps)

        tabStack.translatesAutoresizingMaskIntoConstraints = false
        tabStack.orientation = .vertical
        tabStack.alignment = .centerX
        tabStack.spacing = 6

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.contentView = FlippedClipView() /// A flipped clip view keeps a short document at the top
        scrollView.documentView = tabStack

        /// Add button
        ///     It sits right below the app tabs. If there are too many tabs to fit, the tabs scroll and the button stays at the bottom. (See the constraints below.)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.isBordered = false
        addButton.imagePosition = .imageOnly
        addButton.toolTip = MFLocalizedString("app-tabs.add.tooltip", comment: "")
        addButton.image = SFSymbolStrings.image(withSymbolName: "plus",accessibilityDescription: MFLocalizedString("app-tabs.add.tooltip", comment: ""))
        if addButton.image == nil { addButton.title = "+" }
        addButton.target = self
        addButton.action = #selector(addButtonTapped(_:))

        addSubview(scrollView)
        addSubview(addButton)

        let clip = scrollView.contentView
        /// The scroll view is as tall as its tabs, so the button can sit right below them.
        ///     When the tabs don't fit, the required constraints win over this preference. The scroll view then gets all the room above the button, and the button sits at the bottom.
        let scrollViewFitsTabs = scrollView.heightAnchor.constraint(equalTo: tabStack.heightAnchor)
        scrollViewFitsTabs.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollViewFitsTabs,

            tabStack.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            tabStack.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            tabStack.topAnchor.constraint(equalTo: clip.topAnchor),

            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            addButton.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            addButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 44),
            addButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    /// Rebuilds the tabs. `appBundleIDs` are the app tabs, in order. The global tab is always first.
    func setTabs(appBundleIDs: [String], selectedScope: String?) {

        for view in tabStack.arrangedSubviews {
            tabStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        tabButtons = []

        let globalIcon = SFSymbolStrings.image(withSymbolName: "globe",accessibilityDescription: MFLocalizedString("app-tabs.global.tooltip", comment: "")) ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
        let globalButton = AppTabButton(bundleID: nil, image: globalIcon, toolTip: MFLocalizedString("app-tabs.global.tooltip", comment: ""))
        globalButton.target = self
        globalButton.action = #selector(tabTapped(_:))
        tabButtons.append(globalButton)

        for bundleID in appBundleIDs {
            let name = AppTabs.name(for: bundleID)
            let button = AppTabButton(bundleID: bundleID, image: AppTabs.icon(for: bundleID), toolTip: name)
            button.target = self
            button.action = #selector(tabTapped(_:))
            button.contextMenuForTab = removeMenu(for: bundleID)
            tabButtons.append(button)
        }

        for button in tabButtons {
            tabStack.addArrangedSubview(button)
        }

        setSelectedScope(selectedScope)
    }

    /// Highlights the tab of `app`. nil highlights the global tab.
    func setSelectedScope(_ app: String?) {
        for button in tabButtons {
            button.isSelectedTab = (button.bundleID == app)
        }
    }

    private func removeMenu(for bundleID: String) -> NSMenu {
        let menu = NSMenu()
        let item = NSMenuItem(title: MFLocalizedString("app-tabs.menu.remove", comment: ""), action: #selector(removeTapped(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = bundleID
        menu.addItem(item)
        return menu
    }

    @objc private func tabTapped(_ sender: AppTabButton) {
        onSelectScope?(sender.bundleID)
    }

    @objc private func addButtonTapped(_ sender: NSButton) {
        onAddButtonClicked?(sender)
    }

    @objc private func removeTapped(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        onRemoveAppTab?(bundleID)
    }
}

/// One tab in the strip. Shows an app icon, or a globe for the global tab.
final class AppTabButton: NSButton {

    /// nil for the global tab
    let bundleID: String?
    /// Shown on right click
    var contextMenuForTab: NSMenu?

    var isSelectedTab: Bool = false {
        didSet { updateAppearance() }
    }

    init(bundleID: String?, image: NSImage, toolTip: String) {
        self.bundleID = bundleID
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyUpOrDown
        self.image = image
        self.toolTip = toolTip

        wantsLayer = true
        layer?.cornerRadius = 10
        widthAnchor.constraint(equalToConstant: 46).isActive = true
        heightAnchor.constraint(equalToConstant: 46).isActive = true

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        self.bundleID = nil
        super.init(coder: coder)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return contextMenuForTab
    }

    private func updateAppearance() {
        let color = isSelectedTab ? NSColor.controlAccentColor.withAlphaComponent(0.25) : NSColor.clear
        layer?.backgroundColor = color.cgColor
    }
}

/// Clip view that lays out its document from the top
private final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}
