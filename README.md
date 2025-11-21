# Swift VPN Connection Package

This project is a comprehensive example of creating **IPSec VPN connections** in iOS applications using the NetworkExtension framework.

## ⚠️ Important Notice

**This implementation works ONLY with IPSec protocol. It does NOT work with IKEv2.**

### Required VPN Parameters

To configure a VPN connection, you only need **4 essential parameters**:

- **Username** (VPN username)
- **IP Address** (server address)
- **Shared Secret** (PSK - Pre-Shared Key)
- **Password** (user password)

All other fields in the Country model (id, name) are **optional** and used only for identification purposes.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Project Structure](#project-structure)
- [Core Components](#core-components)
  - [1. KeychainService - Secure Data Storage](#1-keychainservice---secure-data-storage)
  - [2. VPN Class - Main VPN Management](#2-vpn-class---main-vpn-management)
  - [3. Country Model - Server Management](#3-country-model---server-management)
  - [4. Controllers - User Interface](#4-controllers---user-interface)
- [Installation and Configuration](#installation-and-configuration)
- [Usage Examples](#usage-examples)
- [Monitoring VPN Status](#monitoring-vpn-status)
- [Important Notes](#important-notes)
- [Security](#security)

## Features

- ✅ **IPSec protocol support** (⚠️ NOT IKEv2)
- ✅ Shared Secret (PSK) and Password authentication
- ✅ Secure credential storage with iOS Keychain
- ✅ NetworkExtension framework integration
- ✅ Multi-server architecture support
- ✅ Automatic VPN connection management
- ✅ Real-time VPN status monitoring
- ✅ Premium/Free server differentiation (optional UI feature)
- ✅ On-demand VPN support

## Requirements

- iOS 12.0+
- Xcode 11.0+
- Swift 5.0+
- NetworkExtension.framework
- Network Extension capability (Xcode Capabilities)

### Xcode Capabilities

You need to enable the following capabilities in your project:

1. **Personal VPN** - For VPN configuration
2. **Keychain Sharing** - For storing credentials
3. **Network Extensions** - For using VPN protocols

## Project Structure

```
vpnPacket/
├── KeychainHelper.swift              # Keychain data storage service
├── vpnServer.swift              # Main VPN connection class
├── Country.swift                # Server model
└── forUse/
    ├── HomeController.swift            # Main screen and VPN control
    ├── VpnConfigrationController.swift # VPN initial setup screen
    └── SelectCountryController.swift   # Server selection screen
```

## Core Components

### 1. KeychainService - Secure Data Storage

The `KeychainService` class securely stores VPN credentials (password and shared secret) in the iOS Keychain.

#### Code Example:

```swift
import Foundation
import Security

class KeychainService: NSObject {

    // Save data to Keychain
    func save(key: String, value: String) {
        let keyData: Data = key.data(using: .utf8)!
        let valueData: Data = value.data(using: .utf8)!

        let keychainQuery = NSMutableDictionary()
        keychainQuery[kSecClass] = kSecClassGenericPassword
        keychainQuery[kSecAttrGeneric] = keyData
        keychainQuery[kSecAttrAccount] = keyData
        keychainQuery[kSecAttrService] = "VPN"
        keychainQuery[kSecAttrAccessible] = kSecAttrAccessibleAlwaysThisDeviceOnly
        keychainQuery[kSecValueData] = valueData

        // Delete existing item and add new one
        SecItemDelete(keychainQuery as CFDictionary)
        SecItemAdd(keychainQuery as CFDictionary, nil)
    }

    // Load data from Keychain
    func load(key: String) -> Data {
        let keyData: Data = key.data(using: .utf8)!

        let keychainQuery = NSMutableDictionary()
        keychainQuery[kSecClass] = kSecClassGenericPassword
        keychainQuery[kSecAttrGeneric] = keyData
        keychainQuery[kSecAttrAccount] = keyData
        keychainQuery[kSecAttrService] = "VPN"
        keychainQuery[kSecAttrAccessible] = kSecAttrAccessibleAlwaysThisDeviceOnly
        keychainQuery[kSecMatchLimit] = kSecMatchLimitOne
        keychainQuery[kSecReturnPersistentRef] = kCFBooleanTrue

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(keychainQuery, UnsafeMutablePointer($0))
        }

        if status == errSecSuccess {
            if let data = result as? NSData {
                return data as Data
            }
        }
        return "".data(using: .utf8)!
    }
}
```

#### Usage:

```swift
let keychainService = KeychainService()

// Save data
keychainService.save(key: "VPN_PASSWORD", value: "mySecurePassword")
keychainService.save(key: "SHARED", value: "mySharedSecret")

// Load data
let passwordData = keychainService.load(key: "VPN_PASSWORD")
let sharedSecretData = keychainService.load(key: "SHARED")
```

### 2. VPN Class - Main VPN Management

The `VPN` class configures and manages **IPSec VPN connections** using the NetworkExtension framework.

**⚠️ Protocol Note:** This implementation uses `NEVPNProtocolIPSec` which works only with IPSec. For IKEv2, you would need to use `NEVPNProtocolIKEv2` instead (not implemented in this project).

#### Code Example:

```swift
import Foundation
import NetworkExtension

class VPN {
    var userName: String
    var name: String
    var ip: String
    var shared: String
    var pass: String

    let vpnManager = NEVPNManager.shared()

    init(name: String, userName: String, ip: String, shared: String, pass: String) {
        self.userName = userName
        self.ip = ip
        self.shared = shared
        self.pass = pass
        self.name = name
    }

    // Connect to VPN
    public func connectVPN() {
        vpnManager.loadFromPreferences { (error) in
            if error != nil {
                print("Could not load VPN configuration: \(error!.localizedDescription)")
                return
            }

            // Configure IPSec protocol
            let p = NEVPNProtocolIPSec()
            p.username = self.userName
            p.serverAddress = self.ip
            p.authenticationMethod = NEVPNIKEAuthenticationMethod.sharedSecret

            // Load credentials from Keychain
            let kcs = KeychainService()
            kcs.save(key: "SHARED", value: self.shared)
            kcs.save(key: "VPN_PASSWORD", value: self.pass)
            p.sharedSecretReference = kcs.load(key: "SHARED")
            p.passwordReference = kcs.load(key: "VPN_PASSWORD")

            p.useExtendedAuthentication = true
            p.disconnectOnSleep = false

            self.vpnManager.protocolConfiguration = p
            self.vpnManager.localizedDescription = self.name
            self.vpnManager.isEnabled = true

            // Configure on-demand rules
            var rules = [NEOnDemandRule]()
            let rule = NEOnDemandRuleConnect()
            rule.interfaceTypeMatch = .any
            rules.append(rule)
            self.vpnManager.onDemandRules = rules

            // Save configuration and connect
            self.vpnManager.saveToPreferences { (error) in
                if error != nil {
                    print("Could not save VPN configuration: \(error!.localizedDescription)")
                    return
                }

                do {
                    try self.vpnManager.connection.startVPNTunnel()
                } catch let error {
                    print("Error starting VPN connection: \(error.localizedDescription)")
                }
            }
        }
    }

    // Save VPN settings (without connecting)
    public func saveVPN(_ completion: @escaping (Error?) -> Void) {
        vpnManager.loadFromPreferences { (error) in
            if error != nil {
                completion(error)
                return
            }

            let p = NEVPNProtocolIPSec()
            p.username = self.userName
            p.serverAddress = self.ip
            p.authenticationMethod = NEVPNIKEAuthenticationMethod.sharedSecret

            let kcs = KeychainService()
            kcs.save(key: "SHARED", value: self.shared)
            kcs.save(key: "VPN_PASSWORD", value: self.pass)
            p.sharedSecretReference = kcs.load(key: "SHARED")
            p.passwordReference = kcs.load(key: "VPN_PASSWORD")

            p.useExtendedAuthentication = true
            p.disconnectOnSleep = false

            self.vpnManager.protocolConfiguration = p
            self.vpnManager.localizedDescription = self.name
            self.vpnManager.isEnabled = true

            var rules = [NEOnDemandRule]()
            let rule = NEOnDemandRuleConnect()
            rule.interfaceTypeMatch = .any
            rules.append(rule)
            self.vpnManager.onDemandRules = rules

            self.vpnManager.saveToPreferences(completionHandler: completion)
        }
    }

    // Load VPN configuration
    public func loadVPN() {
        vpnManager.loadFromPreferences { (error) in
            if error != nil {
                print("Could not load VPN configuration")
                return
            }
            // Configuration loaded successfully
        }
    }

    // Disconnect from VPN
    public func disconnectVPN() {
        vpnManager.connection.stopVPNTunnel()
    }
}
```

#### Usage:

```swift
// Create VPN object
let vpn = VPN(
    name: "Turkey Server",
    userName: "vpnuser",
    ip: "vpn.server.com",
    shared: "sharedSecret123",
    pass: "password123"
)

// Connect to VPN
vpn.connectVPN()

// Disconnect from VPN
vpn.disconnectVPN()

// Save VPN settings (without connecting)
vpn.saveVPN { error in
    if let error = error {
        print("Error: \(error.localizedDescription)")
    } else {
        print("VPN settings saved successfully")
    }
}
```

### 3. Country Model - Server Management

The `Country` class holds VPN server information.

**⚠️ Required VPN Fields:** Only `userName`, `ip`, `shared`, and `pass` are needed for VPN functionality. Fields `id` and `name` are optional (for identification only). The `vpn` property is automatically created.

#### Code Example:

```swift
import Foundation

class Country {
    var id: String          // Optional - for identification
    var name: String        // Optional - for display
    var userName: String    // ✅ REQUIRED - VPN username
    var ip: String          // ✅ REQUIRED - Server IP/hostname
    var shared: String      // ✅ REQUIRED - Shared Secret (PSK)
    var pass: String        // ✅ REQUIRED - Password
    var vpn: VPN           // Automatically created VPN instance

    init(id: String, name: String, userName: String, ip: String, shared: String, pass: String) {
        self.id = id
        self.name = name
        self.userName = userName
        self.ip = ip
        self.shared = shared
        self.pass = pass

        // Create VPN object for this server
        self.vpn = VPN(name: name, userName: userName, ip: ip, shared: shared, pass: pass)
        vpn.loadVPN()
    }

    // Dummy data for testing
    static func getDummyServers() -> [Country] {
        return [
            Country(
                id: "turkey",
                name: "Turkey",
                userName: "vpnuser",
                ip: "tr.vpn.server.com",
                shared: "sharedSecret123",
                pass: "password123"
            ),
            Country(
                id: "usa",
                name: "United States",
                userName: "vpnuser",
                ip: "us.vpn.server.com",
                shared: "sharedSecret456",
                pass: "password456"
            ),
            Country(
                id: "germany",
                name: "Germany",
                userName: "vpnuser",
                ip: "de.vpn.server.com",
                shared: "sharedSecret789",
                pass: "password789"
            ),
            Country(
                id: "japan",
                name: "Japan",
                userName: "vpnuser",
                ip: "jp.vpn.server.com",
                shared: "sharedSecretABC",
                pass: "passwordABC"
            )
        ]
    }
}
```

#### Usage:

```swift
// Get dummy server list
let countries = Country.getDummyServers()

print("Found \(countries.count) servers")

for country in countries {
    print("\(country.name) - \(country.ip)")

    // Connect to desired server
    if country.name == "Turkey" {
        country.vpn.connectVPN()
    }
}
```

### 4. Controllers - User Interface

#### HomeController - Main Screen

The main screen manages VPN connections and monitors status changes.

**Key features:**

- VPN status monitoring via `NEVPNStatusDidChange` notification
- Connect/disconnect handling
- Server switching
- Connection duration timer

```swift
import UIKit
import NetworkExtension

class HomeController: UIViewController {

    let vpnManager = NEVPNManager.shared()
    var selectedCountry: Country?
    var timer = Timer()
    var countries: [Country] = []

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

    func loadServers() {
        countries = Country.getDummyServers()
        selectedCountry = countries.first
        print("Selected: \(selectedCountry?.name ?? "none")")
    }

    // Connect/disconnect button
    @IBAction func connectButtonTapped() {
        guard let country = selectedCountry else { return }

        switch vpnManager.connection.status {
        case .invalid:
            // First time - save configuration then connect
            country.vpn.saveVPN { error in
                if error == nil {
                    country.vpn.connectVPN()
                }
            }
        case .disconnected:
            country.vpn.connectVPN()
        case .connected:
            country.vpn.disconnectVPN()
        default:
            print("VPN is busy...")
        }
    }

    func switchServer(to newCountry: Country) {
        if vpnManager.connection.status == .connected {
            selectedCountry?.vpn.disconnectVPN()
        }
        selectedCountry = newCountry
        newCountry.vpn.connectVPN()
    }

    // Monitor VPN status
    @objc func vpnStatusChanged() {
        let status = vpnManager.connection.status

        switch status {
        case .connecting:
            print("Connecting...")
        case .connected:
            print("Connected")
            startConnectionTimer()
        case .disconnected:
            print("Disconnected")
            stopConnectionTimer()
        case .disconnecting:
            print("Disconnecting...")
        case .reasserting:
            print("Reconnecting...")
        default:
            break
        }
    }

    // Connection timer
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
        print("Connected: \(String(format: "%02d:%02d:%02d", hours, minutes, seconds))")
    }

    deinit {
        timer.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
```

#### VpnConfigrationController - Initial Setup

Used to request permission from the user when VPN is set up for the first time.

**Key features shown in VpnConfigrationController.swift:**

- First-time VPN profile creation
- User permission flow
- Error handling and retry mechanism

```swift
import UIKit

class VpnConfigrationController: UIViewController {

    var selectedCounty: Country?
    var dismissClosure: (() -> ())?

    // When "Allow" button is tapped
    @IBAction func tapAppend() {
        selectedCounty?.vpn.saveVPN { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                // Retry on error
                self.tapAppend()
                return
            }

            // Success, dismiss screen and connect to VPN
            self.dismiss(animated: true) {
                self.dismissClosure?()
            }
        }
    }
}
```

#### SelectCountryController - Server Selection

**Key features:**

- Display list of available servers
- Server selection handling
- Callback to parent controller

```swift
import UIKit

class SelectCountryController: UIViewController {

    var servers: [Country] = []
    var selectedServer: Country?
    var onServerSelected: ((Country) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        loadServers()
    }

    func loadServers() {
        servers = Country.getDummyServers()
        selectedServer = servers.first
        updateUI()
    }

    func updateUI() {
        print("Available servers:")
        for (index, server) in servers.enumerated() {
            let mark = server.id == selectedServer?.id ? "✓" : " "
            print("[\(mark)] \(index + 1). \(server.name) - \(server.ip)")
        }
    }

    func selectServer(at index: Int) {
        guard index >= 0 && index < servers.count else { return }

        let server = servers[index]
        selectedServer = server
        updateUI()
        print("Selected: \(server.name)")

        // Notify parent
        onServerSelected?(server)
    }

    func selectServerById(_ id: String) {
        guard let server = servers.first(where: { $0.id == id }) else { return }

        selectedServer = server
        updateUI()
        onServerSelected?(server)
    }

    @IBAction func confirmButtonTapped() {
        guard let server = selectedServer else { return }
        onServerSelected?(server)
        dismiss(animated: true, completion: nil)
    }
}
```

## Installation and Configuration

### 1. Xcode Capabilities Setup

Follow these steps in your project:

1. Open your project in Xcode
2. Select your target → Go to **Signing & Capabilities** tab
3. Click **+ Capability** button
4. Add these capabilities:
   - **Personal VPN**
   - **Keychain Sharing**
   - **Network Extensions**

### 2. Info.plist Configuration

Add these keys to your `Info.plist` file:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## Usage Examples

### Minimal VPN Connection (IPSec Only)

**Required parameters for VPN connection:**

```swift
// Only 4 parameters are required for VPN:
// 1. userName - VPN username
// 2. ip - Server IP address or hostname
// 3. shared - Shared Secret (PSK)
// 4. pass - User password

let vpn = VPN(
    name: "My VPN Server",        // Display name (optional)
    userName: "vpnuser",           // ✅ REQUIRED: VPN username
    ip: "vpn.example.com",         // ✅ REQUIRED: Server IP/hostname
    shared: "mySharedSecret",      // ✅ REQUIRED: Shared Secret (PSK)
    pass: "myPassword"             // ✅ REQUIRED: Password
)

// Connect to VPN
vpn.connectVPN()

// Disconnect from VPN
vpn.disconnectVPN()
```

### Simple VPN Connection

```swift
// 1. Create VPN object
let vpn = VPN(
    name: "Test Server",
    userName: "testuser",
    ip: "vpn.example.com",
    shared: "mySharedSecret",
    pass: "myPassword"
)

// 2. Connect
vpn.connectVPN()

// 3. Disconnect
vpn.disconnectVPN()
```

### Multi-Server Setup

```swift
class MyViewController: UIViewController {
    var servers: [Country] = []
    var selectedServer: Country?

    override func viewDidLoad() {
        super.viewDidLoad()
        loadServers()
    }

    func loadServers() {
        // Load available servers
        servers = Country.getDummyServers()

        // Select first server by default
        selectedServer = servers.first
    }

    func connectToSelectedServer() {
        guard let server = selectedServer else { return }

        // Connect to server
        server.vpn.connectVPN()
        print("Connecting to \(server.name)...")
    }

    func switchServer(to newServer: Country) {
        // Disconnect from current server
        selectedServer?.vpn.disconnectVPN()

        // Switch to new server
        selectedServer = newServer

        // Connect to new server
        newServer.vpn.connectVPN()
        print("Switched to \(newServer.name)")
    }
}
```

### Checking VPN Status

```swift
let vpnManager = NEVPNManager.shared()

// Current status
switch vpnManager.connection.status {
case .invalid:
    print("VPN not configured")
case .disconnected:
    print("Not connected")
case .connecting:
    print("Connecting...")
case .connected:
    print("Connected - Connection date: \(vpnManager.connection.connectedDate?.description ?? "")")
case .reasserting:
    print("Reconnecting...")
case .disconnecting:
    print("Disconnecting...")
@unknown default:
    print("Unknown state")
}
```

## Monitoring VPN Status

Use NotificationCenter to listen for VPN status changes in real-time:

```swift
class VPNMonitor {
    let vpnManager = NEVPNManager.shared()

    init() {
        setupNotifications()
    }

    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusChanged),
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )
    }

    @objc func vpnStatusChanged() {
        let status = vpnManager.connection.status

        switch status {
        case .connected:
            handleConnected()
        case .disconnected:
            handleDisconnected()
        case .connecting:
            handleConnecting()
        default:
            break
        }
    }

    func handleConnected() {
        print("VPN connected")
        // Connection time
        if let connectedDate = vpnManager.connection.connectedDate {
            print("Connected at: \(connectedDate)")
        }
    }

    func handleDisconnected() {
        print("VPN disconnected")
    }

    func handleConnecting() {
        print("VPN connecting...")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

## Important Notes

### 1. VPN Permissions

When establishing a VPN connection for the first time, iOS requests permission from the user. This permission screen is shown by the system and cannot be bypassed.

```swift
// Permission screen is shown when saveToPreferences is called for the first time
vpn.saveVPN { error in
    if let error = error {
        // If user denied permission or another error occurred
        print("Error: \(error.localizedDescription)")
    } else {
        // Permission granted, VPN configuration saved
        print("VPN configuration saved successfully")
    }
}
```

### 2. Connection During Sleep Mode

You can configure whether the VPN connection should disconnect when the device enters sleep mode:

```swift
let protocol = NEVPNProtocolIPSec()
protocol.disconnectOnSleep = false  // Stay connected during sleep
// or
protocol.disconnectOnSleep = true   // Disconnect during sleep
```

### 3. On-Demand VPN

To automatically connect to VPN based on specific rules:

```swift
// Auto-connect on all network connections
let rule = NEOnDemandRuleConnect()
rule.interfaceTypeMatch = .any

vpnManager.onDemandRules = [rule]
vpnManager.isOnDemandEnabled = true
```

```swift
// Auto-connect only on Wi-Fi
let wifiRule = NEOnDemandRuleConnect()
wifiRule.interfaceTypeMatch = .wiFi

vpnManager.onDemandRules = [wifiRule]
vpnManager.isOnDemandEnabled = true
```

### 4. Error Handling

Common errors you may encounter with VPN connections:

```swift
vpn.connectVPN()

// Listen for VPN status changes
@objc func vpnStatusChanged() {
    let status = vpnManager.connection.status

    if status == .disconnected {
        // Check for connection errors
        if let error = vpnManager.connection.manager.protocolConfiguration as? NEVPNProtocolIPSec {
            print("Connection lost")
            // Inform user or try to reconnect
        }
    }
}
```

### 5. Managing Multiple Servers

```swift
class VPNManager {
    var servers: [Country] = []
    var currentServer: Country?

    func switchToFastestServer() {
        // Find server with highest signal strength
        let fastest = servers.max(by: { $0.signal < $1.signal })

        if let fastest = fastest {
            currentServer?.vpn.disconnectVPN()
            fastest.vpn.connectVPN()
            currentServer = fastest
        }
    }

    func switchToFreeServer() {
        // Find free server
        let freeServer = servers.first(where: { $0.free })

        if let freeServer = freeServer {
            currentServer?.vpn.disconnectVPN()
            freeServer.vpn.connectVPN()
            currentServer = freeServer
        }
    }
}
```

## Security

### Important Security Notes:

1. **Keychain Usage**: Passwords and shared secrets should never be stored in UserDefaults or plain text files. Always use iOS Keychain.

2. **HTTPS Usage**: Always use HTTPS when communicating with your backend or APIs.

3. **Hardcoded Credentials**: Never hardcode credentials in production code. Fetch them from your secure backend service.

4. **Code Obfuscation**: Consider using code obfuscation before uploading your app to the App Store.

5. **Certificate Pinning**: Implement certificate pinning for extra security.

### Secure Code Example:

```swift
// ❌ WRONG - Hardcoded credentials in code
let vpn = VPN(
    name: "Server",
    userName: "user",
    ip: "vpn.server.com",
    shared: "hardcodedSecret",  // BAD!
    pass: "hardcodedPassword"   // BAD!
)

// ✅ CORRECT - Credentials from secure source
let servers = Country.getDummyServers()
if let server = servers.first {
    // Credentials should come from your backend/API
    server.vpn.connectVPN()
}
```

## File References

- **KeychainHelper.swift** - Keychain service implementation (lines 33-74)
- **vpnServer.swift:86-126** - Main VPN connection logic
- **vpnServer.swift:128-169** - VPN configuration save method
- **vpnServer.swift:182-184** - VPN disconnect method
- **Country.swift** - Server model and dummy data
- **HomeController.swift:328-374** - VPN status change handler
- **HomeController.swift:435-460** - VPN connection/disconnection handler
- **VpnConfigrationController.swift:56-68** - Initial VPN setup

## License

This project was developed by Mustafa Medeni.
Copyright © 2018-2020 Mustafa Medeni. All rights reserved.

## Support and Contact

For questions or suggestions, please use GitHub issues.

---

**Note**: This code example is for educational purposes. Make sure to perform security testing before using in production.
