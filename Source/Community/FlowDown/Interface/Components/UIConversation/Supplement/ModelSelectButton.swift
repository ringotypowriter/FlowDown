//
//  ModelSelectButton.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/4.
//

import Combine
import UIKit

extension UIConversation {
    class ModelSelectButton: UIView {
        let title = UILabel().then { label in
            label.textColor = .label
            label.font = .footnote
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.setContentHuggingPriority(.required, for: .horizontal)
        }

        let dropDownChevron = UIImageView().then { imageView in
            imageView.image = UIImage(systemName: "chevron.down")
            imageView.tintColor = .label
            imageView.contentMode = .scaleAspectFit
        }

        let button = UIButton()

        weak var delegate: Delegate?

        let modelType: ServiceProvider.ModelType
        init(modelType: ServiceProvider.ModelType) {
            self.modelType = modelType
            super.init(frame: .zero)

            addSubviews([title, dropDownChevron])
            title.snp.makeConstraints { make in
                make.left.equalToSuperview()
                make.centerY.equalToSuperview()
            }
            dropDownChevron.snp.makeConstraints { make in
                make.right.equalToSuperview()
                make.left.equalTo(title.snp.right).offset(4)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(16)
            }

            button.showsMenuAsPrimaryAction = true
            button.menu = UIMenu(
                options: [.singleSelection],
                children: [UIDeferredMenuElement.uncached { [weak self] provider in
                    guard let self else {
                        provider([])
                        return
                    }
                    provider(createMenu())
                }]
            )
            addSubview(button)
            button.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        func setTitle(_ string: String) {
            title.text = string
        }

        func createMenu() -> [UIMenuElement] {
            let modelType = modelType
            let providers = ServiceProviders.get()
            let allCount = providers.map(\.enabledModelCount).reduce(0, +)
            var options: UIMenu.Options = [.singleSelection]
            if allCount <= 10 { options.insert(.displayInline) }
            var menuList = [UIMenuElement]()
            for provider in providers {
                let children: [UIMenuElement] = provider.enabledModels[modelType]?.map { identifier in
                    UIAction(title: identifier) { [weak self] _ in
                        self?.delegate?.modelPickerDidPick(
                            provider: provider,
                            modelType: modelType,
                            modelIdentifier: identifier
                        )
                    }
                } ?? []
                menuList.append(UIMenu(
                    title: provider.name,
                    options: options,
                    children: children
                ))
            }
            return menuList
        }
    }
}
