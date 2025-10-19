//
//  QRScannerView.swift
//  Paperkey
//
//  Created by helmholtz on 2025/10/13.
//

import SwiftUI
import AVFoundation
import CoreImage

struct QRScannerView: UIViewControllerRepresentable {
    struct Payload {
        let rawData: Data
        let stringValue: String?
    }
    
    typealias ResultHandler = (Result<Payload, Error>) -> Void
    
    var onResult: ResultHandler
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.coordinator = context.coordinator
        context.coordinator.controller = controller
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController {
    weak var coordinator: QRScannerView.Coordinator?
    
    private let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    private func startScanning() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.configureSession()
                    } else {
                        self.coordinator?.report(error: .permissionDenied)
                    }
                }
            }
        default:
            coordinator?.report(error: .permissionDenied)
        }
    }
    
    private func configureSession() {
        guard let coordinator else { return }
        guard let device = AVCaptureDevice.default(for: .video) else {
            coordinator.report(error: .cameraUnavailable)
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                session.commitConfiguration()
                coordinator.report(error: .cameraUnavailable)
                return
            }
        } catch {
            session.commitConfiguration()
            coordinator.report(error: .cameraUnavailable)
            return
        }
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            session.commitConfiguration()
            coordinator.report(error: .cameraUnavailable)
            return
        }
        
        session.commitConfiguration()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        if !session.isRunning {
            session.startRunning()
        }
    }
    
    func stopScanning() {
        if session.isRunning {
            session.stopRunning()
        }
    }
}

extension QRScannerView {
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onResult: ResultHandler
        weak var controller: ScannerViewController?
        private var didFinish = false
        
        init(onResult: @escaping ResultHandler) {
            self.onResult = onResult
        }
        
        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didFinish else { return }
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr else {
                return
            }
            
            let stringValue = object.stringValue
            var rawData: Data?
            if let descriptor = object.descriptor as? CIQRCodeDescriptor {
                rawData = descriptor.errorCorrectedPayload
                rawData = QRByteModeDecoder.decode(from: rawData)
            } else {
                rawData = nil
            }
            
            let hexString = rawData?.map { String(format: "%02x", $0) }.joined()
            
            guard let payloadData = rawData else {
                return
            }
            
            didFinish = true
            controller?.stopScanning()
            let payload = Payload(rawData: payloadData, stringValue: stringValue)
            onResult(.success(payload))
        }
        
        func report(error: ScannerError) {
            guard !didFinish else { return }
            didFinish = true
            controller?.stopScanning()
            onResult(.failure(error))
        }
    }
    
    enum ScannerError: LocalizedError {
        case permissionDenied
        case cameraUnavailable
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return String(localized: "Camera access is required to scan QR codes.")
            case .cameraUnavailable:
                return String(localized: "Unable to access the camera for scanning.")
            }
        }
    }
}
