//
//  ChatTemplateEditorController.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/28/25.
//

import AlertController
import Combine
import ConfigurableKit
import UIKit

private let dateFormatter: DateFormatter = .init().with {
    $0.dateStyle = .short
    $0.timeStyle = .short
}

class ChatTemplateEditorController: StackScrollController, UITextViewDelegate {
    let templateIdentifier: ChatTemplate.ID
    init(templateIdentifier: ChatTemplate.ID) {
        self.templateIdentifier = templateIdentifier
        super.init(nibName: nil, bundle: nil)
        title = String(localized: "Edit Template")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    var cancellables: Set<AnyCancellable> = .init()

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background

        navigationItem.rightBarButtonItem = .init(
            image: UIImage(systemName: "checkmark"),
            style: .done,
            target: self,
            action: #selector(checkTapped)
        )

        ChatTemplateManager.shared.$templates
            .removeDuplicates()
            .ensureMainThread()
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] templates in
                guard let self, isVisible else { return }
                guard templates[templateIdentifier] != nil else {
                    navigationController?.popViewController(animated: true)
                    return
                }
            }
            .store(in: &cancellables)
    }

    @objc func checkTapped() {
        navigationController?.popViewController()
    }

    @objc func deleteTapped() {
        let alert = AlertViewController(
            title: String(localized: "Delete Template"),
            message: String(localized: "Are you sure you want to delete this template? This action cannot be undone.")
        ) { context in
            context.addAction(title: String(localized: "Cancel")) {
                context.dispose()
            }
            context.addAction(title: String(localized: "Delete"), attribute: .dangerous) {
                context.dispose { [weak self] in
                    guard let self else { return }
                    ChatTemplateManager.shared.remove(for: templateIdentifier)
                }
            }
        }
        present(alert, animated: true)
    }

    override func setupContentViews() {
        super.setupContentViews()

        guard let template = ChatTemplateManager.shared.template(for: templateIdentifier) else { return }

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Basic Information"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let nameView = ConfigurableInfoView().setTapBlock { view in
            guard let template = ChatTemplateManager.shared.template(for: self.templateIdentifier) else { return }
            let input = AlertInputViewController(
                title: String(localized: "Edit Name"),
                message: String(localized: "The display name of this chat template."),
                placeholder: String(localized: "Enter template name"),
                text: template.name
            ) { output in
                ChatTemplateManager.shared.update(template.with { $0.name = output })
                view.configure(value: output)
            }
            view.parentViewController?.present(input, animated: true)
        }
        nameView.configure(icon: .init(systemName: "textformat"))
        nameView.configure(title: String(localized: "Name"))
        nameView.configure(description: String(localized: "The display name of this chat template."))
        nameView.configure(value: template.name)
        stackView.addArrangedSubviewWithMargin(nameView)
        stackView.addArrangedSubview(SeparatorView())

        let avatarView = CircleImageView()
        avatarView.contentMode = .scaleAspectFill
        avatarView.image = UIImage(data: template.avatar) ?? UIImage(systemName: "person.crop.circle.fill")!
        stackView.addArrangedSubviewWithMargin(avatarView)
        stackView.addArrangedSubview(SeparatorView())

        let descriptionView = ConfigurableInfoView().setTapBlock { view in
            guard let template = ChatTemplateManager.shared.template(for: self.templateIdentifier) else { return }
            let input = AlertInputViewController(
                title: String(localized: "Edit Description"),
                message: String(localized: "A brief description of what this template does."),
                placeholder: String(localized: "Enter template description"),
                text: template.templateDescription
            ) { output in
                ChatTemplateManager.shared.update(template.with { $0.templateDescription = output })
                view.configure(value: output)
            }
            view.parentViewController?.present(input, animated: true)
        }
        descriptionView.configure(icon: .init(systemName: "text.quote"))
        descriptionView.configure(title: String(localized: "Description"))
        descriptionView.configure(description: String(localized: "A brief description of what this template does."))
        descriptionView.configure(value: template.templateDescription)
        stackView.addArrangedSubviewWithMargin(descriptionView)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Configuration"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let promptBehaviorView = ConfigurableInfoView()
        promptBehaviorView.configure(icon: .init(systemName: "gear"))
        promptBehaviorView.configure(title: String(localized: "Application Prompt Behavior"))
        promptBehaviorView.configure(description: String(localized: "How this template interacts with application prompts."))
        let behaviorTitle = template.applicationPromptBehavior == .inherit ?
            String(localized: "Inherit") : String(localized: "Ignore")
        promptBehaviorView.configure(value: behaviorTitle)
        promptBehaviorView.setTapBlock { view in
            let children = [
                UIAction(
                    title: String(localized: "Inherit"),
                    image: UIImage(systemName: "arrow.down.circle")
                ) { _ in
                    ChatTemplateManager.shared.update(template.with { $0.applicationPromptBehavior = .inherit })
                    view.configure(value: String(localized: "Inherit"))
                },
                UIAction(
                    title: String(localized: "Ignore"),
                    image: UIImage(systemName: "xmark.circle")
                ) { _ in
                    ChatTemplateManager.shared.update(template.with { $0.applicationPromptBehavior = .ignore })
                    view.configure(value: String(localized: "Ignore"))
                },
            ]
            view.present(
                menu: .init(title: String(localized: "Prompt Behavior"), children: children),
                anchorPoint: .init(x: view.bounds.maxX, y: view.bounds.maxY)
            )
        }
        stackView.addArrangedSubviewWithMargin(promptBehaviorView)
        stackView.addArrangedSubview(SeparatorView())

        let modelView = ConfigurableInfoView()
        modelView.configure(icon: .init(systemName: "cpu"))
        modelView.configure(title: String(localized: "Model"))
        modelView.configure(description: String(localized: "The default model to use with this template."))
        modelView.configure(value: "TODO")
        modelView.setTapBlock { view in
            // TODO: Implement model selection
            Indicator.present(
                title: String(localized: "Feature Coming Soon"),
                referencingView: view
            )
        }
        stackView.addArrangedSubviewWithMargin(modelView)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Prompt"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let promptHeaderView = ConfigurableInfoView()
        promptHeaderView.configure(icon: .init(systemName: "text.bubble"))
        promptHeaderView.configure(title: String(localized: "Template Prompt"))
        promptHeaderView.configure(description: String(localized: "The prompt text that will be used as the foundation for conversations with this template."))
        promptHeaderView.configure(value: "")
        stackView.addArrangedSubviewWithMargin(promptHeaderView)

        let promptTextView = UITextView().with {
            $0.font = .systemFont(ofSize: 16)
            $0.backgroundColor = .secondarySystemGroupedBackground
            $0.layer.cornerRadius = 8
            $0.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            $0.isScrollEnabled = true
            $0.text = template.prompt
            $0.delegate = self
        }
        promptTextView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(120)
        }
        stackView.addArrangedSubviewWithMargin(promptTextView)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionFooterView()
                .with(footer: String(localized: "The prompt serves as the initial instruction for the AI model. It defines the character, behavior, and context for the conversation."))
        ) { $0.top /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Management"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let deleteAction = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            deleteTapped()
        }
        deleteAction.configure(icon: UIImage(systemName: "trash"))
        deleteAction.configure(title: String(localized: "Delete Template"))
        deleteAction.configure(description: String(localized: "Delete this template permanently."))
        deleteAction.titleLabel.textColor = .systemRed
        deleteAction.iconView.tintColor = .systemRed
        deleteAction.descriptionLabel.textColor = .systemRed
        deleteAction.imageView.tintColor = .systemRed
        stackView.addArrangedSubviewWithMargin(deleteAction)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(UIView())

        let icon = UIImageView().with {
            $0.image = UIImage(systemName: "text.bubble")
            $0.tintColor = .label.withAlphaComponent(0.25)
            $0.contentMode = .scaleAspectFit
            $0.snp.makeConstraints { make in
                make.width.height.equalTo(24)
            }
        }
        stackView.addArrangedSubviewWithMargin(icon) { $0.bottom /= 2 }

        let footer = UILabel().with {
            $0.font = .rounded(
                ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize,
                weight: .regular
            )
            $0.textColor = .label.withAlphaComponent(0.25)
            $0.numberOfLines = 0
            $0.text = templateIdentifier.uuidString
            $0.textAlignment = .center
        }
        stackView.addArrangedSubviewWithMargin(footer) { $0.top /= 2 }
        stackView.addArrangedSubviewWithMargin(UIView())
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        guard let template = ChatTemplateManager.shared.template(for: templateIdentifier) else { return }
        ChatTemplateManager.shared.update(template.with { $0.prompt = textView.text })
    }
}
