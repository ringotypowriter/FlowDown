//
//  AddServiceProviderViewController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/7.
//

import ConfigurableKit
import UIKit

class AddServiceProviderViewController: StackScrollController, UITextFieldDelegate {
    var provider: ServiceProvider
    var fetchModelTask: Task<Void, Never>?

    override var title: String? {
        get {
            if provider.name.isEmpty {
                NSLocalizedString("Add Service Provider", comment: "")
            } else {
                provider.name
            }
        }
        set { _ = newValue }
    }

    init(initialEditing provider: ServiceProvider) {
        self.provider = provider
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("Add Service Provider", comment: "")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    lazy var nameTextField = UITextField().then { view in
        view.placeholder = NSLocalizedString("Name", comment: "")
        view.borderStyle = .none
        view.textContentType = .name
        view.clearButtonMode = .whileEditing
        view.returnKeyType = .done
        view.font = .preferredFont(forTextStyle: .footnote).bold
        view.textColor = .accent
        view.backgroundColor = .clear
    }

    lazy var baseEndpointTextField = UITextField().then { view in
        view.placeholder = NSLocalizedString("https://", comment: "")
        view.borderStyle = .none
        view.keyboardType = .URL
        view.autocapitalizationType = .none
        view.autocorrectionType = .no
        view.textContentType = .URL
        view.clearButtonMode = .whileEditing
        view.returnKeyType = .done
        view.font = .preferredFont(forTextStyle: .footnote).bold
        view.textColor = .accent
        view.backgroundColor = .clear
    }

    lazy var passwordTextField = UITextField().then { view in
        view.placeholder = NSLocalizedString("Access Token", comment: "")
        view.borderStyle = .none
        view.textContentType = .password
        view.clearButtonMode = .whileEditing
        view.returnKeyType = .done
        view.font = .preferredFont(forTextStyle: .footnote).bold
        view.textColor = .accent
        view.backgroundColor = .clear
    }

    lazy var fetchModelButton = UIButton().then {
        $0.setAttributedTitle(NSAttributedString(
            string: NSLocalizedString("Fetch Models", comment: ""),
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor.accent,
                .font: UIFont.preferredFont(forTextStyle: .footnote),
            ]
        ), for: .normal)
        $0.addTarget(self, action: #selector(fetchModel), for: .touchUpInside)
    }

    lazy var editModelButton = UIButton().then {
        $0.setAttributedTitle(NSAttributedString(
            string: NSLocalizedString("Edit Enabled Models", comment: ""),
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor.accent,
                .font: UIFont.preferredFont(forTextStyle: .footnote),
            ]
        ), for: .normal)
        $0.setAttributedTitle(NSAttributedString(
            string: NSLocalizedString("Edit Enabled Models", comment: ""),
            attributes: [
                .foregroundColor: UIColor.gray,
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .strikethroughColor: UIColor.gray,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            ]
        ), for: .disabled)
        $0.addTarget(self, action: #selector(editModels), for: .touchUpInside)
    }

    let modelListView = TextView().then {
        $0.isSelectable = true
        $0.isEditable = false
        $0.isScrollEnabled = false
        $0.font = .preferredFont(forTextStyle: .footnote)
        $0.textColor = .label.withAlphaComponent(0.5)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        assert(navigationController != nil)

        view.backgroundColor = .comfortableBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )

        applyInitialValues()
    }

    override func setupContentViews() {
        super.setupContentViews()

        stackView.addArrangedSubview(SeparatorView())
        addSection(
            icon: UIImage(systemName: "person.text.rectangle"),
            title: NSLocalizedString("Name", comment: ""),
            description: NSLocalizedString("Give it a name will make our life easier.", comment: ""),
            contentView: nameTextField
        )
        nameTextField.delegate = self
        addSection(
            icon: UIImage(systemName: "link"),
            title: NSLocalizedString("Base Endpoint", comment: ""),
            description: NSLocalizedString("The base URL for the service provider. Path is without v1 in suffix.", comment: ""),
            contentView: baseEndpointTextField
        )
        baseEndpointTextField.delegate = self
        var openKeyLink: (() -> Void)?
        if let keyLink = provider.template.acquireTokenURL {
            openKeyLink = { UIApplication.shared.open(keyLink, options: [:], completionHandler: nil) }
        }
        addSection(
            icon: UIImage(systemName: "key"),
            title: NSLocalizedString("Access Token", comment: ""),
            description: NSLocalizedString("The access token for the service provider. Leave blank if not required.", comment: ""),
            contentView: passwordTextField,
            action: openKeyLink
        )

        stackView.addArrangedSubviewWithMargin(UIStackView().then {
            $0.axis = .horizontal
            $0.spacing = 16
            $0.distribution = .equalSpacing
            $0.alignment = .center
            $0.addArrangedSubview(UIView().then {
                $0.setContentHuggingPriority(.defaultLow, for: .horizontal)
                $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            })
            $0.addArrangedSubview(fetchModelButton)
            $0.addArrangedSubview(editModelButton)
            $0.addArrangedSubview(UIView().then {
                $0.setContentHuggingPriority(.defaultLow, for: .horizontal)
                $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            })
        })

        stackView.addArrangedSubview(SeparatorView())
        stackView.addArrangedSubviewWithMargin(modelListView)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pickValuesFromFormAndSave()
    }

    func addSection(
        icon: UIImage? = UIImage(systemName: "circle"),
        title: String,
        description: String,
        contentView: UIView,
        action: (() -> Void)? = nil
    ) {
        let view = if let action {
            ConfigurableActionView(actionBlock: { _ in action() }).then {
                $0.configure(icon: icon)
                $0.configure(title: title)
                $0.configure(description: description)
                $0.imageView.image = .init(systemName: "arrow.up.right.circle.fill")
                $0.imageView.tintColor = .accent
            }
        } else {
            ConfigurableLabelView().then {
                $0.configure(icon: icon)
                $0.configure(title: title)
                $0.configure(description: description)
            }
        }
        stackView.addArrangedSubviewWithMargin(view) { inset in
            inset.bottom /= 2
        }
        stackView.addArrangedSubviewWithMargin(contentView) { inset in
            inset.top /= 2
            inset.bottom /= 2
        }.then { view in
            view.backgroundColor = .accent.withAlphaComponent(0.05)
        }
    }

    func textFieldDidEndEditing(_: UITextField) {
        pickValuesFromFormAndSave()
    }
}
