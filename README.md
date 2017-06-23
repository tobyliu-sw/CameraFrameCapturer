## CameraFrameCapturer

[CameraFrameCapturer](https://github.com/toby-liu-os/CameraFrameCapturer) is an iOS app which contains a swift class module CameraFrameCapturer.swift for capturing video frames from camera, converting the frames to UIImage images, and sent the images to delegate instances.

### System environment

1. macOS Sierra Version 10.12.5
2. Xcode Version 8.3.3 (installed from App Store)

### Tested devices

1. iPhone 7 plus with iOS 10.2

### Porting CameraFrameCapturer.swift to a new project

After copying CameraFrameCapturer.swift to a new project, you need add the key NSCameraUsageDescription with description in the app’s Info.plist.

Reference:
1. [Photo Capture Programming Guide](https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/PhotoCaptureGuide/)
2. [Technical Q&A QA1937 - Resolving the Privacy-Sensitive Data App Rejection](https://developer.apple.com/library/content/qa/qa1937/_index.html)

### Features

- Support switching front and back camera
- Support changing captured video frames quality
- Support changing device orientation

### Notes

- Because UI components could be only updated in main thread, please use DispatchQueue.main.async {} to update UI in the delegate function.
```
    func didCaptured(image: UIImage) {
        // UIImageView can only be updated in main thread
        DispatchQueue.main.async {
            self.imageView.image = image
        }
    }
```
