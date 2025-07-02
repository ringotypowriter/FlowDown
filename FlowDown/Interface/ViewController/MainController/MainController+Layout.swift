//
//  MainController+Layout.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/20/25.
//

import UIKit

extension MainController {
    private func createVisibleShadow() {
        contentShadowView.layer.shadowColor = UIColor.black.cgColor
        contentShadowView.layer.shadowOffset = .zero
        contentShadowView.layer.shadowRadius = 8
        #if targetEnvironment(macCatalyst)
            contentShadowView.layer.shadowOpacity = 0.025
        #else
            contentShadowView.layer.shadowOpacity = 0.1
        #endif
    }

    private func removeShadow() {
        contentShadowView.layer.shadowColor = UIColor.clear.cgColor
        contentShadowView.layer.shadowOffset = .zero
        contentShadowView.layer.shadowRadius = 0
        contentShadowView.layer.shadowOpacity = 0
    }

    func setupLayoutAsCatalyst() {
        sidebarView.snp.remakeConstraints { make in
            make.left.bottom.top.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.width.equalTo(sidebarWidth)
        }
        contentView.layer.cornerRadius = 8
        contentView.snp.remakeConstraints { make in
            make.left.equalTo(sidebarView.snp.right).offset(16)
            make.top.bottom.right.equalToSuperview().inset(16)
        }
        createVisibleShadow()
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
            removeShadow()
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
            createVisibleShadow()
        }
    }

    func setupLayoutAsRelaxedStyle() {
        switch isSidebarCollapsed {
        case true:
            sidebarView.snp.remakeConstraints { make in
                make.left.equalToSuperview().offset(-50)
                make.top.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
                make.width.equalTo(sidebarWidth)
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
            removeShadow()
        case false:
            sidebarView.snp.remakeConstraints { make in
                make.top.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
                make.left.equalTo(view.safeAreaLayoutGuide).inset(20)
                make.width.equalTo(sidebarWidth)
            }
            gestureLayoutGuide.snp.remakeConstraints { make in
                make.left.equalTo(sidebarView.snp.right)
                make.top.bottom.equalToSuperview()
                make.width.equalTo(0)
            }
            if allowSidebarPersistence {
                contentView.layer.cornerRadius = 0
                contentView.snp.remakeConstraints { make in
                    make.left.equalTo(gestureLayoutGuide.snp.right).offset(20)
                    make.right.equalToSuperview()
                    make.top.bottom.equalToSuperview()
                }
                removeShadow()
            } else {
                contentView.layer.cornerRadius = 28
                contentView.snp.remakeConstraints { make in
                    make.left.equalTo(gestureLayoutGuide.snp.right).offset(20)
                    make.width.equalToSuperview()
                    make.top.bottom.equalTo(sidebarView)
                }
                createVisibleShadow()
            }
        }
    }
}
