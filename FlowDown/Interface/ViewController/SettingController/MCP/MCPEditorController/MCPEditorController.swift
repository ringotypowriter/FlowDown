import AlertController
import Combine
import ConfigurableKit
import Storage
import UIKit

class MCPEditorController: StackScrollController {
    let clientId: MCPClient.ID
    private var client: MCPClient?
    
    var cancellables: Set<AnyCancellable> = .init()
    
    init(clientId: MCPClient.ID) {
        self.clientId = clientId
        super.init(nibName: nil, bundle: nil)
        title = String(localized: "Edit MCP Client")
        self.client = MCPService.shared.McpClient(identifier: clientId)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        
        navigationItem.rightBarButtonItem = .init(
            image: UIImage(systemName: "checkmark"),
            style: .done,
            target: self,
            action: #selector(checkTapped)
        )
        
        MCPService.shared.clientConfigs
            .removeDuplicates()
            .ensureMainThread()
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] clients in
                guard let self, isVisible else { return }
                if !clients.contains(where: { $0.id == self.clientId }) {
                    navigationController?.popViewController(animated: true)
                }
            }
            .store(in: &cancellables)
    }
    
    @objc func checkTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func deleteTapped() {
        let alert = AlertViewController(
            title: String(localized: "Delete Client"),
            message: String(localized: "Are you sure you want to delete this MCP client? This action cannot be undone.")
        ) { context in
            context.addAction(title: String(localized: "Cancel")) {
                context.dispose()
            }
            context.addAction(title: String(localized: "Delete"), attribute: .dangerous) {
                context.dispose { [weak self] in
                    guard let self else { return }
                    MCPService.shared.removeClient(identifier: clientId)
                    navigationController?.popViewController(animated: true)
                }
            }
        }
        present(alert, animated: true)
    }
    
    override func setupContentViews() {
        super.setupContentViews()
        
        guard let client = client else { return }
        
        // MARK: - Basic Information
        
        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Metadata"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())
        
        let nameView = ConfigurableInfoView().setTapBlock { view in
            let input = AlertInputViewController(
                title: String(localized: "Edit Name"),
                message: String(localized: "The display name of this MCP client."),
                placeholder: String(localized: "Unnamed MCP"),
                text: client.name
            ) { output in
                MCPService.shared.editClient(identifier: self.clientId) { client in
                    client.name = output
                }
                view.configure(value: output.isEmpty ? String(localized: "Unnamed Server") : output)
            }
            view.parentViewController?.present(input, animated: true)
        }
        nameView.configure(icon: .init(systemName: "tag"))
        nameView.configure(title: String(localized: "Name"))
        nameView.configure(description: String(localized: "The display name of this MCP client."))
        nameView.configure(value: client.name.isEmpty ? String(localized: "Unnamed Server") : client.name)
        stackView.addArrangedSubviewWithMargin(nameView)
        stackView.addArrangedSubview(SeparatorView())
        
        let descriptionView = ConfigurableInfoView().setTapBlock { view in
            let input = AlertInputViewController(
                title: String(localized: "Edit Description"),
                message: String(localized: "Optional description for this MCP Server."),
                placeholder: String(localized: "Enter description"),
                text: client.description
            ) { output in
                MCPService.shared.editClient(identifier: self.clientId) { client in
                    client.description = output
                }
                view.configure(value: output.isEmpty ? String(localized: "No Description") : output)
            }
            view.parentViewController?.present(input, animated: true)
        }
        descriptionView.configure(icon: .init(systemName: "text.alignleft"))
        descriptionView.configure(title: String(localized: "Description"))
        descriptionView.configure(description: String(localized: "Optional description for this MCP Server."))
        descriptionView.configure(value: client.description.isEmpty ? String(localized: "No Description") : client.description)
        stackView.addArrangedSubviewWithMargin(descriptionView)
        stackView.addArrangedSubview(SeparatorView())
        
        let enabledView = ConfigurableToggleActionView()
        enabledView.boolValue = client.isEnabled
        enabledView.actionBlock = { value in
            MCPService.shared.editClient(identifier: self.clientId) { client in
                client.isEnabled = value
            }
        }
        enabledView.configure(icon: .init(systemName: "power"))
        enabledView.configure(title: String(localized: "Enabled"))
        enabledView.configure(description: String(localized: "Whether this MCP Server is enabled."))
        stackView.addArrangedSubviewWithMargin(enabledView)
        stackView.addArrangedSubview(SeparatorView())
        
        // MARK: - Connection Settings
        
        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Connection"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())
        
        let typeView = ConfigurableInfoView()
        typeView.configure(icon: .init(systemName: "gear"))
        typeView.configure(title: String(localized: "Connection Type"))
        typeView.configure(description: String(localized: "The transport protocol to use for this client."))
        typeView.configure(value: client.type.rawValue.uppercased())
        typeView.setTapBlock { view in
            let children = [
                UIAction(
                    title: "HTTP",
                    image: UIImage(systemName: "network")
                ) { _ in
                    MCPService.shared.editClient(identifier: self.clientId) { client in
                        client.type = .http
                    }
                    view.configure(value: "HTTP")
                },
                UIAction(
                    title: "SSE",
                    image: UIImage(systemName: "antenna.radiowaves.left.and.right")
                ) { _ in
                    MCPService.shared.editClient(identifier: self.clientId) { client in
                        client.type = .sse
                    }
                    view.configure(value: "SSE")
                }
            ]
            view.present(
                menu: .init(title: String(localized: "Connection Type"), children: children),
                anchorPoint: .init(x: view.bounds.maxX, y: view.bounds.maxY)
            )
        }
        stackView.addArrangedSubviewWithMargin(typeView)
        stackView.addArrangedSubview(SeparatorView())
        
        let endpointView = ConfigurableInfoView().setTapBlock { view in
            let input = AlertInputViewController(
                title: String(localized: "Edit Endpoint"),
                message: String(localized: "The URL endpoint for this MCP client."),
                placeholder: "https://",
                text: client.endpoint.isEmpty ? "https://" : client.endpoint
            ) { output in
                MCPService.shared.editClient(identifier: self.clientId) { client in
                    client.endpoint = output
                }
                view.configure(value: output.isEmpty ? String(localized: "Not Configured") : output)
            }
            view.parentViewController?.present(input, animated: true)
        }
        endpointView.configure(icon: .init(systemName: "link"))
        endpointView.configure(title: String(localized: "Endpoint"))
        endpointView.configure(description: String(localized: "The URL endpoint for this MCP client."))
        endpointView.configure(value: client.endpoint.isEmpty ? String(localized: "Not Configured") : client.endpoint)
        stackView.addArrangedSubviewWithMargin(endpointView)
        stackView.addArrangedSubview(SeparatorView())
        
        let headerView = ConfigurableInfoView().setTapBlock { view in
            guard let client = MCPService.shared.McpClient(identifier: self.clientId) else { return }
            var text = client.header
            if text.isEmpty { text = "{}" }
            let textEditor = JsonStringMapEditorController(text: text)
            textEditor.title = String(localized: "Edit Headers")
            textEditor.collectEditedContent { result in
                guard let object = try? JSONDecoder().decode([String: String].self, from: result.data(using: .utf8) ?? .init()) else {
                    return
                }
                let jsonData = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted)
                let jsonString = String(data: jsonData ?? Data(), encoding: .utf8) ?? ""
                MCPService.shared.editClient(identifier: self.clientId) { client in
                    client.header = jsonString == "{}" ? "" : jsonString
                }
                view.configure(value: object.isEmpty ? String(localized: "No Headers") : String(localized: "Configured"))
            }
            view.parentViewController?.navigationController?.pushViewController(textEditor, animated: true)
        }
        headerView.configure(icon: .init(systemName: "list.bullet"))
        headerView.configure(title: String(localized: "Headers"))
        headerView.configure(description: String(localized: "Additional HTTP headers for requests."))
        headerView.configure(value: client.header.isEmpty ? String(localized: "No Headers") : String(localized: "Configured"))
        stackView.addArrangedSubviewWithMargin(headerView)
        stackView.addArrangedSubview(SeparatorView())
        
        let timeoutView = ConfigurableInfoView().setTapBlock { view in
            let input = AlertInputViewController(
                title: String(localized: "Edit Timeout"),
                message: String(localized: "Request timeout in seconds."),
                placeholder: "60",
                text: "\(client.timeout)"
            ) { output in
                let timeout = Int(output) ?? 60
                MCPService.shared.editClient(identifier: self.clientId) { client in
                    client.timeout = timeout
                }
                view.configure(value: "\(timeout)s")
            }
            view.parentViewController?.present(input, animated: true)
        }
        timeoutView.configure(icon: .init(systemName: "timer"))
        timeoutView.configure(title: String(localized: "Timeout"))
        timeoutView.configure(description: String(localized: "Request timeout in seconds."))
        timeoutView.configure(value: "\(client.timeout)s")
        stackView.addArrangedSubviewWithMargin(timeoutView)
        stackView.addArrangedSubview(SeparatorView())
        


        // MARK: - Test / fetch tools
        let testAction = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            // deleteTapped() 
            // TODO: Testing method.
        }
        testAction.configure(icon: UIImage(systemName: "wand.and.stars"))
        testAction.configure(title: String(localized: "Test Configuration"))
        testAction.configure(description: String(localized: "Test the configuration of the MCP server."))


        stackView.addArrangedSubviewWithMargin(testAction)
        stackView.addArrangedSubview(SeparatorView())
        // MARK: - Tool management.
        /*
            only visible when MCPClient is is enabled.
        */

        // MARK: - Resource Management

        // MARK: - Template mangement
        
        // MARK: - Management
        
        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Management"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())
        
        let deleteAction = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            deleteTapped()
        }
        deleteAction.configure(icon: UIImage(systemName: "trash"))
        deleteAction.configure(title: String(localized: "Delete Server"))
        deleteAction.configure(description: String(localized: "Delete this MCP server permanently."))
        deleteAction.titleLabel.textColor = .systemRed
        deleteAction.iconView.tintColor = .systemRed
        deleteAction.descriptionLabel.textColor = .systemRed
        deleteAction.imageView.tintColor = .systemRed
        stackView.addArrangedSubviewWithMargin(deleteAction)
        stackView.addArrangedSubview(SeparatorView())
    
    }
}
