//
//  ConversationCaptureView.swift
//  FlowDown
//
//  Created by 秋星桥 on 3/19/25.
//

import GlyphixTextFx
import Litext
import Storage
import UIKit

private let renderWidth = max(UIScreen.main.bounds.width, 520)

class ConversationCaptureView: UIView {
    let session: ConversationSession

    let titleBar = ChatView.TitleBar()
    let listView = MessageListView()
    let sepB = SeparatorView()
    let avatarView = UIImageView()

    let appLabel = UILabel()

    init(session: ConversationSession) {
        self.session = session

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleBar.textLabel.textColor = .label
        titleBar.bg.backgroundColor = .clear
        titleBar.icon.alpha = 1
        titleBar.use(identifier: session.id)
        addSubview(titleBar)
        titleBar.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
        }

        listView.session = session
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.top.equalTo(titleBar.snp.bottom).offset(16 - 4)
            make.left.right.equalToSuperview()
        }

        addSubview(sepB)
        sepB.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(listView.snp.bottom)
            make.height.equalTo(1)
        }

        avatarView.image = .avatar
        avatarView.contentMode = .scaleAspectFit
        avatarView.layerCornerRadius = 6
        avatarView.layer.cornerCurve = .continuous
        addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
            make.top.equalTo(sepB.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }

        appLabel.font = UIFont.rounded(ofSize: 12).bold
        appLabel.textColor = .label
        appLabel.text = "FlowDown.AI"
        appLabel.textAlignment = .center
        addSubview(appLabel)
        appLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarView.snp.bottom).offset(8)
            make.bottom.equalToSuperview().offset(-16)
            make.left.right.equalToSuperview()
        }

        clipsToBounds = true
        isUserInteractionEnabled = false
        overrideUserInterfaceStyle = .light
        backgroundColor = .background
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func capture(controller: UIViewController, _ completion: @escaping (UIImage?) -> Void) {
        assert(Thread.isMainThread)
        controller.view.addSubview(self)
        snp.remakeConstraints { make in
            make.top.equalTo(controller.view.snp.bottom)
            make.left.equalTo(controller.view.snp.right)
            make.width.equalTo(renderWidth)
            make.height.equalTo(1024)
        }
        layoutIfNeeded()

        var bfsViews: [UIView] = subviews
        while let firstView = bfsViews.first {
            bfsViews.removeFirst()
            bfsViews.append(contentsOf: firstView.subviews)

            // force an update
            if let trickLabel = firstView as? GlyphixTextLabel {
                trickLabel.textColor = .label
            }
        }

        // wait for message to be updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            let listHeight: CGFloat = listView.contentSize.height
            let footHeight: CGFloat = 16 + 24 + 8 + 12 + 16
            let height = titleBar.frame.height + listHeight + 50 + 1 + footHeight
            snp.remakeConstraints { make in
                make.top.equalTo(controller.view.snp.bottom).priority(.required)
                make.left.equalTo(controller.view.snp.right).priority(.required)
                make.width.equalTo(renderWidth).priority(.required)
                make.height.equalTo(height).priority(.required)
            }
            layoutIfNeeded()

            // let all animation complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                let render = UIGraphicsImageRenderer(bounds: bounds)
                let image = render.image { ctx in
                    layer.render(in: ctx.cgContext)
                }
                completion(image)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.removeFromSuperview()
                }
            }
        }
    }
}
