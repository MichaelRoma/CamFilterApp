//
//  ViewController.swift
//  CamFilterApp
//
//  Created by Mikhayl Romanovsky on 2023/7/25.
//

import UIKit
import AVFoundation
import CoreImage

final class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private enum CameraFilter: String, CaseIterable {
        case colorInvert
        case normal
        case tonalEffect
        
        var filterName: String {
            switch self {
            case .colorInvert: return "CIColorInvert"
            case .normal: return ""
            case .tonalEffect: return "CIPhotoEffectTonal"
            }
        }
    }
   
    private let ciContext = CIContext()
    private let imageView = UIImageView()
    
    private var captureSession: AVCaptureSession?
    private var currentFilter: CIFilter?
   
    override func viewDidLoad() {
        super.viewDidLoad()
        let items = CameraFilter.allCases.map { filterName in filterName.rawValue }
        let filterControl = UISegmentedControl(items: items)
        filterControl.selectedSegmentIndex = 1
        filterControl.addTarget(self, action: #selector(onFilterSelectionChanged), for: .valueChanged)
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
                self?.configureCaptureSession()
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            configureCaptureSession()
        @unknown default:
            break
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    @objc private func onFilterSelectionChanged(_ sender: UISegmentedControl) {
        let title = sender.titleForSegment(at: sender.selectedSegmentIndex) ?? ""
        guard let filterName = CameraFilter(rawValue: title)?.filterName else { return }
        currentFilter = CIFilter(name: filterName)
    }
    
    private func configureCaptureSession() {
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
                self.captureSession = session
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
        
        if let filter = currentFilter {
            filter.setValue(image, forKey: kCIInputImageKey)
            guard let outputImage = filter.outputImage else { return }
            finalImage = outputImage
        } else {
            finalImage = image
        }
        
        guard let cgImage = ciContext.createCGImage(finalImage, from: finalImage.extent) else { return }
        DispatchQueue.main.async { [weak self] in
            let outPutImage = UIImage(cgImage: cgImage)
            self?.imageView.image = outPutImage
        }
    }
}
