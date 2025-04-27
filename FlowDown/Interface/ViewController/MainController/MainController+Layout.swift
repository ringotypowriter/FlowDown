//
//  MainController+Layout.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/20/25.
//

import UIKit

extension MainController {
    func setupLayoutAsCatalyst() {
        sidebarView.snp.remakeConstraints { make in
            make.left.bottom.top.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.width.equalTo(256)
        }
        contentView.layer.cornerRadius = 8
        contentView.snp.remakeConstraints { make in
            make.left.equalTo(sidebarView.snp.right).offset(16)
            make.top.bottom.right.equalToSuperview().inset(16)
        }
    }

    func setupLayoutAsCompactStyle() {
        switch isSidebarCollapsed {
        case true:
            sidebarView.snp.remakeConstraints { make in
                make.left.equalToSuperview().inset(-50)
                make.top.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
                make.width.equalTo(view.snp.width).offset(-40)
            }
            gestureLayoutGuide.snp.remakeConstraints { make in
                make.left.equalToSuperview()
                make.top.bottom.equalToSuperview()
                make.width.equalTo(0)
            }
            contentView.layer.cornerRadius = 0
            contentView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.width.equalToSuperview()
                make.left.equalTo(gestureLayoutGuide.snp.right)
            }
        case false:
            sidebarView.snp.remakeConstraints { make in
                make.top.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
                make.left.equalTo(view.safeAreaLayoutGuide).inset(20)
                make.right.equalTo(view.safeAreaLayoutGuide).inset(60)
            }
            gestureLayoutGuide.snp.remakeConstraints { make in
                make.left.equalTo(sidebarView.snp.right)
                make.top.bottom.equalToSuperview()
                make.width.equalTo(0)
            }
            contentView.layer.cornerRadius = 28
            contentView.snp.remakeConstraints { make in
                make.width.equalToSuperview()
                make.top.bottom.equalTo(sidebarView)
                make.left.equalTo(gestureLayoutGuide.snp.right).offset(20)
            }
        }
    }

    func setupLayoutAsRelaxedStyle() {
        switch isSidebarCollapsed {
        case true:
            sidebarView.snp.remakeConstraints { make in
                make.left.equalToSuperview().offset(-50)
                make.top.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
                make.width.equalTo(256)
            }
            gestureLayoutGuide.snp.remakeConstraints { make in
                make.left.equalToSuperview()
                make.top.bottom.equalToSuperview()
                make.width.equalTo(0)
            }
            contentView.layer.cornerRadius = 8
            contentView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.width.equalToSuperview()
                make.left.equalTo(gestureLayoutGuide.snp.right)
            }
        case false:
            sidebarView.snp.remakeConstraints { make in
                make.top.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
                make.left.equalTo(view.safeAreaLayoutGuide).inset(20)
                make.width.equalTo(256)
            }
            gestureLayoutGuide.snp.remakeConstraints { make in
                make.left.equalTo(sidebarView.snp.right)
                make.top.bottom.equalToSuperview()
                make.width.equalTo(0)
            }
            contentView.layer.cornerRadius = 28
            contentView.snp.remakeConstraints { make in
                make.width.equalToSuperview()
                make.top.bottom.equalTo(sidebarView)
                make.left.equalTo(gestureLayoutGuide.snp.right).offset(20)
            }
        }
    }
}
