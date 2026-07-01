import Foundation

// MARK: - Notifications

extension Notification.Name {
    static let websitesDidChange = Notification.Name("websitesDidChange")
}

protocol NetworkMonitorDelegate: AnyObject {
    func networkMonitorDidUpdate(results: [WebsiteResult], quality: NetworkQuality)
    func networkMonitorDidStartTesting()
}

class NetworkMonitor {
    static let shared = NetworkMonitor()
    weak var delegate: NetworkMonitorDelegate?

    private var session: URLSession
    private var isTesting = false

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 15.0
        config.allowsCellularAccess = true
        self.session = URLSession(configuration: config)
    }

    func testAllWebsites() {
        guard !isTesting else { return }
        isTesting = true
        delegate?.networkMonitorDidStartTesting()

        let prefs = Preferences.shared
        let websites: [Website]
        switch prefs.environmentMode {
        case .domesticOnly:
            websites = prefs.websites.filter { $0.isEnabled && $0.isDomestic }
        case .global:
            websites = prefs.websites.filter { $0.isEnabled }
        }
        let group = DispatchGroup()
        var results: [WebsiteResult] = []
        let lock = NSLock()

        for website in websites {
            group.enter()
            testWebsite(website) { result in
                lock.lock()
                results.append(result)
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isTesting = false
            let quality = self?.calculateOverallQuality(results: results) ?? .noSignal
            self?.delegate?.networkMonitorDidUpdate(results: results, quality: quality)
        }
    }

    private func testWebsite(_ website: Website, completion: @escaping (WebsiteResult) -> Void) {
        let urlStr = website.url.hasPrefix("http") ? website.url : "https://\(website.url)"
        guard let url = URL(string: urlStr) else {
            completion(WebsiteResult(website: website, responseTime: -1, status: .timeout))
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Use HEAD first for speed, fall back to GET on error
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")

        let task = session.dataTask(with: request) { data, response, error in
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0 // ms

            if error != nil || response == nil {
                // Fallback to GET if HEAD fails (some servers don't support HEAD)
                self.retryWithGet(website, startTime: startTime, completion: completion)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(WebsiteResult(website: website, responseTime: -1, status: .timeout))
                }
                return
            }

            // If HEAD succeeded with 2xx/3xx, no need to retry
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 {
                let status: WebsiteStatus
                if elapsed < 200 {
                    status = .excellent
                } else if elapsed < 500 {
                    status = .good
                } else if elapsed < 1500 {
                    status = .fair
                } else {
                    status = .poor
                }
                DispatchQueue.main.async {
                    completion(WebsiteResult(website: website, responseTime: elapsed, status: status))
                }
                return
            }

            // Non-2xx from HEAD — retry with GET
            self.retryWithGet(website, startTime: startTime, completion: completion)
        }
        task.resume()
    }

    private func retryWithGet(_ website: Website, startTime: CFAbsoluteTime, completion: @escaping (WebsiteResult) -> Void) {
        let urlStr = website.url.hasPrefix("http") ? website.url : "https://\(website.url)"
        guard let url = URL(string: urlStr) else {
            DispatchQueue.main.async {
                completion(WebsiteResult(website: website, responseTime: -1, status: .timeout))
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let task = session.dataTask(with: request) { data, response, error in
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0 // ms

            if error != nil {
                DispatchQueue.main.async {
                    completion(WebsiteResult(website: website, responseTime: -1, status: .timeout))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(WebsiteResult(website: website, responseTime: -1, status: .timeout))
                }
                return
            }

            let status: WebsiteStatus
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 {
                if elapsed < 200 {
                    status = .excellent
                } else if elapsed < 500 {
                    status = .good
                } else if elapsed < 1500 {
                    status = .fair
                } else {
                    status = .poor
                }
            } else {
                status = .timeout
            }

            DispatchQueue.main.async {
                completion(WebsiteResult(website: website, responseTime: elapsed, status: status))
            }
        }
        task.resume()
    }

    private func calculateOverallQuality(results: [WebsiteResult]) -> NetworkQuality {
        guard !results.isEmpty else { return .noSignal }

        let validResults = results.filter { $0.status != .timeout }
        if validResults.isEmpty {
            return .noSignal
        }

        let avgTime = validResults.map { $0.responseTime }.reduce(0, +) / Double(validResults.count)

        if avgTime < 200 {
            return .excellent
        } else if avgTime < 500 {
            return .good
        } else if avgTime < 1500 {
            return .fair
        } else {
            return .poor
        }
    }
}
