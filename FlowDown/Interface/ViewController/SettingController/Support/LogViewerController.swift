//
//  LogViewerController.swift
//  FlowDown
//

import Storage
import UIKit

final class LogViewerController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var lines: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "Logs")
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: String(localized: "Share"), style: .plain, target: self, action: #selector(shareLog)),
            UIBarButtonItem(title: String(localized: "Clear"), style: .plain, target: self, action: #selector(clearLog)),
        ]

        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .singleLine
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        reload()
    }

    @objc private func reload() {
        let text = LogStore.shared.readTail()
        lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        tableView.reloadData()
        if !lines.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: max(lines.count - 1, 0), section: 0), at: .bottom, animated: false)
        }
    }

    @objc private func shareLog() {
        let text = LogStore.shared.readTail(maxBytes: 512 * 1024)
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(vc, animated: true)
    }

    @objc private func clearLog() {
        LogStore.shared.clear()
        reload()
    }

    func numberOfSections(in _: UITableView) -> Int { 1 }
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { lines.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let id = "cell"
        let cell = tableView.dequeueReusableCell(withIdentifier: id) ?? UITableViewCell(style: .subtitle, reuseIdentifier: id)
        cell.textLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = lines[indexPath.row]
        cell.selectionStyle = .none
        return cell
    }
}
