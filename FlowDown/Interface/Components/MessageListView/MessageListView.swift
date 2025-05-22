//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import AlertController
import ChidoriMenu
import Combine
import ListViewKit
import Litext
import MarkdownNode
import MarkdownParser
import MarkdownView
import SnapKit
import Storage
import UIKit

final class MessageListView: UIView {
    private lazy var listView: MessageListViewCore = .init()
    var contentSize: CGSize { listView.contentSize }

    private(set) lazy var markdownDrawingViewProvider: DrawingViewProvider = .init()
    lazy var dataSource: ListViewDiffableDataSource<Entry> = .init(listView: listView)

    private var entryCount = 0

    var session: ConversationSession! {
        didSet {
            isFirstLoad = true
            sessionScopedCancellables.forEach { $0.cancel() }
            sessionScopedCancellables.removeAll()
            session.messagesDidChange.ensureMainThread().sink { [unowned self] messages, scrolling in
                updateFromUpstreamPublisher(messages, scrolling)
            }
            .store(in: &sessionScopedCancellables)
            session.userDidSendMessage.sink { [unowned self] _ in
                isAutoScrollingToBottom = true
            }
            .store(in: &sessionScopedCancellables)
        }
    }

    /// A Boolean value that indicates whether the list should automatically scroll to the bottom
    /// when the messages change.
    ///
    /// When `true`, the list will scroll to the bottom to make the latest message visible.
    private var isAutoScrollingToBottom: Bool = true

    /// A Boolean value that indicates whether the last row in the list is in the suppressed rect.
    private var isLastRowInSuppressedRect: Bool = false
    /// A Boolean value that indicates whether the list is suppressed from being updated.
    ///
    /// If this property is `true`, newly appended data at the end of the list will temporarily not be applied to the list.
    private var isUpdatingSuppressed: Bool = false

    private var isLoading: Bool = false
    private var isFirstLoad: Bool = true

    private var viewCancellables: Set<AnyCancellable> = .init()
    private var sessionScopedCancellables: Set<AnyCancellable> = .init()

    var contentSafeAreaInsets: UIEdgeInsets = .zero {
        didSet {
            setNeedsLayout()
        }
    }

    static let listRowInsets: UIEdgeInsets = .init(top: 0, left: 20, bottom: 16, right: 20)
    var theme: MarkdownTheme = .default {
        didSet {
            listView.reloadData()
        }
    }

    private(set) lazy var labelForSizeCalculation: LTXLabel = .init()
    private(set) lazy var markdownViewForSizeCalculation: MarkdownTextView = .init(viewProvider: markdownDrawingViewProvider)
    private(set) lazy var markdownNodesCache: MarkdownNodesCache = .init()

    init() {
        super.init(frame: .zero)

        listView.delegate = self
        listView.adapter = self
        listView.alwaysBounceVertical = true
        listView.alwaysBounceHorizontal = false
        listView.contentInsetAdjustmentBehavior = .never
        listView.showsVerticalScrollIndicator = false
        listView.showsHorizontalScrollIndicator = false
        listView.layoutSubviewsCallback = { [unowned self] in
            if isFirstLoad {
                let snapshot = dataSource.snapshot()
                if snapshot.isEmpty {
                    // No messages are retrieved from the database, it means the list is empty,
                    // and no further action is required.
                    isFirstLoad = false
                    return
                }
                if listView.contentSize.height > 0 {
                    // Scrolls to the bottom when the list view is first loaded.
                    listView.scroll(to: listView.maximumContentOffset)
                    listView.setNeedsLayout()
                    isFirstLoad = false
                }
            }
        }
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        listView.gestureRecognizers?.forEach {
            guard $0 is UIPanGestureRecognizer else { return }
            $0.cancelsTouchesInView = false
        }

        MarkdownTheme.fontScaleDidChange
            .ensureMainThread()
            .sink { [weak self] _ in
                guard let self else { return }
                theme = MarkdownTheme.default
                listView.reloadData()
                updateList(animated: false)
            }
            .store(in: &viewCancellables)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        listView.contentInset = contentSafeAreaInsets
    }

    private func updateAutoScrolling() {
        if listView.contentOffset.y == listView.maximumContentOffset.y {
            isAutoScrollingToBottom = true
        }
    }

    func loading(with message: String = .init()) {
        var snapshot = dataSource.snapshot()
        let lastIndex = snapshot.count - 1
        let item = snapshot.item(at: lastIndex)
        let reportingEntry: Entry = .activityReporting(message)
        if case .activityReporting = item {
            // Update the existing activity reporting text.
            snapshot.updateItem(reportingEntry, at: lastIndex)
        } else {
            // Add a new activity reporting item.
            snapshot.append(reportingEntry)
        }
        isLoading = true
        dataSource.applySnapshot(snapshot)
        if isAutoScrollingToBottom {
            listView.scroll(to: listView.maximumContentOffset, animated: true)
        }
    }

    func stopLoading() {
        if !isLoading {
            return
        }

        var snapshot = dataSource.snapshot()
        let lastIndex = snapshot.count - 1
        let item = snapshot.item(at: lastIndex)
        if case .activityReporting = item {
            snapshot.remove(at: lastIndex)
            dataSource.applySnapshot(snapshot)
        }
        isLoading = false
    }

