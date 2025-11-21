# Swift VPN Connection Package

This project is a comprehensive example of creating **IPSec VPN connections** in iOS applications using the NetworkExtension framework.

## 🚀 Ready-to-Use Code

**All code is consolidated in 2 main files:**
- 📱 **UIKit**: `forUse/UIKitControllers.swift` (All 3 controllers)
- 🎨 **SwiftUI**: `forUse/VPNSwiftUIViews.swift` (All 4 views + Manager)

**Core Files (Required for Both):**
- `KeychainHelper.swift` - Secure credential storage
- `vpnServer.swift` - VPN connection class
- `Country.swift` - Server model

Each file includes complete examples and documentation - just copy and use!

## ⚠️ Important Notice

**This implementation works ONLY with IPSec protocol. It does NOT work with IKEv2.**

### Required VPN Parameters

To configure a VPN connection, you only need **4 essential parameters**:

- **Username** (VPN username)
- **IP Address** (server address)
- **Shared Secret** (PSK - Pre-Shared Key)
- **Password** (user password)

All other fields in the Country model (id, name) are **optional** and used only for identification purposes.

## Features

- ✅ **IPSec protocol support** (⚠️ NOT IKEv2)
- ✅ Secure credential storage with iOS Keychain
- ✅ Multi-server architecture support
- ✅ Real-time VPN status monitoring
- ✅ On-demand VPN support
- ✅ **Consolidated codebase** - UIKit and SwiftUI in single files

## Requirements

- iOS 12.0+
- Xcode 11.0+
- Swift 5.0+
- NetworkExtension.framework

### Xcode Capabilities Required

1. **Personal VPN**
2. **Keychain Sharing**
3. **Network Extensions**

## Project Structure

```
vpnPacket/
├── KeychainHelper.swift              # Keychain data storage service
├── vpnServer.swift                   # Main VPN connection class
├── Country.swift                     # Server model
└── forUse/
    ├── UIKitControllers.swift        # All UIKit controllers in one file
    └── VPNSwiftUIViews.swift         # All SwiftUI views in one file
```

## Quick Start Guide

### 1. Choose Your UI Framework

**UIKit** or **SwiftUI**? Pick one and copy the corresponding file to your project:
- UIKit → `forUse/UIKitControllers.swift`
- SwiftUI → `forUse/VPNSwiftUIViews.swift`

### 2. Copy Core Files

Always copy these 3 files:
```
KeychainHelper.swift
vpnServer.swift
Country.swift
```

### 3. Configure Xcode

Enable these capabilities in your target:
1. Personal VPN
2. Keychain Sharing
3. Network Extensions

### 4. Info.plist Configuration

Add these keys to your `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 5. Start Coding

Use `HomeController()` for UIKit or `HomeView()` for SwiftUI in your app.

## VPN Server Setup

You need an IPSec VPN server to connect to. Set one up easily:

**Recommended**: [hwdsl2/setup-ipsec-vpn](https://github.com/hwdsl2/setup-ipsec-vpn)

**Quick Server Setup:**

```bash
# For Ubuntu/Debian
wget https://get.vpnsetup.net -O vpn.sh && sudo sh vpn.sh

# For CentOS/RHEL
yum -y install wget
wget https://get.vpnsetup.net -O vpn.sh && sudo sh vpn.sh
```

**Docker Alternative:**

```bash
docker run \
    --name ipsec-vpn-server \
    --restart=always \
    -v ikev2-vpn-data:/etc/ipsec.d \
    -v /lib/modules:/lib/modules:ro \
    -p 500:500/udp \
    -p 4500:4500/udp \
    -d --privileged \
    hwdsl2/ipsec-vpn-server
```

After installation, you'll receive:
- **Server IP Address** → Use in `Country.ip`
- **IPsec PSK (Shared Secret)** → Use in `Country.shared`
- **VPN Username** → Use in `Country.userName`
- **VPN Password** → Use in `Country.pass`

### 6. Configure VPN Credentials

Update `Country.swift` with your server details:

```swift
Country(
    id: "my-server",
    name: "My VPN Server",
    userName: "your-username",        // From VPN server setup
    ip: "your-server-ip",            // Your server's IP address
    shared: "your-shared-secret",    // IPsec PSK from setup
    pass: "your-password"            // VPN password from setup
)
```

**That's it! You're ready to go!** 🎉

## Core Components Overview

### 1. KeychainService
Securely stores VPN credentials (password and shared secret) in iOS Keychain.

```swift
let keychainService = KeychainService()
keychainService.save(key: "VPN_PASSWORD", value: "mySecurePassword")
keychainService.save(key: "SHARED", value: "mySharedSecret")
```

### 2. VPN Class
Manages IPSec VPN connections using NetworkExtension framework.

```swift
let vpn = VPN(
    name: "My Server",
    userName: "vpnuser",
    ip: "vpn.example.com",
    shared: "mySharedSecret",
    pass: "myPassword"
)

