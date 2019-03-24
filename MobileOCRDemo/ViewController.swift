//
//  ViewController.swift
//  SwiftOCR Camera
//
//  Created by Nicolas Camenisch on 04.05.16.
//  Copyright © 2016 Nicolas Camenisch. All rights reserved.
//

import UIKit
import AVFoundation
import TesseractOCR


class ViewController: UIViewController {
    // MARK: - Outlets
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var viewFinder: UIView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var cropedImage: UIImageView!
    var arrOcrNumbers: [String] = []
    var scanHandler: ((String)->())?
    /// 是否在取照片
    var isPhoto: Bool = true
    // MARK: - Private Properties
    fileprivate var stillImageOutput: AVCapturePhotoOutput!
    fileprivate let captureSession = AVCaptureSession()
    fileprivate let device  = AVCaptureDevice.default(for: AVMediaType.video)
    
    
    // MARK: - View LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // start camera init
        self.title = "识别手机号"
        DispatchQueue.global(qos: .userInitiated).async {
            if self.device != nil {
                self.configureCameraForUse()
                
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(2)) {
            self.isPhoto = false
        }
    }
    
    
    
    // MARK: - IBActions
    @IBAction func takePhotoButtonPressed (_ sender: UIButton) {
        isPhoto = false
        label.text = ""
        arrOcrNumbers = []
    }
    
    
    @IBAction func sliderValueDidChange(_ sender: UISlider) {
        do {
            try device!.lockForConfiguration()
            var zoomScale = CGFloat(slider.value * 10.0)
            let zoomFactor = device?.activeFormat.videoMaxZoomFactor
            
            if zoomScale < 1 {
                zoomScale = 1
            } else if zoomScale > zoomFactor! {
                zoomScale = zoomFactor!
            }
            
            device?.videoZoomFactor = zoomScale
            device?.unlockForConfiguration()
        } catch {
            print("captureDevice?.lockForConfiguration() denied")
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)  {
        if isPhoto == true{
            return
        }else{
            isPhoto = true
        }
        let image = self.image(from: sampleBuffer)
        
        let croppedImage = self.prepareImageForCrop(using: image)
        
        if let tesseract = G8Tesseract(language: "eng") {
            //            tesseract.setVariableValue("0123456789", forKey: "tessedit_char_whitelist")
            // 2
            tesseract.engineMode = .tesseractOnly
            // 3
            tesseract.pageSegmentationMode = .auto
            // 4
            tesseract.image = croppedImage
            // 5
            tesseract.recognize()
            
            let r = tesseract.recognizedText ?? ""
            print(r)
            let pattern = "(1\\d{10})"
            
            let recognizedString = regexGetSub(pattern: pattern, str: r)
            
            if recognizedString.count != 11  || !recognizedString.hasPrefix("1"){
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1)) {
                    self.isPhoto = false
                }
            }else{
                DispatchQueue.main.async {
                    print("识别到手机号")
                    //                DLog(self.arrOcrNumbers)
                    self.label.text = recognizedString
                    self.cropedImage.image = croppedImage
                    self.scanHandler?(recognizedString)
                }
                
            }
        }
    }
    
    func regexGetSub(pattern:String, str:String) -> String {
        var subStr = ""
        let regex = try! NSRegularExpression(pattern: pattern, options:[])
        let matches = regex.matches(in: str, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, str.count))
        print(matches.count)
        //解析出子串
        
        if let match = matches.first {
            subStr = String(str[Range(match.range(at: 1), in: str)!])
        }
        
        return subStr
    }
    
    ///  捕获取样buffer里的内容，创建一个图片
    func image(from sampleBuffer:CMSampleBuffer) -> UIImage{
        //        let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer)
        //        let type = CMFormatDescriptionGetMediaType(formatDesc!)
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        /// 初始化上下文
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        let quartzImage = context!.makeImage()
        
        CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let image = UIImage(cgImage: quartzImage!)
        
        return image
        
    }
}

extension ViewController {
    // MARK: AVFoundation
    fileprivate func configureCameraForUse () {
        self.stillImageOutput = AVCapturePhotoOutput()
        let fullResolution = UIDevice.current.userInterfaceIdiom == .phone && max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height) < 568.0
        
        if fullResolution {
            self.captureSession.sessionPreset = AVCaptureSession.Preset.photo
        } else {
            self.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        }
        
