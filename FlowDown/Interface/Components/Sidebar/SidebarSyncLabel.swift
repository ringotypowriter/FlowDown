//
//  SidebarSyncLabel.swift
//  FlowDown
//
//  Created by qaq on 24/10/2025.
//

import Combine
import GlyphixTextFx
import SnapKit
import Storage
import UIKit

private let formatter: RelativeDateTimeFormatter = {
    let fmt = RelativeDateTimeFormatter()
    fmt.unitsStyle = .short
    return fmt
}()

class SidebarSyncLabel: UIView {
    let textLabel: GlyphixTextLabel = .init().with {
        $0.font = .preferredFont(forTextStyle: .footnote).bold
        $0.isBlurEffectEnabled = true
        $0.textColor = .label
        $0.textAlignment = .center
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.clipsToBounds = true
    }

    var cancellables = Set<AnyCancellable>()

    init() {
        super.init(frame: .zero)

        addSubview(textLabel)
        textLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        NotificationCenter.default.publisher(for: SyncEngine.SyncStatusChanged)
            .delay(for: .seconds(0.1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSyncStatus()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: SyncEngine.SyncStatusChanged)
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSyncStatus()
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSyncStatus() {
        if SyncEngine.isSynchronizing {
            textLabel.text = String(localized: "Syncing with iCloud")
        } else {
            if let data = SyncEngine.LastSyncDate, let dateText = formatter.string(for: data) {
                let text = String(localized: "Last synced \(dateText)")
                textLabel.text = text
            }
        }
    }

    func scheduleTextDismissal() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dismissText), object: nil)
        perform(#selector(dismissText), with: nil, afterDelay: 3.0)
    }

    @objc func dismissText() {
        textLabel.text = ""
    }
}
