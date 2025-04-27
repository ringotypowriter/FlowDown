//
//  MessageListView+DataElement.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Combine
import Foundation
import UIKit

extension UIConversation.MessageListView {
    struct Element: Identifiable {
        let id: AnyHashable // equals to message id if applicable

        enum Cell: String, CaseIterable {
            case base
            case hint
            case user
            case assistantDocumentElement
            case spacer
        }

        let cell: Cell
        let viewModel: any ViewModel

        typealias UserObject = any(Identifiable & Hashable)
        let object: UserObject?

        init(id: AnyHashable, cell: Cell, viewModel: any ViewModel, object: UserObject?) {
            assert(cell != .base)
            self.id = id
            self.cell = cell
            self.viewModel = viewModel
            self.object = object
        }
    }
}

extension UIConversation.MessageListView.Element {
    static func transform(input: Conversation.Message) -> [UIConversation.MessageListView.Element] {
        switch input.participant {
        case .assistant:
            var ret: [UIConversation.MessageListView.Element] = []
            let intrinsicWidth = input.documentNode.map {
                $0.manifest(theme: .default).intrinsicWidth
            }.max() ?? 0
            let documentNodes = input.documentNode.map {
                UIConversation.MessageListView.AssistantDocumentElementCell.ViewModel(
                    block: $0,
                    groupIntrinsicWidth: intrinsicWidth,
                    groupLocation: .center
                )
            }
            for (idx, vm) in documentNodes.enumerated() {
                if idx == 0 { vm.groupLocation = .begin }
                if idx == documentNodes.count - 1 { vm.groupLocation = .end }
                ret.append(.init(
                    id: "\(input.id)-\(idx)",
                    cell: .assistantDocumentElement,
                    viewModel: vm,
                    object: input
                ))
            }
            return ret
        case .user:
            return [
                .init(
                    id: [input.id],
                    cell: .user,
                    viewModel: UIConversation.MessageListView.UserCell.ViewModel(text: input.document),
                    object: input
                ),
            ]
        case .system:
            return []
        case .hint:
            return [.init(
                id: [input.id],
                cell: .hint,
                viewModel: UIConversation.MessageListView.HintCell.ViewModel(hint: input.document),
                object: input
            )]
        }
    }
}

extension UIConversation.MessageListView.Element {
    func createMenu(referencingView view: UIView) -> UIMenu? {
        if let object = object as? Conversation.Message {
            return object.createMenu(referencingView: view)
        }
        return nil
    }
}

extension UIConversation.MessageListView.Element.Cell {
    var cellClass: UIConversation.MessageListView.BaseCell.Type {
        switch self {
        case .base:
            UIConversation.MessageListView.BaseCell.self
        case .hint:
            UIConversation.MessageListView.HintCell.self
        case .user:
            UIConversation.MessageListView.UserCell.self
        case .assistantDocumentElement:
            UIConversation.MessageListView.AssistantDocumentElementCell.self
        case .spacer:
            UIConversation.MessageListView.SpacerCell.self
        }
    }
}

extension UIConversation.MessageListView.Element {
    protocol ViewModel {
        func contentIdentifier(hasher: inout Hasher)
    }
}