        self.captureSession.addOutput(self.stillImageOutput)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.prepareCaptureSession()
        }
    }
    
    private func prepareCaptureSession () {
        do {
            //            if captureSession.inputs.isEmpty {
            captureSession.addInput(try AVCaptureDeviceInput(device: self.device!))
            //            }
        } catch {
            print("AVCaptureDeviceInput Error")
        }
        
        // device lock is important to grab data correctly from image
        do {
            try self.device?.lockForConfiguration()
            self.device?.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            self.device?.focusMode = .continuousAutoFocus
            self.device?.unlockForConfiguration()
        } catch {
            print("captureDevice?.lockForConfiguration() denied")
        }
        
        // 初始化输出
        let videoDataOutPut = AVCaptureVideoDataOutput()
        videoDataOutPut.videoSettings = [kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_32BGRA] as [String : Any]
        videoDataOutPut.setSampleBufferDelegate(self as AVCaptureVideoDataOutputSampleBufferDelegate, queue: DispatchQueue.global())
        // 添加输出
        if captureSession.canAddOutput(videoDataOutPut){
            captureSession.addOutput(videoDataOutPut)
        }
        //Set initial Zoom scale
        do {
            try self.device?.lockForConfiguration()
            
            let zoomScale: CGFloat = 2
            
            if zoomScale <= (device?.activeFormat.videoMaxZoomFactor)! {
                device?.videoZoomFactor = zoomScale
            }
            
            device?.unlockForConfiguration()
        } catch {
            print("captureDevice?.lockForConfiguration() denied")
        }
        
        
        
        DispatchQueue.main.async(execute: {
            // layer customization
            let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            previewLayer.frame.size = self.cameraView.frame.size
            previewLayer.frame.origin = CGPoint.zero
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            
            self.cameraView.layer.addSublayer(previewLayer)
            self.captureSession.startRunning()
        })
    }
    
    // MARK: Image Processing
    fileprivate func prepareImageForCrop (using image: UIImage) -> UIImage {
        let degreesToRadians: (CGFloat) -> CGFloat = {
            return $0 / 180.0 * CGFloat(Double.pi)
        }
        
        let degree = CGFloat(90)
        let cropSize = CGSize(width: 800, height: 110)
        
        //Downscale
        let cgImage = image.cgImage!
        
        let height = cropSize.width
        let width = image.size.height / image.size.width * cropSize.width
        
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let colorSpace = cgImage.colorSpace
        let bitmapInfo = cgImage.bitmapInfo
        
        let context = CGContext(data: nil,
                                width: Int(width),
                                height: Int(height),
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace!,
                                bitmapInfo: bitmapInfo.rawValue)
        
        context!.interpolationQuality = CGInterpolationQuality.none
        // Rotate the image context
        context?.rotate(by: degreesToRadians(degree));
        // Now, draw the rotated/scaled image into the context
        context?.scaleBy(x: -1.0, y: -1.0)
        
        context?.draw(cgImage, in: CGRect(x: -height, y: 0, width: height, height: width))
        //Crop
        //        switch imageOrientation {
        //        case .right, .rightMirrored:
        //            context?.draw(cgImage, in: CGRect(x: -height, y: 0, width: height, height: width))
        //        case .left, .leftMirrored:
        //            context?.draw(cgImage, in: CGRect(x: 0, y: -width, width: height, height: width))
        //        case .up, .upMirrored:
        //            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        //        case .down, .downMirrored:
        //            context?.draw(cgImage, in: CGRect(x: -width, y: -height, width: width, height: height))
        //        }
//        let cropHeight = cropSize.height * (width/cropSize.width)
        let widthRatio = 450 / self.view.frame.width
        let cropWidth = 280 * widthRatio
        
        let calculatedFrame = CGRect(x: CGFloat((width - cropWidth)/2.0), y: CGFloat((height - 44)/2.0), width: cropWidth, height: 44)
        let originImage = UIImage(cgImage: (context?.makeImage())!)
        let scaledCGImage = originImage.cgImage?.cropping(to: calculatedFrame)
        
        let beginImage = CIImage(cgImage: scaledCGImage!)
        let blackANdWhite = CIFilter(name: "CIColorControls", parameters: [kCIInputImageKey: beginImage, "inputBrightness": 0.0, "inputContrast":1.1, "inputSaturation":0.0])?.outputImage
        let output = CIFilter(name: "CIExposureAdjust", parameters: [kCIInputImageKey:blackANdWhite!, "inputEV": 0.7])?.outputImage
        let blackContext = CIContext(options: nil)
        let cgiimage = blackContext.createCGImage(output!, from: (output?.extent)!)
        let cropedImage = UIImage(cgImage: cgiimage!, scale: 0, orientation: image.imageOrientation)
        
        DispatchQueue.main.async {
            self.cropedImage.image = cropedImage
        }
        
        
        return cropedImage
    }
    
}
