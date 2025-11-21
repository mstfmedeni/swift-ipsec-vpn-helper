//
//  HomeController.swift
//
//  Created by Mustafa MEDENi on 24.10.2020.
//

import UIKit
import NetworkExtension

class HomeController: UIViewController {

    let vpnManager = NEVPNManager.shared()
    var selectedCountry: Country?
    var timer = Timer()
    var countries: [Country] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Listen to VPN status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusChanged),
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )

        // Load servers
        loadServers()
    }

    deinit {
        timer.invalidate()
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )
        selectedCountry?.vpn.disconnectVPN()
        vpnManager.connection.stopVPNTunnel()
    }

    // MARK: - Server Management

    func loadServers() {
        countries = Country.getDummyServers()

        // Select first server by default
        if let firstServer = countries.first {
            selectedCountry = firstServer
            print("Selected server: \(firstServer.name) - \(firstServer.ip)")
        }
    }

    // MARK: - VPN Connection

    @IBAction func connectButtonTapped() {
        guard let country = selectedCountry else {
            print("No server selected")
            return
        }

        let status = vpnManager.connection.status

        switch status {
        case .invalid:
            // First time setup - need to save VPN configuration
            country.vpn.saveVPN { [weak self] error in
                if let error = error {
                    print("Error saving VPN configuration: \(error.localizedDescription)")
                    return
                }
                // After saving, connect
                country.vpn.connectVPN()
            }

        case .disconnected:
            // Connect to VPN
            country.vpn.connectVPN()
            print("Connecting to \(country.name)...")

        case .connected:
            // Disconnect from VPN
            country.vpn.disconnectVPN()
            print("Disconnecting from \(country.name)...")

        case .connecting, .disconnecting, .reasserting:
            print("VPN is in transition state, please wait...")

        @unknown default:
            print("Unknown VPN status")
        }
    }

    func switchServer(to newCountry: Country) {
        // Disconnect from current server if connected
        if vpnManager.connection.status == .connected {
            selectedCountry?.vpn.disconnectVPN()
        }

        // Switch to new server
        selectedCountry = newCountry
        print("Switched to server: \(newCountry.name) - \(newCountry.ip)")

        // Connect to new server
        newCountry.vpn.connectVPN()
    }

    // MARK: - VPN Status Monitoring

    @objc func vpnStatusChanged() {
        let status = vpnManager.connection.status

        switch status {
        case .connecting:
            print("VPN Status: Connecting...")
            updateUI(status: "Connecting...")

        case .connected:
            print("VPN Status: Connected")
            updateUI(status: "Connected")
            startConnectionTimer()

        case .disconnecting:
            print("VPN Status: Disconnecting...")
            updateUI(status: "Disconnecting...")

        case .disconnected:
            print("VPN Status: Disconnected")
            updateUI(status: "Disconnected")
            stopConnectionTimer()

        case .invalid:
            print("VPN Status: Invalid")
            updateUI(status: "Not Configured")

        case .reasserting:
            print("VPN Status: Reconnecting...")
            updateUI(status: "Reconnecting...")

        @unknown default:
            print("VPN Status: Unknown")
        }
    }

    func updateUI(status: String) {
        // Update your UI labels/buttons here
        print("UI Update: \(status)")
    }

    // MARK: - Connection Timer

    func startConnectionTimer() {
        stopConnectionTimer()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateConnectionTime),
            userInfo: nil,
            repeats: true
        )
    }

    func stopConnectionTimer() {
        timer.invalidate()
    }

    @objc func updateConnectionTime() {
        guard let connectedDate = vpnManager.connection.connectedDate else { return }

        let duration = Date().timeIntervalSince(connectedDate)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        let timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        print("Connected for: \(timeString)")

        // Update your UI timer label here
    }
}
