//
//  CameraManager.swift
//  macOS Camera
//
//  Created by Mihail Șalari. on 16.05.2022.
//  Copyright © 2017 Mihail Șalari. All rights reserved.
//

import AVFoundation
import Cocoa

//enum Esposure {
//    case min, normal, max
//
//    func value(device: AVCaptureDevice) -> Float {
//        switch self {
//        case .min:
//            return device.activeFormat.minISO
//        case .normal:
//            return AVCaptureDevice.currentISO
//        case .max:
//            return device.activeFormat.maxISO
//        }
//    }
//}


enum CameraError: LocalizedError {
    case cannotDetectCameraDevice
    case cannotAddInput
    case previewLayerConnectionError
    case cannotAddOutput
    case videoSessionNil
    
    var localizedDescription: String {
        switch self {
        case .cannotDetectCameraDevice: return "Cannot detect camera device"
        case .cannotAddInput: return "Cannot add camera input"
        case .previewLayerConnectionError: return "Preview layer connection error"
        case .cannotAddOutput: return "Cannot add video output"
        case .videoSessionNil: return "Camera video session is nil"
        }
    }
}

enum CameraSettingError: LocalizedError {
    case failedToApply
    
    var localizedDescription: String {
        switch self {
        case .failedToApply: return "Failed to appy setting"
        }
    }
}


typealias CameraCaptureOutput = AVCaptureOutput
typealias CameraSampleBuffer = CMSampleBuffer
typealias CameraCaptureConnection = AVCaptureConnection

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ output: CameraCaptureOutput, didOutput sampleBuffer: CameraSampleBuffer, from connection: CameraCaptureConnection)
    func devicesList(_ list: [AVCaptureDevice])
}

protocol CameraManagerProtocol: AnyObject {
    var delegate: CameraManagerDelegate? { get set }
    
    func startSession() throws
    func stopSession() throws
    func startRecording()
    func stopRecording()

    
    func loadDevices()
    func changeDevice(_ device: AVCaptureDevice)
    
    func changeSetting(_ setting: CameraSetting) throws
}

protocol CameraSettingProtocol: AnyObject {
    func getCurrentSetting() -> CameraSetting
}

final class CameraManager: NSObject, CameraManagerProtocol, CameraSettingProtocol {
    
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var videoSession: AVCaptureSession!
    private var cameraDevice: AVCaptureDevice!
    private var movieOutput: AVCaptureMovieFileOutput!
    
    private let cameraQueue: DispatchQueue
    
    private let containerView: NSView
    
    weak var delegate: CameraManagerDelegate?
    
    struct Constants {
        static let kExposureDurationPower = 5.0 // Higher numbers will give the slider more sensitivity at shorter durations
        static let kExposureMinimumDuration = 1.0/1000 // Limit exposure duration to a useful range
    }
    
    init(containerView: NSView) throws {
        self.containerView = containerView
        cameraQueue = DispatchQueue(label: "sample buffer delegate", attributes: [])
        super.init()
    }
    
    deinit {
        previewLayer = nil
        videoSession = nil
        cameraDevice = nil
    }
    
}

// MARK: - Camera handler

extension CameraManager {
    func loadDevices() {
        let devices = AVCaptureDevice.devices()
        let videoDevices = devices.filter { $0.hasMediaType(.video) }
        delegate?.devicesList(videoDevices)
    }
    
    func changeDevice(_ device: AVCaptureDevice) {
        self.cameraDevice = device
        try? prepareCamera()
        try? startSession()
    }
    
    private func prepareCamera() throws {
        videoSession = AVCaptureSession()
        movieOutput = AVCaptureMovieFileOutput()
        videoSession.sessionPreset = AVCaptureSession.Preset.photo
        previewLayer = AVCaptureVideoPreviewLayer(session: videoSession)
        previewLayer.videoGravity = .resizeAspectFill
    
        
        if cameraDevice != nil  {
            do {
                let input = try AVCaptureDeviceInput(device: cameraDevice)
                if videoSession.canAddInput(input) {
                    videoSession.addInput(input)
                } else {
                    throw CameraError.cannotAddInput
                }
                
                if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = true
                } else {
                    throw CameraError.previewLayerConnectionError
                }
                
                previewLayer.frame = containerView.bounds
                containerView.layer = previewLayer
                containerView.wantsLayer = true
                
            } catch {
                throw CameraError.cannotDetectCameraDevice
            }
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        if videoSession.canAddOutput(videoOutput) {
            videoSession.addOutput(videoOutput)
            videoSession.addOutput(movieOutput)
        } else {
            throw CameraError.cannotAddOutput
        }
    }
    
    func startSession() throws {
        if let videoSession = videoSession {
            if !videoSession.isRunning {
                cameraQueue.async {
                    videoSession.startRunning()
                }
            }
        } else {
            throw CameraError.videoSessionNil
        }
    }
    
    func stopSession() throws {
        if let videoSession = videoSession {
            if videoSession.isRunning {
                cameraQueue.async {
                    videoSession.stopRunning()
                    self.movieOutput.stopRecording()
                }
            }
        } else {
            throw CameraError.videoSessionNil
        }
    }
    
