//
//  ChatTemplateListController.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/28/25.
//

import Combine
import Foundation
import UIKit

class ChatTemplateController: UIViewController {
    private var cancellables = Set<AnyCancellable>()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}
