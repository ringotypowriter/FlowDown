//
//  EditorSectionView.swift
//  RichEditor
//
//  Created by 秋星桥 on 2025/1/16.
//

import Combine
import UIKit

public class EditorSectionView: UIView {
    public let heightPublisher: CurrentValueSubject<CGFloat, Never> = .init(0)
    public var cancellables: Set<AnyCancellable> = .init()

    var horizontalAdjustment: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    public required init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        clipsToBounds = false
        layer.masksToBounds = false

        initializeViews()

        for view in subviews {
            guard let view = view as? EditorSectionView else { continue }
            view.heightPublisher
                .removeDuplicates()
                .ensureMainThread()
                .sink { [weak self] _ in self?.subviewHeightDidChanged() }
                .store(in: &cancellables)
        }
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError()
    }

    public func initializeViews() {
        setNeedsLayout()
    }

    public func subviewHeightDidChanged() {
        setNeedsLayout()
        layoutIfNeeded()
    }
}
