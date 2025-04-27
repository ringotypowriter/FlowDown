//
//  ContentView.swift
//  RichEditorDemo
//
//  Created by 秋星桥 on 2025/1/11.
//

import RichEditor

struct ContentView: View {
    var body: some View {
        NavigationView {
            Controller()
                .navigationTitle("FlowDown Editor")
                .toolbar {
                    ToolbarItem {
                        Button("Copy") {
                            NotificationCenter.default.post(name: .init("COPY"), object: nil)
                        }
                    }
                    ToolbarItem {
                        Button("Done") {
                            NotificationCenter.default.post(name: .init("DONE"), object: nil)
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}

struct Controller: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> some UIViewController {
        ContentController()
    }

    func updateUIViewController(_: UIViewControllerType, context _: Context) {}
}
