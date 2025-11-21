//
//  VpnConfigrationController.swift
//  vpnOKAN
//
//  Created by Mustafa MEDENi on 2.11.2020.
//

import UIKit

class VpnConfigrationController: BaseController {
   

    var selectedCounty:Country?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    var dismissClosure: (()->())?
    @IBAction func tapAppend(){
        self.selectedCounty?.vpn.saveVPN({ (err) in
            if let err = err{
                print(err)
                 self.tapAppend()
                return
            }
            self.dismiss(animated: true)  { [weak self] in
                self?.dismissClosure?()
            }
        })

    }
    
 
}
