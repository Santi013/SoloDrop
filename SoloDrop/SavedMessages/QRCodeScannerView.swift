import AVFoundation
import SwiftUI
import UIKit

struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    @State private var permissionState: CameraPermissionState = .checking
    @State private var captureError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch permissionState {
                case .checking:
                    ProgressView()
                        .tint(.white)
                case .ready:
                    QRCodeCameraPreview(
                        onScan: { value in
                            onScan(value)
                            dismiss()
                        },
                        onError: { message in
                            captureError = message
                            permissionState = .unavailable
                        }
                    )
                    .ignoresSafeArea()

                    scannerOverlay
                case .denied:
                    QRScannerMessageView(
                        title: "Нет доступа к камере",
                        message: "Разрешите доступ к камере в Settings или введите адрес вручную.",
                        actionTitle: "Ввести вручную",
                        action: { dismiss() }
                    )
                case .unavailable:
                    QRScannerMessageView(
                        title: "Камера недоступна",
                        message: captureError ?? "Введите адрес сервера вручную.",
                        actionTitle: "Ввести вручную",
                        action: { dismiss() }
                    )
                }
            }
            .navigationTitle("Сканировать QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .task {
                await resolveCameraPermission()
            }
        }
    }

    private var scannerOverlay: some View {
        VStack {
            Spacer()
            Text("Наведите камеру на SoloDrop QR-код")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(.bottom, 36)
        }
    }

    private func resolveCameraPermission() async {
        guard AVCaptureDevice.default(for: .video) != nil else {
            permissionState = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .ready
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionState = granted ? .ready : .denied
        case .denied, .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .denied
        }
    }
}

private enum CameraPermissionState {
    case checking
    case ready
    case denied
    case unavailable
}

private struct QRScannerMessageView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundStyle(.white)
            Text(LocalizedStringKey(message))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 32)
            Button(action: action) {
                Text(LocalizedStringKey(actionTitle))
            }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
        }
    }
}

private struct QRCodeCameraPreview: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeCameraViewController {
        QRCodeCameraViewController(onScan: onScan, onError: onError)
    }

    func updateUIViewController(_ uiViewController: QRCodeCameraViewController, context: Context) {}
}

private final class QRCodeCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.solodrop.qrscanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false
    private let onScan: (String) -> Void
    private let onError: (String) -> Void

    init(onScan: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onScan = onScan
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func configureSession() {
        guard let camera = AVCaptureDevice.default(for: .video) else {
            onError("Камера недоступна. Введите адрес сервера вручную.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                onError("Камера недоступна. Введите адрес сервера вручную.")
                return
            }
            session.addInput(input)
        } catch {
            onError("Камера недоступна. Введите адрес сервера вручную.")
            return
        }

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onError("Сканирование QR недоступно. Введите адрес вручную.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    private func startSession() {
        guard !session.isRunning else { return }
        sessionQueue.async { [session] in
            session.startRunning()
        }
    }

    private func stopSession() {
        guard session.isRunning else { return }
        sessionQueue.async { [session] in
            session.stopRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else {
            return
        }

        didScan = true
        stopSession()
        onScan(value)
    }
}
