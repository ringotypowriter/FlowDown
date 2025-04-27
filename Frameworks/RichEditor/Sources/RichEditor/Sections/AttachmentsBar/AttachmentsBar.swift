//
//  AttachmentsBar.swift
//  RichEditor
//
//  Created by 秋星桥 on 2025/1/16.
//

import AlignedCollectionViewFlowLayout
import OrderedCollections
import QuickLook
import UIKit

public class AttachmentsBar: EditorSectionView {
    public let collectionView: UICollectionView
    let collectionViewLayout = AlignedCollectionViewFlowLayout(
        horizontalAlignment: .justified,
        verticalAlignment: .center
    )
    var attachmetns: OrderedDictionary<ItemIdentifier, Item> = [:] {
        didSet { updateDataSource() }
    }

    lazy var dataSoruce: DataSource = .init(collectionView: collectionView) { [weak self] _, indexPath, itemIdentifier in
        self?.cellFor(indexPath: indexPath, itemIdentifier: itemIdentifier) ?? .init()
    }

    public var inset: UIEdgeInsets = .init(top: 10, left: 10, bottom: 0, right: 10)
    public let itemSpacing: CGFloat = 10
    public let itemSize = CGSize(width: 80, height: AttachmentsBar.itemHeight)

    public static let itemHeight: CGFloat = 80

    public weak var delegate: Delegate?
    public var isDeletable: Bool = true {
        didSet { collectionView.reloadData() }
    }

    var previewItemDataSource: Any?

    public required init() {
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.minimumInteritemSpacing = itemSpacing
        collectionViewLayout.minimumLineSpacing = itemSpacing
        collectionView = .init(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.register(
            AttachmentsImageCell.self,
            forCellWithReuseIdentifier: String(describing: AttachmentsImageCell.self)
        )
        collectionView.register(
            AttachmentsTextCell.self,
            forCellWithReuseIdentifier: String(describing: AttachmentsTextCell.self)
        )
        collectionViewLayout.sectionInset = .init(
            top: 0,
            left: inset.left,
            bottom: 0,
            right: inset.right
        )
        super.init()
        collectionView.delegate = self
    }

    deinit {
        previewItemDataSource = nil
    }

    override public func initializeViews() {
        super.initializeViews()
        clipsToBounds = true
        addSubview(collectionView)
        updateDataSource()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = .init(x: 0, y: inset.top, width: bounds.width, height: itemSize.height)
    }

    public func idealSize() -> CGSize {
        let itemWidth = attachmetns.values
            .map {
                itemSize(for: $0.type).width
            }
            .reduce(0, +)
        let spacingWidth = CGFloat(attachmetns.count) * itemSpacing
        return .init(
            width: itemWidth + spacingWidth + inset.left + inset.right,
            height: itemSize.height + inset.top + inset.bottom
        )
    }

    public func item(for id: ItemIdentifier) -> Item? {
        attachmetns[id]
    }

    func cellFor(indexPath: IndexPath, itemIdentifier: ItemIdentifier) -> UICollectionViewCell {
        guard let item = item(for: itemIdentifier) else { return .init() }
        switch item.type {
        case .image:
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: String(describing: AttachmentsImageCell.self),
                    for: indexPath
                ) as! AttachmentsImageCell
            cell.isDeletable = isDeletable
            cell.configure(item: item)
            return cell
        case .text:
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: String(describing: AttachmentsTextCell.self),
                    for: indexPath
                ) as! AttachmentsTextCell
            cell.isDeletable = isDeletable
            cell.configure(item: item)
            return cell
        }
    }

    func updateDataSource() {
        var snapshot = dataSoruce.snapshot()
        if snapshot.sectionIdentifiers.isEmpty {
            snapshot.appendSections([.main])
        }
        let newItems = attachmetns.keys
        for item in snapshot.itemIdentifiers {
            if !newItems.contains(item) {
                snapshot.deleteItems([item])
            }
        }
        for item in newItems {
            if !snapshot.itemIdentifiers.contains(item) {
                snapshot.appendItems([item])
            }
        }
        dataSoruce.apply(snapshot)
        delegate?.attachmentBarDidUpdateAttachments(Array(attachmetns.values))

        if attachmetns.isEmpty {
            withAnimation { self.heightPublisher.send(0) }
        } else {
            withAnimation { [self] in
                heightPublisher.send(itemSize.height + inset.top + inset.bottom)
            }
        }
    }

    public func reloadItem(itemIdentifier: Item.ID) {
        var snapshot = dataSoruce.snapshot()
        snapshot.reloadItems([itemIdentifier])
        dataSoruce.apply(snapshot)
    }

    public func delete(itemIdentifier: Item.ID?) {
        guard let itemIdentifier else { return }
        attachmetns.removeValue(forKey: itemIdentifier)
    }

    public func insert(item: Item) {
        attachmetns.updateValue(item, forKey: item.id)
        reloadItem(itemIdentifier: item.id)
    }

    public func deleteAllItems() {
        attachmetns.removeAll()
    }
}

