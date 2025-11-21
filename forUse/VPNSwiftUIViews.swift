//
//  VPNSwiftUIViews.swift
//  VPN IPSec SwiftUI Implementation
//
//  SwiftUI versions of UIKit controllers
//  Created from forUse directory files
//

import SwiftUI
import NetworkExtension
import Combine

// MARK: - VPN Manager (Observable Object)

/// Observable VPN Manager for SwiftUI
/// Manages VPN connections and monitors status changes in real-time
class VPNManager: ObservableObject {

    // MARK: - Published Properties

    @Published var connectionStatus: NEVPNStatus = .invalid
    @Published var connectionTime: String = "00:00:00"
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var selectedCountry: Country?
    @Published var countries: [Country] = []

    // MARK: - Private Properties

    private let vpnManager = NEVPNManager.shared()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupNotifications()
        loadServers()
        updateStatus()
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusChanged),
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )
    }

    func loadServers() {
        countries = Country.getDummyServers()
        selectedCountry = countries.first
        print("Loaded \(countries.count) servers")
    }

    // MARK: - VPN Connection Methods

    /// Connect to VPN with selected country
    func connect() {
        guard let country = selectedCountry else {
            print("No country selected")
            return
        }

        let status = vpnManager.connection.status

        switch status {
        case .invalid:
            // First time setup
            country.vpn.saveVPN { [weak self] error in
                if let error = error {
                    print("Error saving VPN: \(error.localizedDescription)")
                    return
                }
                country.vpn.connectVPN()
            }

        case .disconnected:
            country.vpn.connectVPN()
            print("Connecting to \(country.name)...")

        case .connected:
            disconnect()

        default:
            print("VPN is busy...")
        }
    }

    /// Disconnect from VPN
    func disconnect() {
        selectedCountry?.vpn.disconnectVPN()
        print("Disconnecting...")
    }

    /// Switch to a different server
    func switchServer(to country: Country) {
        if vpnManager.connection.status == .connected {
            disconnect()
        }

        selectedCountry = country
        print("Switched to \(country.name)")

        // Auto-connect to new server
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.connect()
        }
    }

    // MARK: - Status Monitoring

    @objc private func vpnStatusChanged() {
        updateStatus()
    }

    private func updateStatus() {
        let status = vpnManager.connection.status

        DispatchQueue.main.async {
            self.connectionStatus = status
            self.isConnected = status == .connected
            self.isConnecting = status == .connecting || status == .reasserting

            switch status {
            case .connecting:
                print("Status: Connecting...")
            case .connected:
                print("Status: Connected")
                self.startConnectionTimer()
            case .disconnecting:
                print("Status: Disconnecting...")
            case .disconnected:
                print("Status: Disconnected")
                self.stopConnectionTimer()
            case .invalid:
                print("Status: Not configured")
            case .reasserting:
                print("Status: Reconnecting...")
            @unknown default:
                print("Status: Unknown")
            }
        }
    }

    // MARK: - Connection Timer

    private func startConnectionTimer() {
        stopConnectionTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateConnectionTime()
        }
    }

    private func stopConnectionTimer() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async {
            self.connectionTime = "00:00:00"
        }
    }

    private func updateConnectionTime() {
        guard let connectedDate = vpnManager.connection.connectedDate else { return }

        let duration = Date().timeIntervalSince(connectedDate)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        DispatchQueue.main.async {
            self.connectionTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }

    // MARK: - Helper Methods

    var statusText: String {
        switch connectionStatus {
        case .invalid: return "Not Configured"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reasserting: return "Reconnecting..."
        case .disconnecting: return "Disconnecting..."
        @unknown default: return "Unknown"
        }
    }

    var buttonTitle: String {
        if isConnected {
            return "Disconnect"
        } else if isConnecting {
            return "Connecting..."
        } else {
            return "Connect"
        }
    }
}

// MARK: - Home View (Main VPN Screen)

/// Main VPN connection screen
/// SwiftUI version of HomeController
struct HomeView: View {

