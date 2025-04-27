//
//  AddServiceProviderViewController+Models.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/8.
//

import ConfigurableKit
import OrderedCollections
import UIKit

extension AddServiceProviderViewController {
    @objc func fetchModel() {
        fetchModelTask?.cancel()
        fetchModelTask = nil
        pickValuesFromFormAndSave()
        let alert = UIAlertController(
            title: NSLocalizedString("Fetch Model", comment: ""),
            message: NSLocalizedString("Communicating with service provider...", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Cancel", comment: ""),
            style: .cancel
        ))
        present(alert, animated: true) {
            let task = self.createFetchTask(progressController: alert)
            self.fetchModelTask = task
        }
    }

    @objc func editModels() {
        let editor = ModelAvailabilityEditorController(
            dataSource: provider.models,
            currentEnabledModels: provider.enabledModels
        )
        editor.onUpdateBlock = { input in
            self.provider.enabledModels = input
            self.pickValuesFromFormAndSave()
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func createFetchTask(progressController: UIViewController) -> Task<Void, Never> {
        .detached {
            assert(!Thread.isMainThread)
            let result = await self.provider.fetchModels()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                progressController.dismiss(animated: true) {
                    switch result {
                    case let .success(success):
                        self.processSuccess(models: success)
                    case let .failure(failure):
                        self.processFailure(error: failure)
                    }
                    self.fetchModelTask = nil
                }
            }
        }
    }

    private func processSuccess(models: ServiceProvider.Models) {
        provider.models = models
        pickValuesFromFormAndSave()
        editModels()
    }

    private func processFailure(error: Error) {
        let alert = UIAlertController(
            title: NSLocalizedString("Error", comment: ""),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("OK", comment: ""),
            style: .cancel
        ))
        present(alert, animated: true)
    }
}
