//
//  UIKitControllers.swift
//  VPN IPSec UIKit Implementation
//
//  All UIKit controllers in one file
//  Combined from: HomeController.swift, VpnConfigrationController.swift, SelectCountryController.swift
//  Created by Mustafa Medeni
//

import UIKit
import NetworkExtension

// MARK: - Base Controller

/// Base controller class for common functionality
/// Note: If you don't have a BaseController class in your project,
/// you can replace it with UIViewController in VpnConfigrationController
class BaseController: UIViewController {
    // Add common functionality here if needed
}

// MARK: - Home Controller

/// Main VPN screen and control
/// Manages VPN connections, server selection, and status monitoring
class HomeController: UIViewController {

    // MARK: - Properties

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

// MARK: - VPN Configuration Controller

/// Initial VPN configuration and permission screen
/// Used when VPN is set up for the first time
class VpnConfigrationController: BaseController {

    // MARK: - Properties

    var selectedCounty: Country?
    var dismissClosure: (() -> ())?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    // MARK: - Actions

    @IBAction func tapAppend() {
        self.selectedCounty?.vpn.saveVPN({ (err) in
            if let err = err {
                print(err)
                // Retry on error
                self.tapAppend()
                return
            }
            self.dismiss(animated: true) { [weak self] in
                self?.dismissClosure?()
            }
        })
    }
}

// MARK: - Select Country Controller

/// Server selection screen
/// Displays available VPN servers and handles selection
class SelectCountryController: UIViewController {

