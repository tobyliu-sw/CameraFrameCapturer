//
//  ViewController.swift
//  CameraFrameCapturer
//
//  Created by Pin-Chou Liu on 6/20/17.
//  Copyright © 2017 Pin-Chou Liu. All rights reserved.
//

import UIKit

class ViewController: UIViewController, CameraFrameCapturerDelegate {

    @IBOutlet weak var imageView: UIImageView!

    var cameraFrameCapturer: CameraFrameCapturer? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        cameraFrameCapturer = CameraFrameCapturer(withDelegate: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        cameraFrameCapturer?.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        cameraFrameCapturer?.stop()

        super.viewWillDisappear(animated)
    }

    func didCaptured(image: UIImage) {
        // UIImageView can only be updated in main thread
        DispatchQueue.main.async { [unowned self] in
            self.imageView.image = image
        }
    }

}

