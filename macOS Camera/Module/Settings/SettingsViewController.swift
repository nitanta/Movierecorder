//
//  SettingsViewController.swift
//  macOS Camera
//
//  Created by Nitanta Adhikari on 25/05/2022.
//  Copyright © 2022 Keyboarder Co. All rights reserved.
//

import Cocoa
import AVFoundation

protocol SettingsViewDelegate: AnyObject {
    func didChangeExposure(_ value: CGFloat)
    func autoExposure()
    
    func didChangeWhiteBalance(_ value: CGFloat)
    func autoWhiteBalance()
}


final class SettingsViewController: NSViewController {
    private var cameraManager: CameraManagerProtocol!
    var viewDelegate: SettingsViewDelegate!
    
    @IBAction func closeButton(_ sender: Any) {
        self.dismiss(nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
    }
    
    @IBAction func exposureSlider(_ sender: Any) {
        guard let slider = sender as? NSSlider else { return }
        viewDelegate.didChangeExposure(slider.altIncrementValue)
    }
    
    @IBAction func whiteBalanceRecording(_ sender: Any) {
        guard let slider = sender as? NSSlider else { return }
        viewDelegate.didChangeWhiteBalance(slider.altIncrementValue)
    }
    
}
