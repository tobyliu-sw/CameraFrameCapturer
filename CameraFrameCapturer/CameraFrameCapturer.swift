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


protocol CameraFrameCapturerDelegate {
    func didCaptured(image:UIImage)
}


class CameraFrameCapturer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // camera position
    var cameraPosition = AVCaptureDevicePosition.front

    // video quality
    var videoQuality = AVCaptureSessionPresetMedium

    // device orientation
    var deviceOrientation = UIDeviceOrientation.portrait

    // video orientation
    private var videoOrientation: AVCaptureVideoOrientation {
        guard var result = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue) else {
            return AVCaptureVideoOrientation.portrait
        }
        if deviceOrientation == UIDeviceOrientation.landscapeLeft {
            result = AVCaptureVideoOrientation.landscapeRight
        } else if deviceOrientation == UIDeviceOrientation.landscapeRight {
            result = AVCaptureVideoOrientation.landscapeLeft
        }
        return result;
    }


    // capturer delegate
    private var delegate: CameraFrameCapturerDelegate? = nil

    // AV session instance of managing the whole capturing session
    private let session = AVCaptureSession()

    // AV capture connection instance of managing buffer orientation and mirroring
    private var connection: AVCaptureConnection? = nil

    // configuration state of instance
    private var isConfigured = false

    private let context = CIContext()


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
    private func isPermissionGranted() -> Bool {
        var isGranted = false
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            isGranted = true

        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo,
                                          completionHandler: { success in isGranted = success })

        case .denied,
             .restricted:
            isGranted = false
        }
        return isGranted
    }


    // set the orientation of the captured video buffer
    private func setVideoOrientation() {
        if connection?.isVideoOrientationSupported ?? false {
            connection!.videoOrientation = videoOrientation
        }
    }


    // set the mirroring of the captured video buffer
    private func setVideoMirrored() {
        if connection?.isVideoMirroringSupported ?? false {
            connection!.isVideoMirrored = cameraPosition == .front
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

        // set video mirroring for front camera
        setVideoMirrored()

        return true
    }

    // set output device
    private func setSessionOutput() -> Bool {
        let captureOutput = AVCaptureVideoDataOutput()
        captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))

        if session.canAddOutput(captureOutput) {
            session.addOutput(captureOutput)

            connection = captureOutput.connection(withMediaType: AVFoundation.AVMediaTypeVideo)
            setVideoOrientation()
            setVideoMirrored()

            return true
        }

        return false
    }

    // configure capture device and session
    func configure() {
        if !isConfigured && isPermissionGranted() {
            guard setSessionInput() else {
                print("[Error] setSessionInput failed")
                return
            }

            guard setSessionOutput() else {
                print("[Error] setSessionOutput failed")
                return
            }

            // set the capturing quality
            session.sessionPreset = videoQuality

            print("[Info] configure done !")
            isConfigured = true
        }
    }

    // start capture session
    func start() {
        if !isConfigured {
            configure()
        }
        session.startRunning()
    }

    // stop capture session
    func stop() {
        session.stopRunning()
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