vpn.connectVPN()      // Connect
vpn.disconnectVPN()   // Disconnect
```

### 3. Country Model
Holds VPN server information and creates VPN instances.

```swift
let countries = Country.getDummyServers()
countries.first?.vpn.connectVPN()
```

### 4. UI Components

**UIKit** (`UIKitControllers.swift`):
- `HomeController` - Main screen with VPN controls
- `VpnConfigrationController` - First-time setup
- `SelectCountryController` - Server selection

**SwiftUI** (`VPNSwiftUIViews.swift`):
- `VPNManager` - Observable state management
- `HomeView`, `SelectCountryView`, `VPNConfigurationView`

## Usage Examples

### Basic VPN Connection

```swift
let vpn = VPN(
    name: "Test Server",
    userName: "testuser",
    ip: "vpn.example.com",
    shared: "mySharedSecret",
    pass: "myPassword"
)

vpn.connectVPN()
vpn.disconnectVPN()
```

### Multi-Server Setup

```swift
let servers = Country.getDummyServers()
selectedServer?.vpn.connectVPN()

// Switch servers
func switchServer(to newServer: Country) {
    selectedServer?.vpn.disconnectVPN()
    newServer.vpn.connectVPN()
}
```

### Monitoring VPN Status

Monitor connection status using `NEVPNStatusDidChange` notification:

```swift
@objc func vpnStatusChanged() {
    let status = NEVPNManager.shared().connection.status
    // Handle: .connected, .disconnected, .connecting, etc.
}
```

For SwiftUI, use `VPNManager` with `@StateObject` for automatic UI updates.

## Important Notes

### VPN Permissions
iOS requests permission when establishing VPN for the first time. This is system-controlled and cannot be bypassed.

### On-Demand VPN
Auto-connect on network changes:

```swift
let rule = NEOnDemandRuleConnect()
rule.interfaceTypeMatch = .any
vpnManager.onDemandRules = [rule]
vpnManager.isOnDemandEnabled = true
```

### Sleep Mode
Configure VPN behavior during device sleep:

```swift
protocol.disconnectOnSleep = false  // Stay connected
```

## Security Best Practices

1. **Keychain Usage**: Never store credentials in UserDefaults or plain text
2. **HTTPS**: Always use HTTPS for API communication
3. **No Hardcoding**: Never hardcode credentials in production
4. **Code Obfuscation**: Consider obfuscation before App Store release
5. **Certificate Pinning**: Implement for extra security

```swift
// ❌ WRONG - Hardcoded credentials
let vpn = VPN(name: "Server", userName: "user", ip: "vpn.com",
              shared: "hardcoded", pass: "hardcoded")

// ✅ CORRECT - Credentials from secure source
let servers = Country.getDummyServers()
servers.first?.vpn.connectVPN()
```

## File References

### Core Files
- **KeychainHelper.swift** - Keychain service implementation
- **vpnServer.swift** - Main VPN connection class
- **Country.swift** - Server model and dummy data

### UIKit Implementation
- **forUse/UIKitControllers.swift** - Complete UIKit implementation
  - `HomeController`, `VpnConfigrationController`, `SelectCountryController`

### SwiftUI Implementation
- **forUse/VPNSwiftUIViews.swift** - Complete SwiftUI implementation
  - `VPNManager`, `HomeView`, `SelectCountryView`, `VPNConfigurationView`

## License

This project was developed by Mustafa Medeni.
Copyright © 2018-2020 Mustafa Medeni. All rights reserved.

## Support

For questions or suggestions:
- Email: mustafa@medeni.dev
- GitHub: [swift-ipsec-vpn-helper](https://github.com/mstfmedeni/swift-ipsec-vpn-helper)

---

**Note**: This code example is for educational purposes. Make sure to perform security testing before using in production.
