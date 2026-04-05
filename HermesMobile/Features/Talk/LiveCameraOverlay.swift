import AVFoundation
import SwiftUI
import UIKit

/// Full-screen camera preview that sends periodic snapshots to the Realtime model.
/// Audio is NOT captured — the microphone stays on WebRTC for voice.
struct LiveCameraOverlay: View {
    let onFrameCaptured: (_ frameData: Data, _ isFirstFrame: Bool) -> Void
    let onDismiss: () -> Void

    @State private var captureManager = CameraCaptureManager()
    @State private var isUsingFrontCamera = false

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: captureManager.session)
                .ignoresSafeArea()

            // Controls overlay
            VStack {
                HStack {
                    Spacer()

                    // Flip camera
                    Button {
                        isUsingFrontCamera.toggle()
                        captureManager.switchCamera(front: isUsingFrontCamera)
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, Design.Spacing.md)

                    // Close camera (back to voice mode)
                    Button {
                        captureManager.stop()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, Design.Spacing.md)
                }
                .padding(.top, Design.Spacing.xl)

                Spacer()

                // Subtle status
                Text("Camera active \u{2022} voice continues")
                    .font(Design.Typography.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, Design.Spacing.xxl)
            }
        }
        .onAppear {
            captureManager.onFrameCaptured = onFrameCaptured
            captureManager.start(front: isUsingFrontCamera)
        }
        .onDisappear {
            captureManager.stop()
        }
        .statusBarHidden(true)
    }
}

// MARK: - Camera Preview (UIKit wrapper)

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Camera Capture Manager

@MainActor
@Observable
final class CameraCaptureManager: NSObject {
    let session = AVCaptureSession()
    var onFrameCaptured: ((_ frameData: Data, _ isFirstFrame: Bool) -> Void)?

    private var videoOutput: AVCaptureVideoDataOutput?
    private var frameTimer: Timer?
    private var latestCompressedFrame: Data?
    // isFirstFrame removed — camera frames always send with triggerResponse: false
    private var isRunning = false
    private let captureQueue = DispatchQueue(label: "hermes.camera.capture", qos: .userInitiated)

    func start(front: Bool) {
        guard !isRunning else { return }
        isRunning = true

        session.beginConfiguration()
        session.sessionPreset = .medium // 480p — good balance of quality and size

        // Add video input (no audio — mic stays on WebRTC)
        let position: AVCaptureDevice.Position = front ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // Add video output for frame capture
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        videoOutput = output

        session.commitConfiguration()
        session.startRunning()

        // Periodic frame capture timer (every 1.5 seconds)
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.captureAndSendFrame()
            }
        }
    }

    func stop() {
        frameTimer?.invalidate()
        frameTimer = nil
        session.stopRunning()
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }
        videoOutput = nil
        latestCompressedFrame = nil
        isRunning = false
    }

    func switchCamera(front: Bool) {
        guard isRunning else { return }
        stop()
        start(front: front)
    }

    private func captureAndSendFrame() {
        guard let imageData = latestCompressedFrame else { return }
        onFrameCaptured?(imageData, false)
    }

    /// Convert a sample buffer to a 512px JPEG at 0.5 quality (~20-40KB).
    nonisolated private static func compressFrame(_ buffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let image = UIImage(cgImage: cgImage)
        let maxDimension: CGFloat = 512
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.5)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Compress on the capture queue immediately, then send the Data to main
        guard let frameData = Self.compressFrame(sampleBuffer) else { return }
        Task { @MainActor [weak self] in
            self?.latestCompressedFrame = frameData
        }
    }
}