    func handleLinkTapped(_ link: MarkdownTextView.LinkPayload, in _: NSRange, at point: CGPoint) {
        // long press handled
        guard parentViewController?.presentedViewController == nil else { return }
        switch link {
        case let .url(url):
            processLinkTapped(link: url, rawValue: url.absoluteString, location: point)
        case let .string(string):
            let charset: CharacterSet = [
                .init(charactersIn: #""'“”"#),
                .whitespacesAndNewlines,
            ].reduce(into: .init()) { $0.formUnion($1) }
            var candidate = string.trimmingCharacters(in: charset)
            if var comp = URLComponents(string: candidate) {
                comp.path = comp.path.urlEncoded
                if let url = comp.url {
                    candidate = url.absoluteString
                }
            }
            processLinkTapped(link: .init(string: candidate), rawValue: string, location: point)
        }
    }

    private func processLinkTapped(link: URL?, rawValue: String, location: CGPoint) {
        guard let link,
              let host = link.host,
              let scheme = link.scheme,
              ["http", "https"].contains(scheme)
        else {
            let alert = AlertViewController(
                title: String(localized: "Unable to open link."),
                message: String(localized: "We are unable to process the link you tapped, either it is invalid or not supported.")
            ) { context in
                context.addAction(title: String(localized: "Dismiss")) {
                    context.dispose()
                }
                context.addAction(title: String(localized: "Copy Content"), attribute: .dangerous) {
                    UIPasteboard.general.string = rawValue
                    context.dispose()
                }
            }
            parentViewController?.present(alert, animated: true)
            return
        }
        let menu = UIMenu(children: [
            UIMenu(title: String(localized: "From \(host)"), options: [.displayInline], children: [
                UIAction(title: String(localized: "View"), image: UIImage(systemName: "eye")) { [weak self] _ in
                    guard let self else { return }
                    Indicator.present(link, referencedView: self)
                },
            ]),
            UIMenu(options: [.displayInline], children: [
                UIAction(title: String(localized: "Share"), image: UIImage(systemName: "safari")) { [weak self] _ in
                    let shareSheet = UIActivityViewController(activityItems: [link], applicationActivities: nil)
                    shareSheet.popoverPresentationController?.sourceView = self
                    shareSheet.popoverPresentationController?.sourceRect = .init(
                        origin: .init(x: location.x, y: location.y - 4),
                        size: .init(width: 8, height: 8)
                    )
                    self?.parentViewController?.present(shareSheet, animated: true)
                },
                UIAction(title: String(localized: "Open in Safari"), image: UIImage(systemName: "safari")) { [weak self] _ in
                    guard let self else { return }
                    Indicator.open(link, referencedView: self)
                },
            ]),
        ])
        present(menu: menu, anchorPoint: .init(x: location.x, y: location.y + 4))
    }

    func updateList(animated: Bool = true) {
        let entries = entries(from: session.messages)
        dataSource.applySnapshot(using: entries, animatingDifferences: animated)
    }

    func updateFromUpstreamPublisher(_ messages: [Message], _ scrolling: Bool) {
        let entries = entries(from: messages)
        let someEntiresBeingRemoved = entryCount > entries.count
        let shouldScrolling = scrolling && isAutoScrollingToBottom

        entryCount = entries.count

        #if DEBUG
            assert(!isLoading || entries.count > dataSource.numberOfItems(in: listView), "You should not add new rows when loading")
        #endif

        if !shouldScrolling {
            // When the list needs to scroll, the list updating cannot be suppressed.
            let shouldSuppressed = shouldUpdatingSuppressed(with: entries)
            isUpdatingSuppressed = shouldSuppressed && isLastRowInSuppressedRect

            // but if entry is becoming less, we should update it
            if isUpdatingSuppressed, !someEntiresBeingRemoved { return }
        } else {
            isUpdatingSuppressed = false
        }

        dataSource.applySnapshot(using: entries, animatingDifferences: someEntiresBeingRemoved ? true : false)
        if shouldScrolling { listView.scroll(to: listView.maximumContentOffset, animated: true) }
    }
}

extension MessageListView: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_: UIScrollView) {
        isAutoScrollingToBottom = false
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        updateAutoScrolling()
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateAutoScrolling()
        }
    }

    func scrollViewDidScroll(_: UIScrollView) {
        let numberOfItems = dataSource.numberOfItems(in: listView)
        let lastIndex = numberOfItems - 1
        if lastIndex < 0 {
            return
        }
        guard let rowView = listView.rowView(at: lastIndex) else {
            return
        }
        isLastRowInSuppressedRect = rowViewInSuppressedRect(rowView)
        if isUpdatingSuppressed, !isLastRowInSuppressedRect {
            // When the tail row re-enters the visible updating area, update the list.
            updateList(animated: false)
            isUpdatingSuppressed = false
        }
    }

    private func shouldUpdatingSuppressed(with entries: [Entry]) -> Bool {
        let numberOfItems = dataSource.numberOfItems(in: listView)
        if numberOfItems != entries.count {
            return false
        }
        let lastIndex = numberOfItems - 1
        if lastIndex < 0 {
            return false
        }
        guard let lastItem = dataSource.item(at: lastIndex, in: listView) as? Entry else {
            assertionFailure()
            return false
        }
        return entries[lastIndex] != lastItem
    }

    private func rowViewInSuppressedRect(_ rowView: ListRowView) -> Bool {
        let rect = rowView.convert(rowView.bounds, to: listView)
        // If the tail of the last row exceeds the visible area by a certain distance,
        // the list update can be paused.
        let overflow = rect.maxY - listView.bounds.maxY
        return overflow >= 50
    }
}

extension MessageListView {
    final class MessageListViewCore: ListViewKit.ListView {
        var layoutSubviewsCallback: (() -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            layoutSubviewsCallback?()
        }
    }
}
