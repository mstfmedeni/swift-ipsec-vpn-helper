//
//  Model.swift
 //
//  Created by Mustafa Medeni
//  Copyright © 2016 Mustafa Medeni. All rights reserved.
//

import Foundation
import UIKit

class Country {
    var id: String
    var name: String
    var userName: String
    var ip: String
    var shared: String
    var pass: String
    var vpn: VPN

    init(id: String, name: String, userName: String, ip: String, shared: String, pass: String) {
        self.id = id
        self.name = name
        self.userName = userName
        self.ip = ip
        self.shared = shared
        self.pass = pass
        self.vpn = VPN(name: name, userName: userName, ip: ip, shared: shared, pass: pass)
        vpn.loadVPN()
    }
 
    // Dummy data for testing VPN connections
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
