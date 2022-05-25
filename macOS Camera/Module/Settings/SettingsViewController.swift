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
    func didChangeSetting(_ setting: CameraSetting)
}

struct CameraSetting {
    var isAutoExposureEnabled: Bool = false
    var isAutoWhiteBalanceEnabled: Bool = false
    var exposureValue: CGFloat = 0
    var whiteBalanceValue: CGFloat = 0
}

final class SettingsViewController: NSViewController {
    var settingManager: CameraSettingProtocol!
    var viewDelegate: SettingsViewDelegate!
    
    var setting: CameraSetting!
    
    @IBOutlet weak var exposureSlider: NSSlider!
    @IBOutlet weak var whiteBalanceSlider: NSSlider!
    
    @IBOutlet weak var exposureButton: NSButton!
    @IBOutlet weak var whiteBalanceButton: NSButton!
    
    @IBAction func closeButton(_ sender: Any) {
        self.dismiss(nil)
    }
    
    @IBAction func applyTapped(_ sender: Any) {
        viewDelegate.didChangeSetting(setting)
        self.dismiss(nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setting = settingManager.getCurrentSetting()
        setupUI(setting: setting)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
    }
    
    func setupUI(setting: CameraSetting) {
        exposureSlider.isEnabled = !setting.isAutoExposureEnabled
        exposureSlider.doubleValue = setting.exposureValue
        
        whiteBalanceSlider.isEnabled = !setting.isAutoWhiteBalanceEnabled
        whiteBalanceSlider.doubleValue = setting.whiteBalanceValue

        exposureButton.state = setting.isAutoExposureEnabled ? .on : .off
        whiteBalanceButton.state = setting.isAutoWhiteBalanceEnabled ? .on : .off
    }
    
    @IBAction func autoExposureCheckbox(_ sender: Any) {
        guard let button = sender as? NSButton else { return }
        setting.isAutoExposureEnabled =  (button.state == .on) ? true : false
        setupUI(setting: setting)
    }
    
    @IBAction func exposureSlider(_ sender: Any) {
        guard let slider = sender as? NSSlider else { return }
        setting.exposureValue = slider.doubleValue
        setupUI(setting: setting)
    }
    
    @IBAction func autoWhiteBalanceCheckbox(_ sender: Any) {
        guard let button = sender as? NSButton else { return }
        setting.isAutoWhiteBalanceEnabled = (button.state == .on) ? true : false
        setupUI(setting: setting)
    }
    
    @IBAction func whiteBalanceSlider(_ sender: Any) {
        guard let slider = sender as? NSSlider else { return }
        setting.whiteBalanceValue = slider.doubleValue
        setupUI(setting: setting)
    }
    
}
