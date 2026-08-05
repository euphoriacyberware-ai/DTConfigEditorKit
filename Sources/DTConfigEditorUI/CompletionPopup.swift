import SwiftUI
import DTConfigCore

#if os(macOS)
import AppKit

// MARK: - Completion list (SwiftUI content)

struct CompletionListView: View {
    let items: [CompletionItem]
    let selectedIndex: Int
    let onSelect: (CompletionItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        CompletionRowView(item: item, isSelected: index == selectedIndex)
                            .id(index)
                            .onTapGesture { onSelect(item) }
                    }
                }
            }
            .onChange(of: selectedIndex) { _, newValue in
                withAnimation(.linear(duration: 0.05)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(width: 360, height: min(CGFloat(items.count) * 24, 200))
    }
}

private struct CompletionRowView: View {
    let item: CompletionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(item.displayLabel)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
            Spacer()
            if let typeLabel = item.typeLabel {
                Text(typeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Controller

/// Manages a floating completion panel on macOS.
///
/// The panel is non-activating so the text view keeps keyboard focus.
/// Keyboard navigation (up/down/enter/escape) is handled by the coordinator
/// via ``TextViewCoordinator`` delegate methods.
@MainActor
final class CompletionPopupController {
    private var panel: NSPanel?
    private(set) var items: [CompletionItem] = []
    private(set) var selectedIndex: Int = 0
    private(set) var replacementRange: Range<Int> = 0..<0
    private var onAccept: ((CompletionItem, Range<Int>) -> Void)?
    private var hostingView: NSHostingView<CompletionListView>?

    var isShowing: Bool { panel?.isVisible ?? false }

    func show(
        result: CompletionResult,
        near rect: NSRect,
        in view: NSView,
        onAccept: @escaping (CompletionItem, Range<Int>) -> Void
    ) {
        guard !result.items.isEmpty else {
            dismiss()
            return
        }

        self.items = result.items
        self.selectedIndex = 0
        self.replacementRange = result.replacementRange
        self.onAccept = onAccept

        let content = CompletionListView(
            items: items, selectedIndex: selectedIndex
        ) { [weak self] item in
            guard let self else { return }
            self.dismiss()
            onAccept(item, self.replacementRange)
        }

        if let panel, panel.isVisible {
            // Update content in-place.
            hostingView?.rootView = content
            positionPanel(panel, near: rect, in: view)
            return
        }

        dismiss()

        let hosting = NSHostingView(rootView: content)
        hosting.frame.size = hosting.intrinsicContentSize
        let panelRect = NSRect(origin: .zero, size: hosting.frame.size)

        let p = NSPanel(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.hasShadow = true
        p.level = .popUpMenu
        p.backgroundColor = .windowBackgroundColor
        p.contentView = hosting

        positionPanel(p, near: rect, in: view)
        p.orderFront(nil)
        self.panel = p
        self.hostingView = hosting
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        items = []
    }

    func moveUp() {
        guard !items.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
        refreshContent()
    }

    func moveDown() {
        guard !items.isEmpty else { return }
        selectedIndex = min(items.count - 1, selectedIndex + 1)
        refreshContent()
    }

    func acceptCurrent() {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        let item = items[selectedIndex]
        let range = replacementRange
        dismiss()
        onAccept?(item, range)
    }

    // MARK: - Private

    private func positionPanel(_ panel: NSPanel, near rect: NSRect, in view: NSView) {
        guard let window = view.window else { return }
        let screenRect = window.convertToScreen(view.convert(rect, to: nil))
        let origin = NSPoint(
            x: screenRect.origin.x,
            y: screenRect.origin.y - panel.frame.height - 2
        )
        panel.setFrameOrigin(origin)
    }

    private func refreshContent() {
        let content = CompletionListView(
            items: items, selectedIndex: selectedIndex
        ) { [weak self] item in
            guard let self else { return }
            let range = self.replacementRange
            self.dismiss()
            self.onAccept?(item, range)
        }
        hostingView?.rootView = content
    }
}
#endif
