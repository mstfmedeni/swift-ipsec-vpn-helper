//
//  vpnServer.swift
 //
//  Created by Mustafa Medeni  
//  Copyright © 2018 Mustafa MEDENi. All rights reserved.
//


import Foundation

import NetworkExtension

class VPN {

    var userName,name,ip,shared,pass:String


    init(name:String,userName:String,ip:String,shared:String,pass:String) {
        self.userName = userName
        self.ip = ip
        self.shared = shared
        self.pass = pass
        self.name = name
    }

    var vpnlock = false
    let vpnManager = NEVPNManager.shared();


    private var vpnLoadHandler: (Error?) -> Void { return
    { (error:Error?) in
        if ((error) != nil) {
            print("Could not load VPN Configurations")
            return;
        }
        let p = NEVPNProtocolIPSec()
        p.username = self.userName
        p.serverAddress = self.ip
        p.authenticationMethod = NEVPNIKEAuthenticationMethod.sharedSecret




        let kcs = KeychainService();
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
       // self.vpnManager.isOnDemandEnabled = true


        }

    }

    private var vpnSaveHandler: (Error?) -> Void { return
    { (error:Error?) in
        if (error != nil) {
            print("Could not save VPN Configurations")
            return
        } else {
            do {
                try self.vpnManager.connection.startVPNTunnel()
            } catch let error {
                print("Error starting VPN Connection \(error.localizedDescription)");
            }
        }
        }
        self.vpnlock = false
    }

    public func connectVPN() {
        //For no known reason the process of saving/loading the VPN configurations fails.On the 2nd time it works

        self.vpnManager.loadFromPreferences { (error) in
            if ((error) != nil) {
                print("Could not load VPN Configurations")
                return;
            }
            let p = NEVPNProtocolIPSec()
            p.username = self.userName
            p.serverAddress = self.ip
            p.authenticationMethod = NEVPNIKEAuthenticationMethod.sharedSecret




            let kcs = KeychainService();
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
            // self.vpnManager.isOnDemandEnabled = true

            self.vpnManager.saveToPreferences(completionHandler: self.vpnSaveHandler)

        }
    }

        public func saveVPN(_ completion: @escaping (Error?) -> Void) {
            //For no known reason the process of saving/loading the VPN configurations fails.On the 2nd time it works

            self.vpnManager.loadFromPreferences { (error) in
                if ((error) != nil) {
                    print("Could not load VPN Configurations")
                    completion(error)
                    return;
                }
                let p = NEVPNProtocolIPSec()
                p.username = self.userName
                p.serverAddress = self.ip
                p.authenticationMethod = NEVPNIKEAuthenticationMethod.sharedSecret




                let kcs = KeychainService();
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
                // self.vpnManager.isOnDemandEnabled = true

                self.vpnManager.saveToPreferences(completionHandler: completion)

            }
        }



    public func loadVPN() {
        //For no known reason the process of saving/loading the VPN configurations fails.On the 2nd time it works

        self.vpnManager.loadFromPreferences(completionHandler: self.vpnLoadHandler)

    }



    public func disconnectVPN() {
        vpnManager.connection.stopVPNTunnel()
    }
}