extension AttachmentsBar: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    var storage: TemporaryStorage? {
        var superview = superview
        while superview != nil {
            if let editor = superview as? RichEditorView {
                return editor.storage
            }
            superview = superview?.superview
        }
        return nil
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        cell.puddingAnimate()
        guard let itemIdentifier = dataSoruce.itemIdentifier(for: indexPath) else { return }
        guard let item = item(for: itemIdentifier) else { return }
        if let storage {
            switch item.type {
            case .image:
                let controller = QLPreviewController()
                let singlePreview = SingleItemDataSource(
                    item: storage.absoluteURL(item.storageSuffix),
                    name: NSLocalizedString("Image", bundle: .module, comment: "")
                )
                controller.dataSource = singlePreview
                controller.delegate = singlePreview
                parentViewController?.present(controller, animated: true)
                previewItemDataSource = singlePreview
                return
            case .text:
                let controller = TextEditorController()
                controller.text = item.textRepresentation
                controller.callback = { [weak self] output in
                    var attachment = item
                    let url = storage.absoluteURL(attachment.storageSuffix)
                    do {
                        try output.write(to: url, atomically: true, encoding: .utf8)
                    } catch { return }
                    attachment.textRepresentation = output
                    self?.insert(item: attachment)
                }
                parentViewController?.present(controller, animated: true)
                return
            }
        } else {
            let previewImageData = item.previewImage
            if let image = UIImage(data: previewImageData) {
                let data = image.pngData()
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("DisposableResources")
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("png")
                try? FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? data?.write(to: url)
                let controller = QLPreviewController()
                let singlePreview = SingleItemDataSource(
                    item: url,
                    name: NSLocalizedString("Image", bundle: .module, comment: "")
                )
                controller.dataSource = singlePreview
                controller.delegate = singlePreview
                parentViewController?.present(controller, animated: true)
                previewItemDataSource = singlePreview
                return
            }
            if !item.textRepresentation.isEmpty {
                let controller = TextEditorController()
                controller.text = item.textRepresentation
                controller.cancellable = false
                controller.rootController.title = String(localized: "Text Viewer", bundle: .module)
                #if targetEnvironment(macCatalyst)
                    controller.shouldDismissWhenTappedAround = true
                    controller.shouldDismissWhenEscapeKeyPressed = true
                #endif
                parentViewController?.present(controller, animated: true)
                return
            }
        }
    }

    public func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let itemIdentifier = dataSoruce.itemIdentifier(for: indexPath) else { return .zero }
        guard let item = item(for: itemIdentifier) else { return .zero }
        return itemSize(for: item.type)
    }

    private func itemSize(for type: Item.AttachmentType) -> CGSize {
        switch type {
        case .image:
            itemSize
        case .text:
            .init(width: itemSize.width * 3, height: itemSize.height)
        }
    }
}
