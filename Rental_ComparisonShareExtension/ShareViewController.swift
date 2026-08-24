import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let activity = UIActivityIndicatorView(style: .large)
    private let message = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        message.text = "正在打开租房对比…"
        message.textAlignment = .center
        message.numberOfLines = 0
        activity.startAnimating()
        let stack = UIStackView(arrangedSubviews: [activity, message])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        readSharedURL()
    }

    private func readSharedURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            finish(message: "没有找到可导入的链接。")
            return
        }
        let providers = item.attachments ?? []
        loadURL(from: providers, index: 0)
    }

    private func loadURL(from providers: [NSItemProvider], index: Int) {
        guard index < providers.count else {
            finish(message: "分享内容中没有找到房源链接。")
            return
        }
        let provider = providers[index]
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                if let url = Self.url(from: item) {
                    self?.openHostApp(with: url)
                } else {
                    self?.loadURL(from: providers, index: index + 1)
                }
            }
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                if let text = item as? String,
                   let url = Self.url(in: text) {
                    self?.openHostApp(with: url)
                } else {
                    self?.loadURL(from: providers, index: index + 1)
                }
            }
            return
        }
        loadURL(from: providers, index: index + 1)
    }

    private func openHostApp(with sharedURL: URL) {
        var components = URLComponents()
        components.scheme = "rentalcomparison"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "url", value: sharedURL.absoluteString)]
        guard let appURL = components.url else {
            finish(message: "链接格式无法识别。")
            return
        }
        extensionContext?.open(appURL) { [weak self] success in
            DispatchQueue.main.async {
                self?.finish(message: success ? nil : "无法打开租房对比，请在 App 内粘贴链接。")
            }
        }
    }

    private func finish(message: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let message {
                self.activity.stopAnimating()
                self.message.text = message
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            } else {
                self.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let nsURL = item as? NSURL { return nsURL as URL }
        if let text = item as? String { return url(in: text) }
        return nil
    }

    private static func url(in text: String) -> URL? {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .compactMap { URL(string: String($0)) }
            .first { $0.scheme == "http" || $0.scheme == "https" }
    }
}
