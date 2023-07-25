//
//  ViewController.swift
//  CamFilterApp
//
//  Created by Mikhayl Romanovsky on 2023/7/25.
//

import UIKit
import AVFoundation
import CoreImage

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    enum CameraFilter: String, CaseIterable {
        case effectNoir
        case normal
        case tonalEffect
        
        var filterName: String {
            switch self {
            case .effectNoir: return "CIPhotoEffectNoir"
            case .normal: return ""
            case .tonalEffect: return "CIPhotoEffectTonal"
            }
        }
        
        static func fromRawValue(_ value: String) -> CameraFilter? {
            for type in CameraFilter.allCases {
                if type.rawValue == value { return type }
            }
            return nil
        }
    }
    
    var session: AVCaptureSession?
    
    let context = CIContext()
    var filter: CIFilter?
    
    
    let imageView = UIImageView(image: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let items = CameraFilter.allCases.map { filterName in filterName.rawValue }
        let filterControl = UISegmentedControl(items: items)
        filterControl.selectedSegmentIndex = 1
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        view.addSubview(filterControl)
        let filterSegmentedControllHeight: CGFloat = 40
        let filterSegmentedControllInset:CGFloat = 20
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterControl.heightAnchor.constraint(equalToConstant: filterSegmentedControllHeight),
            filterControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -filterSegmentedControllInset),
            filterControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -filterSegmentedControllInset),
            filterControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: filterSegmentedControllInset)
        ])
        imageView.contentMode = .scaleAspectFill
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                self?.setupCamera()
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            setupCamera()
        @unknown default:
            break
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            self?.session?.stopRunning()
        }
    }
    
    @objc func filterChanged(_ sender: UISegmentedControl) {
        guard let filterName = CameraFilter.fromRawValue(sender.titleForSegment(at: sender.selectedSegmentIndex) ?? "")?.filterName else { return }
        filter = CIFilter(name: filterName)
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input) }
                
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                    guard let connection = videoOutput.connection(with: .video) else { return }
                    connection.videoOrientation = .portrait
                }
                
                session.commitConfiguration()
                
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
                self.session = session
            }
            catch {
                print(error)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        var finalImage: CIImage
        
        if let filter = filter {
            filter.setValue(image, forKey: kCIInputImageKey)
            guard let outputImage = filter.outputImage else { return }
            finalImage = outputImage
        } else {
            finalImage = image
        }
        
        guard let cgImage = context.createCGImage(finalImage, from: finalImage.extent) else { return }
        DispatchQueue.main.async { [weak self] in
            let outPutImage = UIImage(cgImage: cgImage)
            self?.imageView.image = outPutImage
        }
    }
}