    @StateObject private var vpnManager = VPNManager()
    @State private var showServerSelection = false
    @State private var showConfiguration = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {

                    Spacer()

                    // Status Icon
                    statusIcon

                    // Connection Status
                    Text(vpnManager.statusText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    // Connection Time (when connected)
                    if vpnManager.isConnected {
                        Text(vpnManager.connectionTime)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Selected Server Card
                    selectedServerCard

                    // Connect/Disconnect Button
                    connectButton

                    // Change Server Button
                    Button(action: {
                        showServerSelection = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Change Server")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("VPN")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showServerSelection) {
                SelectCountryView(
                    vpnManager: vpnManager,
                    isPresented: $showServerSelection
                )
            }
            .sheet(isPresented: $showConfiguration) {
                VPNConfigurationView(
                    vpnManager: vpnManager,
                    isPresented: $showConfiguration
                )
            }
        }
    }

    // MARK: - View Components

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(vpnManager.isConnected ? Color.green : Color.gray)
                .frame(width: 120, height: 120)
                .shadow(color: vpnManager.isConnected ? .green.opacity(0.5) : .clear, radius: 20)

            Image(systemName: vpnManager.isConnected ? "lock.shield.fill" : "lock.shield")
                .font(.system(size: 50))
                .foregroundColor(.white)
        }
        .scaleEffect(vpnManager.isConnecting ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: vpnManager.isConnecting)
    }

    private var selectedServerCard: some View {
        VStack(spacing: 10) {
            if let country = vpnManager.selectedCountry {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(country.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(country.ip)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(15)
                .padding(.horizontal, 40)
            }
        }
    }

    private var connectButton: some View {
        Button(action: {
            if vpnManager.connectionStatus == .invalid {
                showConfiguration = true
            } else {
                vpnManager.connect()
            }
        }) {
            Text(vpnManager.buttonTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 200, height: 60)
                .background(
                    vpnManager.isConnected ? Color.red : Color.green
                )
                .cornerRadius(30)
                .shadow(radius: 10)
        }
        .disabled(vpnManager.isConnecting)
    }
}

// MARK: - Select Country View (Server Selection)

/// Server selection screen
/// SwiftUI version of SelectCountryController
struct SelectCountryView: View {

