//
// --------------------------------------------------------------------------
// AppPresetBannerView.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import AppKit

/// The banner in an empty app tab that offers a built-in preset.
final class AppPresetBannerView: NSView {

    /// Called when the user clicks Review
    var onReview: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private let reviewButton = NSButton(title: MFLocalizedString("app-presets.review", comment: ""), target: nil, action: nil)

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
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        /// Two lines, so the summary of the preset isn't cut off in a narrow window
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.maximumNumberOfLines = 2
        label.cell?.wraps = true
        label.lineBreakMode = .byWordWrapping
        label.cell?.truncatesLastVisibleLine = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        reviewButton.translatesAutoresizingMaskIntoConstraints = false
        reviewButton.bezelStyle = .rounded
        reviewButton.target = self
        reviewButton.action = #selector(reviewTapped(_:))

        let stack = NSStackView(views: [label, reviewButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    /// Sets the text of the offer
    func setText(_ text: String) {
        label.stringValue = text
    }

    @objc private func reviewTapped(_ sender: NSButton) {
        onReview?()
    }
}
