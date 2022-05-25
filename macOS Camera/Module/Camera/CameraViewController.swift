//
//  ViewController.swift
//  macOS Camera
//
//  Created by Mihail Șalari. on 4/24/17.
//  Copyright © 2017 Mihail Șalari. All rights reserved.
//

import Cocoa
import AVFoundation

final class CameraViewController: NSViewController {
    private var cameraManager: CameraManagerProtocol!
    var datasource: [AVCaptureDevice] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        videoCaptureComboBox.delegate = self
        videoCaptureComboBox.dataSource = self
        
        do {
            cameraManager = try CameraManager(containerView: view)
            cameraManager.delegate = self
        } catch {
            print(error.localizedDescription)
        }
        cameraManager.loadDevices()
    }
    
    override var representedObject: Any? {
        didSet { }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        do {
            try cameraManager.stopSession()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    @IBAction func startRecording(_ sender: Any) {
        cameraManager.startRecording()
    }
    @IBAction func stopRecording(_ sender: Any) {
        cameraManager.stopRecording()
    }
    
    @IBOutlet weak var videoCaptureComboBox: NSComboBox!
    
    @IBAction func settingAction(_ sender: Any) {
        let storyBoard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        if let viewController = storyBoard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("SettingsViewController")) as? SettingsViewController {
            viewController.viewDelegate = self
            viewController.settingManager = cameraManager as! CameraSettingProtocol
            self.presentAsSheet(viewController)
        }
    }
}

extension CameraViewController: SettingsViewDelegate {
    func didChangeSetting(_ setting: CameraSetting) {
        try? cameraManager.changeSetting(setting)
    }
}

extension CameraViewController: CameraManagerDelegate {
    func devicesList(_ list: [AVCaptureDevice]) {
        self.datasource = list
        videoCaptureComboBox.reloadData()
    }
    
    func cameraManager(_ output: CameraCaptureOutput, didOutput sampleBuffer: CameraSampleBuffer, from connection: CameraCaptureConnection) {
        print(Date())
    }
    
}

extension CameraViewController: NSComboBoxDataSource, NSComboBoxDelegate {
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return datasource.count
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        let device = datasource[index]
        return device.localizedName
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        let comboBox = notification.object as! NSComboBox
        let selectedDevice = datasource[comboBox.indexOfSelectedItem]
        
        cameraManager.changeDevice(selectedDevice)
    }
    
}