    @ObservedObject var vpnManager: VPNManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                ForEach(vpnManager.countries, id: \.id) { country in
                    serverRow(for: country)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectServer(country)
                        }
                }
            }
            .navigationTitle("Select Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    // MARK: - View Components

    private func serverRow(for country: Country) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(country.name)
                    .font(.headline)

                Text(country.ip)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("User: \(country.userName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if country.id == vpnManager.selectedCountry?.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func selectServer(_ country: Country) {
        vpnManager.switchServer(to: country)

        // Close after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// MARK: - VPN Configuration View (Initial Setup)

/// Initial VPN configuration screen
/// SwiftUI version of VpnConfigrationController
struct VPNConfigurationView: View {

    @ObservedObject var vpnManager: VPNManager
    @Binding var isPresented: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 30) {

                    Spacer()

                    // Icon
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    // Title
                    Text("VPN Configuration")
                        .font(.title)
                        .fontWeight(.bold)

                    // Description
                    Text("Allow this app to add VPN configurations to your device")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()

                    // Server Info
                    if let country = vpnManager.selectedCountry {
                        VStack(spacing: 10) {
                            InfoRow(label: "Server", value: country.name)
                            InfoRow(label: "IP Address", value: country.ip)
                            InfoRow(label: "Username", value: country.userName)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(15)
                        .padding(.horizontal, 40)
                    }

                    Spacer()

                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 40)
                    }

                    // Allow Button
                    Button(action: {
                        configureVPN()
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 200, height: 50)
                        } else {
                            Text("Allow")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(25)
                    .disabled(isLoading)

                    // Cancel Button
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)

                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Actions

    private func configureVPN() {
        guard let country = vpnManager.selectedCountry else { return }

        isLoading = true
        errorMessage = nil

        country.vpn.saveVPN { error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = error.localizedDescription
                    print("Configuration error: \(error.localizedDescription)")

                    // Retry after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        configureVPN()
                    }
                } else {
                    print("VPN configured successfully")

                    // Close and connect
                    isPresented = false

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        vpnManager.connect()
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview Providers

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

struct SelectCountryView_Previews: PreviewProvider {
    static var previews: some View {
        SelectCountryView(
            vpnManager: VPNManager(),
            isPresented: .constant(true)
        )
    }
}

struct VPNConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        VPNConfigurationView(
            vpnManager: VPNManager(),
            isPresented: .constant(true)
        )
    }
}

// MARK: - Usage Examples

/*

 # SwiftUI VPN Implementation - Usage Examples

 ## 1. Basic Usage - Show Home View

 ```swift
 import SwiftUI

 @main
 struct VPNApp: App {
     var body: some Scene {
         WindowGroup {
             HomeView()
         }
     }
 }
 ```

 ## 2. Using VPNManager Standalone

 ```swift
 import SwiftUI

 struct ContentView: View {
     @StateObject private var vpnManager = VPNManager()

     var body: some View {
         VStack {
             Text("Status: \(vpnManager.statusText)")

             if let country = vpnManager.selectedCountry {
                 Text("Server: \(country.name)")
             }

             Button(vpnManager.buttonTitle) {
                 vpnManager.connect()
             }
         }
     }
 }
 ```

 ## 3. Custom Server List

 ```swift
 struct ServerListView: View {
     @StateObject private var vpnManager = VPNManager()

     var body: some View {
         List(vpnManager.countries, id: \.id) { country in
             HStack {
                 Text(country.name)
                 Spacer()
                 Button("Connect") {
                     vpnManager.switchServer(to: country)
                 }
             }
         }
     }
 }
 ```

 ## 4. Monitoring VPN Status

 ```swift
 struct StatusMonitorView: View {
     @StateObject private var vpnManager = VPNManager()

     var body: some View {
         VStack(spacing: 20) {
             // Real-time status
             Text(vpnManager.statusText)
                 .font(.title)

             // Connected indicator
             Circle()
                 .fill(vpnManager.isConnected ? Color.green : Color.red)
                 .frame(width: 50, height: 50)

             // Connection time
             if vpnManager.isConnected {
                 Text(vpnManager.connectionTime)
                     .font(.system(.title, design: .monospaced))
             }

             // Quick actions
             HStack {
                 Button("Connect") {
                     vpnManager.connect()
                 }
                 .disabled(vpnManager.isConnected)

                 Button("Disconnect") {
                     vpnManager.disconnect()
                 }
                 .disabled(!vpnManager.isConnected)
             }
         }
     }
 }
 ```

 ## 5. Advanced - Custom VPN Manager

 ```swift
 class CustomVPNManager: VPNManager {

     @Published var isFastServer: Bool = false

     // Override to add custom behavior
     override func connect() {
         print("Custom connect logic")

         // Add analytics or logging
         trackConnectionAttempt()

         // Call parent implementation
         super.connect()
     }

     func trackConnectionAttempt() {
         // Your analytics code
         print("Tracking connection to \(selectedCountry?.name ?? "unknown")")
     }

     func connectToFastest() {
         // Your logic to find fastest server
         if let fastest = countries.first {
            switchServer(to: fastest)
         }
     }
 }
 ```

 ## 6. Integration with TabView

 ```swift
 struct MainTabView: View {
     var body: some View {
         TabView {
             HomeView()
                 .tabItem {
                     Label("VPN", systemImage: "lock.shield")
                 }

             SettingsView()
                 .tabItem {
                     Label("Settings", systemImage: "gear")
                 }
         }
     }
 }
 ```

 ## 7. Widget Integration Example

 ```swift
 struct VPNStatusWidget: View {
     @StateObject private var vpnManager = VPNManager()

     var body: some View {
         VStack {
             Image(systemName: vpnManager.isConnected ? "lock.shield.fill" : "lock.shield")
                 .foregroundColor(vpnManager.isConnected ? .green : .gray)

             Text(vpnManager.statusText)
                 .font(.caption)
         }
         .padding()
         .background(Color(.systemBackground))
         .cornerRadius(10)
     }
 }
 ```

 ## Key Features:

 - ✅ Fully reactive with @Published properties
 - ✅ Real-time VPN status monitoring
 - ✅ Connection timer tracking
 - ✅ Server switching support
 - ✅ Easy to integrate with any SwiftUI app
 - ✅ Built-in error handling
 - ✅ Automatic UI updates

 ## Requirements:

 - iOS 14.0+ (for @StateObject)
 - NetworkExtension framework
 - Xcode Capabilities: Personal VPN, Keychain Sharing, Network Extensions

 */
