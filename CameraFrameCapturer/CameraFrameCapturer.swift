//
//  CameraFrameCapturer.swift
//  CameraFrameCapturer
//
//  Created by Pin-Chou Liu on 6/20/17.
//  Copyright © 2017 Pin-Chou Liu.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import UIKit
import AVFoundation


protocol CameraFrameCapturerDelegate: class {
    func didCaptured(image:UIImage)
}


class CameraFrameCapturer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // camera position
    var cameraPosition = AVCaptureDevicePosition.front {
        didSet {
            sessionQueue.async {
                guard self.isConfigured else { return }

                let sessionIsRunning = self.session.isRunning
                if sessionIsRunning {
                    self.session.stopRunning()
                }

                guard self.setSessionInput() else {
                    print("[Error] setSessionInput failed")
                    return
                }

                self.setVideoOrientation()
                self.setVideoMirrored()

                if sessionIsRunning {
                    self.session.startRunning()
                }
            }
        }
    }

    // video quality
    var videoQuality = AVCaptureSessionPreset640x480 {
        didSet {
            sessionQueue.async {
                guard self.isConfigured else { return }

                self.session.beginConfiguration()
                self.session.sessionPreset = self.videoQuality
                self.session.commitConfiguration()
            }
        }
    }

    // device orientation
    var deviceOrientation = UIDeviceOrientation.portrait {
        didSet {
            guard (deviceOrientation != oldValue) else { return }

            switch deviceOrientation {
            case .portrait,
                 .portraitUpsideDown,
                 .landscapeLeft,
                 .landscapeRight:
                sessionQueue.async {
                    guard self.isConfigured else { return }

                    let sessionIsRunning = self.session.isRunning
                    if sessionIsRunning {
                        self.session.stopRunning()
                    }

                    self.setVideoOrientation()

                    if sessionIsRunning {
                        self.session.startRunning()
                    }
                }
            default:
                deviceOrientation = oldValue
                break
            }
        }
    }

    // video orientation
    private var videoOrientation: AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .portrait:
            return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft:
            return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight:
            return AVCaptureVideoOrientation.landscapeLeft
        default:
            print("[WARN] unsupported deviceOrientation: \(deviceOrientation.rawValue)")
            return AVCaptureVideoOrientation.portrait
        }
    }


    // capturer delegate (set to weak to avoid Strong Reference Cycle)
    weak private var delegate: CameraFrameCapturerDelegate? = nil

    // AV capture session instance of managing the whole capturing session
    private let session = AVCaptureSession()

    // Asynchronous queue to process AV capture session configuration and operations
    private let sessionQueue = DispatchQueue(label: "SessionQueue")

    // AV capture output instance for managing orientation and mirroring of video frames
    private var captureOutput: AVCaptureVideoDataOutput? = nil

    // configuration state of instance
    private var isConfigured = false

    // configuration state of instance
    private var isAuthorized = false


    // convenience initializer
    convenience init(withDelegate delegate: CameraFrameCapturerDelegate?) {
        self.init()
        self.delegate = delegate
    }


    // convenience initializer
    convenience init(cameraPosition: AVCaptureDevicePosition,
                     videoQuality: String,
                     deviceOrientation: UIDeviceOrientation,
                     withDelegate delegate: CameraFrameCapturerDelegate?) {
        self.init(withDelegate: delegate)
        self.cameraPosition = cameraPosition
        self.videoQuality = videoQuality
        self.deviceOrientation = deviceOrientation
    }


    // check the permission for accessing camera
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            isAuthorized = true

        case .notDetermined:
            // stop session queue from executing configuring operation
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { success in
                self.isAuthorized = success
                // resume session queue to execute configuring operation
                self.sessionQueue.resume()
            })

        case .denied,
             .restricted:
            isAuthorized = false

        }
    }


    // set the orientation of the captured video buffer
    private func setVideoOrientation() {
        if let connection = captureOutput?.connection(withMediaType: AVFoundation.AVMediaTypeVideo) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
        }
    }


    // set the mirroring of the captured video buffer
    private func setVideoMirrored() {
        if let connection = captureOutput?.connection(withMediaType: AVFoundation.AVMediaTypeVideo) {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = cameraPosition == .front
            }
        }
    }


    // set input device
    private func setSessionInput() -> Bool {

        // discover the video capture device which matches the camera position
        func discoverCaptureDevice() -> AVCaptureDevice? {
            if let devices = AVCaptureDevice.devices(withMediaType:AVMediaTypeVideo) {
                for device in devices {
                    if let captureDevice = device as? AVCaptureDevice  {
                        if captureDevice.position == cameraPosition {
                            return captureDevice
                        }
                    }
                }
            }
            return nil
        }

        guard let newCaptureDevice = discoverCaptureDevice() else {
            print("[Error] discoverCaptureDevice failed")
            return false
        }

        guard let newCaptureInput = try? AVCaptureDeviceInput(device: newCaptureDevice) else {
            print("[Error] init AVCaptureDeviceInput failed")
            return false
        }

        // modify session configuration
        session.beginConfiguration()

        if let currentInputs = session.inputs {
            for input in currentInputs {
                if let captureInput = input as? AVCaptureInput {
                    session.removeInput(captureInput)
                }
            }
        }

        if session.canAddInput(newCaptureInput) {
            session.addInput(newCaptureInput)
        }

        session.commitConfiguration()

        return true
    }

    // set output device
    private func setSessionOutput() -> Bool {
        captureOutput = AVCaptureVideoDataOutput()
        captureOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))

        if session.canAddOutput(captureOutput!) {
            session.addOutput(captureOutput!)

            setVideoOrientation()
            setVideoMirrored()

            return true
        }

        return false
    }

    // configure capture device and session
    func configure() {
        sessionQueue.async {
            guard !self.isConfigured else { return }

            self.checkPermission()
        }

        sessionQueue.async {
            guard !self.isConfigured else { return }

            guard self.isAuthorized else {
                print("[Error] permission denied")
                return
            }

            guard self.setSessionInput() else {
                print("[Error] setSessionInput failed")
                return
            }

            guard self.setSessionOutput() else {
                print("[Error] setSessionOutput failed")
                return
            }

            // set the capturing quality
            self.session.sessionPreset = self.videoQuality

            self.isConfigured = true
            print("[Info] configure done !")
        }
    }

    // start capture session
    func start() {
        sessionQueue.async {
            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    // stop capture session
    func stop() {
        sessionQueue.async {
            if self.isConfigured && self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // AVCaptureVideoDataOutputSampleBufferDelegate delegate function
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        // convert sample buffer to UIImage
        func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return nil
            }
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            return UIImage(ciImage: ciImage)
        }

        // send image to delegate function
        if let uiImage = imageFromSampleBuffer(sampleBuffer) {
            delegate?.didCaptured(image: uiImage)
        }
    }
}