    // MARK: - Properties

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

// MARK: - Usage Examples

/*

 # UIKit VPN Controllers - Usage Examples

 ## 1. Using HomeController

 ```swift
 // In your storyboard or programmatically:
 let homeVC = HomeController()
 navigationController?.pushViewController(homeVC, animated: true)

 // Servers are loaded automatically in viewDidLoad
 // User can tap connect button to establish VPN connection
 ```

 ## 2. Using VpnConfigrationController for First-Time Setup

 ```swift
 let configVC = VpnConfigrationController()
 configVC.selectedCounty = myCountry

 // Set dismissal callback
 configVC.dismissClosure = {
     print("VPN configuration completed")
     // Connect to VPN or update UI
 }

 present(configVC, animated: true)
 ```

 ## 3. Using SelectCountryController

 ```swift
 let selectVC = SelectCountryController()

 // Set selection callback
 selectVC.onServerSelected = { [weak self] country in
     print("User selected: \(country.name)")
     self?.selectedCountry = country
     // Update UI or connect to new server
 }

 present(selectVC, animated: true)
 ```

 ## 4. Complete Flow Example

 ```swift
 class MainViewController: UIViewController {

     var selectedCountry: Country?
     let vpnManager = NEVPNManager.shared()

     @IBAction func showServerSelection() {
         let selectVC = SelectCountryController()

         selectVC.onServerSelected = { [weak self] country in
             guard let self = self else { return }

             // Check if VPN is configured
             if self.vpnManager.connection.status == .invalid {
                 // First time - show configuration screen
                 self.showConfiguration(for: country)
             } else {
                 // Already configured - switch server
                 self.switchToServer(country)
             }
         }

         present(selectVC, animated: true)
     }

     func showConfiguration(for country: Country) {
         let configVC = VpnConfigrationController()
         configVC.selectedCounty = country

         configVC.dismissClosure = { [weak self] in
             // Configuration done, connect
             country.vpn.connectVPN()
             self?.selectedCountry = country
         }

         present(configVC, animated: true)
     }

     func switchToServer(_ country: Country) {
         // Disconnect from current
         selectedCountry?.vpn.disconnectVPN()

         // Connect to new server
         selectedCountry = country
         country.vpn.connectVPN()
     }
 }
 ```

 ## 5. Monitoring VPN Status in Your ViewController

 ```swift
 class MyViewController: UIViewController {

     let vpnManager = NEVPNManager.shared()

     override func viewDidLoad() {
         super.viewDidLoad()

         NotificationCenter.default.addObserver(
             self,
             selector: #selector(vpnStatusChanged),
             name: NSNotification.Name.NEVPNStatusDidChange,
             object: nil
         )
     }

     @objc func vpnStatusChanged() {
         let status = vpnManager.connection.status

         DispatchQueue.main.async {
             switch status {
             case .connected:
                 self.statusLabel.text = "Connected"
                 self.connectButton.setTitle("Disconnect", for: .normal)

             case .disconnected:
                 self.statusLabel.text = "Disconnected"
                 self.connectButton.setTitle("Connect", for: .normal)

             case .connecting:
                 self.statusLabel.text = "Connecting..."
                 self.connectButton.isEnabled = false

             default:
                 break
             }
         }
     }

     deinit {
         NotificationCenter.default.removeObserver(self)
     }
 }
 ```

 ## 6. Custom Server Loading

 ```swift
 class CustomHomeController: HomeController {

     override func loadServers() {
         // Override to load servers from your API
         fetchServersFromAPI { [weak self] servers in
             self?.countries = servers
             self?.selectedCountry = servers.first
             self?.updateUI(status: "Ready")
         }
     }

     func fetchServersFromAPI(completion: @escaping ([Country]) -> Void) {
         // Your API call here
         // For now, use dummy data
         completion(Country.getDummyServers())
     }
 }
 ```

 ## 7. Programmatic UI Setup

 ```swift
 class ProgrammaticHomeController: HomeController {

     let statusLabel = UILabel()
     let connectButton = UIButton(type: .system)
     let timerLabel = UILabel()

     override func viewDidLoad() {
         super.viewDidLoad()
         setupUI()
     }

     func setupUI() {
         view.backgroundColor = .systemBackground

         // Status Label
         statusLabel.text = "Disconnected"
         statusLabel.font = .systemFont(ofSize: 24, weight: .bold)
         statusLabel.textAlignment = .center
         view.addSubview(statusLabel)

         // Connect Button
         connectButton.setTitle("Connect", for: .normal)
         connectButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
         connectButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
         view.addSubview(connectButton)

         // Timer Label
         timerLabel.text = "00:00:00"
         timerLabel.font = .monospacedSystemFont(ofSize: 20, weight: .regular)
         timerLabel.textAlignment = .center
         view.addSubview(timerLabel)

         // Layout (add constraints or frames as needed)
     }

     override func updateUI(status: String) {
         super.updateUI(status: status)

         DispatchQueue.main.async {
             self.statusLabel.text = status

             switch self.vpnManager.connection.status {
             case .connected:
                 self.connectButton.setTitle("Disconnect", for: .normal)
             case .disconnected:
                 self.connectButton.setTitle("Connect", for: .normal)
             case .connecting:
                 self.connectButton.setTitle("Connecting...", for: .normal)
             default:
                 break
             }
         }
     }

     override func updateConnectionTime() {
         super.updateConnectionTime()

         guard let connectedDate = vpnManager.connection.connectedDate else { return }
         let duration = Date().timeIntervalSince(connectedDate)
         let hours = Int(duration) / 3600
         let minutes = (Int(duration) % 3600) / 60
         let seconds = Int(duration) % 60

         let timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

         DispatchQueue.main.async {
             self.timerLabel.text = timeString
         }
     }
 }
 ```

 ## Key Features:

 - ✅ Complete VPN connection management
 - ✅ Real-time status monitoring
 - ✅ Connection timer tracking
 - ✅ Server selection and switching
 - ✅ First-time configuration flow
 - ✅ Error handling and retry mechanism
 - ✅ Callback-based architecture
 - ✅ Easy to integrate with storyboards or programmatic UI

 ## Requirements:

 - iOS 12.0+
 - UIKit framework
 - NetworkExtension framework
 - Xcode Capabilities: Personal VPN, Keychain Sharing, Network Extensions

 */
