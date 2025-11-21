//
//  SelectCountryController.swift
//  vpnOKAN
//
//  Created by Mustafa MEDENi on 31.10.2020.
//

import UIKit

class SelectCountryController: UIViewController {

    var servers: [Country] = []
    var selectedServer: Country?
    var onServerSelected: ((Country) -> Void)?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        loadServers()
    }

    // MARK: - Server Management

    func loadServers() {
        servers = Country.getDummyServers()

        // Select first server by default
        if let firstServer = servers.first {
            selectedServer = firstServer
            updateUI()
        }
    }

    func updateUI() {
        // Update your UI to display server list
        print("Available servers:")
        for (index, server) in servers.enumerated() {
            let selectedMark = server.id == selectedServer?.id ? "✓" : " "
            print("[\(selectedMark)] \(index + 1). \(server.name) - \(server.ip)")
        }
    }

    // MARK: - Server Selection

    func selectServer(at index: Int) {
        guard index >= 0 && index < servers.count else {
            print("Invalid server index")
            return
        }

        let server = servers[index]
        selectedServer = server
        updateUI()

        print("Selected server: \(server.name)")

        // Notify parent controller
        onServerSelected?(server)
    }

    func selectServerById(_ id: String) {
        guard let server = servers.first(where: { $0.id == id }) else {
            print("Server not found: \(id)")
            return
        }

        selectedServer = server
        updateUI()

        print("Selected server: \(server.name)")

        // Notify parent controller
        onServerSelected?(server)
    }

    // MARK: - Actions

    @IBAction func serverButtonTapped(_ sender: UIButton) {
        // Get server index from button tag or other identifier
        let serverIndex = sender.tag
        selectServer(at: serverIndex)
    }

    @IBAction func confirmButtonTapped() {
        guard let server = selectedServer else {
            print("No server selected")
            return
        }

        print("Confirmed selection: \(server.name)")
        onServerSelected?(server)

        // Dismiss or navigate
        dismiss(animated: true, completion: nil)
    }
}
