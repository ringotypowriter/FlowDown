//
//  AddServiceProviderViewController+Form.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/8.
//

import ConfigurableKit
import OrderedCollections
import UIKit

extension AddServiceProviderViewController {
    func applyInitialValues() {
        nameTextField.text = provider.name
        baseEndpointTextField.text = provider.baseEndpoint.url?.absoluteString ?? "https://"
        passwordTextField.text = provider.token
        pickValuesFromFormAndSave()
    }

    func pickValuesFromFormAndSave() {
        provider.name = nameTextField.text ?? ""
        provider.baseEndpoint = baseEndpointTextField.text ?? ""
        provider.token = passwordTextField.text ?? ""
        if provider.enabledModelCount <= 0 {
            modelListView.text = NSLocalizedString("No models selected", comment: "")
        } else {
            modelListView.text = provider.enabledModelTextList
        }
        editModelButton.isEnabled = provider.modelCount > 0
        ServiceProviders.save(provider: provider)
    }

    @objc func doneButtonTapped() {
        pickValuesFromFormAndSave()
        if provider.modelCount <= 0 {
            fetchModel()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc func cancel() {
        let alert = UIAlertController(
            title: NSLocalizedString("Discard Changes?", comment: ""),
            message: NSLocalizedString("Are you sure you want to discard changes?", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Discard", comment: ""),
            style: .destructive,
            handler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }
        ))
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Cancel", comment: ""),
            style: .cancel
        ))
        present(alert, animated: true)
    }
}