    func startRecording(){
        movieOutput.startRecording(to: getOutputURL(), recordingDelegate: self as AVCaptureFileOutputRecordingDelegate)
    }
    
    func stopRecording(){
        movieOutput.stopRecording()
    }
  
    private func getOutputURL() -> URL{
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileName = UUID().uuidString
        let fileUrl = paths[0].appendingPathComponent("\(fileName).mov")
        try? FileManager.default.removeItem(at: fileUrl)
        return fileUrl
    }
}

// MARK: - Setting handler

extension CameraManager {
    
    func getCurrentSetting() -> CameraSetting {
        guard let device = cameraDevice else { return CameraSetting() }
        
        let isAutoExposure = device.exposureMode == .autoExpose
        let isAutoWhiteBalance = device.whiteBalanceMode == .autoWhiteBalance
        
        let exposureDurationSeconds = CMTimeGetSeconds(cameraDevice.exposureDuration ?? CMTime())
        let minExposureDurationSeconds = max(CMTimeGetSeconds(cameraDevice.activeFormat.minExposureDuration ?? CMTime()), Constants.kExposureMinimumDuration)
        let maxExposureDurationSeconds = CMTimeGetSeconds(cameraDevice.activeFormat.maxExposureDuration ?? CMTime())
        // Map from duration to non-linear UI range 0-1
        let p = (exposureDurationSeconds - minExposureDurationSeconds) / (maxExposureDurationSeconds - minExposureDurationSeconds) // Scale to 0-1
        
        let exposureValue = Float(pow(p, 1 / Constants.kExposureDurationPower))
        
        
        let whiteBalanceGains = cameraDevice.deviceWhiteBalanceGains ?? AVCaptureDevice.WhiteBalanceGains()
        let whiteBalanceTemperatureAndTint = cameraDevice.temperatureAndTintValues(for: whiteBalanceGains) ?? AVCaptureDevice.WhiteBalanceTemperatureAndTintValues()
        
        let whiteBalanceValue  = whiteBalanceTemperatureAndTint.temperature
        
        return CameraSetting(isAutoExposureEnabled: isAutoExposure, isAutoWhiteBalanceEnabled: isAutoWhiteBalance, exposureValue: CGFloat(exposureValue), whiteBalanceValue: CGFloat(whiteBalanceValue))
    }
    
    func changeSetting(_ setting: CameraSetting) throws {
        do {
            try cameraDevice.lockForConfiguration()
            
            if setting.isAutoExposureEnabled, cameraDevice.isExposureModeSupported(.autoExpose) {
                cameraDevice.exposureMode = .autoExpose
            } else {
                let p = pow(setting.exposureValue, Constants.kExposureDurationPower) // Apply power function to expand slider's low-end range
                let minDurationSeconds = max(CMTimeGetSeconds(cameraDevice.activeFormat.minExposureDuration), Constants.kExposureMinimumDuration)
                let maxDurationSeconds = CMTimeGetSeconds(cameraDevice.activeFormat.maxExposureDuration)
                let newDurationSeconds = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds; // Scale from 0-1 slider range to actual duration
                
                cameraDevice.setExposureModeCustom(duration: CMTimeMakeWithSeconds(newDurationSeconds, 1000*1000*1000), iso: AVCaptureDevice.currentISO, completionHandler: nil)
            }
            
            if setting.isAutoWhiteBalanceEnabled, cameraDevice.isWhiteBalanceModeSupported(.autoWhiteBalance) {
                cameraDevice.whiteBalanceMode = .autoWhiteBalance
            } else {
                let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(setting.whiteBalanceValue), tint: 0.0)
                let gains = cameraDevice.deviceWhiteBalanceGains(for: temperatureAndTint)
                let normalizedGains = self.normalizedGains(gains) // Conversion can yield out-of-bound values, cap to limits
                cameraDevice.setWhiteBalanceModeLocked(with: normalizedGains, completionHandler: nil)
            }
            
            cameraDevice.unlockForConfiguration()
        } catch {
            throw CameraSettingError.failedToApply
        }
    }
    
    private func normalizedGains(_ gains: AVCaptureDevice.WhiteBalanceGains) -> AVCaptureDevice.WhiteBalanceGains {
        var g = gains
        
        g.redGain = max(1.0, g.redGain)
        g.greenGain = max(1.0, g.greenGain)
        g.blueGain = max(1.0, g.blueGain)
        
        g.redGain = min(cameraDevice.maxWhiteBalanceGain, g.redGain)
        g.greenGain = min(cameraDevice.maxWhiteBalanceGain, g.greenGain)
        g.blueGain = min(cameraDevice.maxWhiteBalanceGain, g.blueGain)
        
        return g
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraManager(output, didOutput: sampleBuffer, from: connection)
    }
}
// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager:AVCaptureFileOutputRecordingDelegate{
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            debugPrint("capture output: finish recording to \(outputFileURL)")
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        debugPrint("capture output:started recording to \(fileURL)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didResumeRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        debugPrint("capture output:resumed recording to \(fileURL)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didPauseRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        debugPrint("capture output:started paused to \(fileURL)")
    }
}



