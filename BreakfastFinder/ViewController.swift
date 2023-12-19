/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the view controller for the Breakfast Finder.
*/

import UIKit
import AVFoundation
import Vision
import CoreBluetooth

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate, CBCentralManagerDelegate {

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    // Characteristics
    var customChar: CBCharacteristic?
    
    // Scan for peripheral
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central state update")
        if central.state != .poweredOn {
            print("Central is not powered on")
        } else {
            print("Central scanning for", WalkpalPeripheral.caneServiceUUID);
            centralManager.scanForPeripherals(withServices: [WalkpalPeripheral.caneServiceUUID],
                                              options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    // Handles the result of the scan
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        // We've found it so stop scan
        self.centralManager.stopScan()

        // Copy the peripheral instance
        self.peripheral = peripheral
        self.peripheral.delegate = self
        print("Peripheral Discovered: \(peripheral)")
//        print("Peripheral name: \(String(describing: peripheral.name))")
//        print ("Advertisement Data : \(advertisementData)")

        // Connect!
        self.centralManager.connect(self.peripheral, options: nil)

    }
    
    // The handler if we do connect succesfully
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == self.peripheral {
            print("Connected to your Cane Board")
            peripheral.discoverServices([WalkpalPeripheral.caneServiceUUID])
        }
    }
    
    // Handles discovery event
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == WalkpalPeripheral.caneServiceUUID {
                    print("Cane service found")
                    //Now kick off discovery of characteristics
                        peripheral.discoverCharacteristics([WalkpalPeripheral.customServiceUUID], for: service)
                    return
                }
            }
        }
    }
    // Handling discovery of characteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
//            if characteristic.uuid == WalkpalPeripheral.customServiceUUID {
//                print("LED characteristic found")
            for characteristic in characteristics {
                if characteristic.uuid == WalkpalPeripheral.customServiceUUID {
                    print("Custom characteristic found")
                    customChar = characteristic
                    writeListToArduino( withCharacteristic: customChar!, data: "0,0,0#")
                }
//                } else if characteristic.uuid == ParticlePeripheral.greenLEDCharacteristicUUID {
//                    print("Green LED characteristic found")
//                } else if characteristic.uuid == ParticlePeripheral.blueLEDCharacteristicUUID {
//                    print("Blue LED characteristic found");
//                }
            }
        }
    }
    
    func writeListToArduino( withCharacteristic characteristic: CBCharacteristic, data: String) {
//    func writeListToArduino( withCharacteristic characteristic: CBCharacteristic, withValue value: Data) {
            let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
            // Check if it has the write property
            if characteristic.properties.contains(.writeWithoutResponse) && peripheral != nil {

                peripheral.writeValue(valueString!, for: characteristic, type: .withoutResponse)

            }

    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        return
    }
    
    
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    
    @IBOutlet weak private var previewView: UIView!
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // to be implemented in the subclass
    }
    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupAVCapture()
//    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        // Select a video device, make an input
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInUltraWideCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720 // Model image size is smaller.
//        session.sessionPreset = .hd4K3840x2160 // Model image size is smaller.
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            // UPDATE
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
    }
    
    func startCaptureSession() {
        session.startRunning()
    }
    
    
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("frame dropped")
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
    
// Main Audio Engine and it's corresponding mixer
    var audioEngine: AVAudioEngine = AVAudioEngine()
    var mainMixer = AVAudioMixerNode()

    // One AVAudioPlayerNode per note
    var audioFilePlayer = [AVAudioPlayerNode]()

    var audioEnvironment = [AVAudioEnvironmentNode]()
    //{0: 'person', 1: 'bicycle', 2: 'car', 3: 'motorcycle', 5: 'bus', 7: 'truck', 10: 'fire hydrant', bottle==car}

    // Array of filepaths
    let noteFilePath: [String] = [
    Bundle.main.path(forResource: "1_bicycle_F", ofType: "mp3")!,
    Bundle.main.path(forResource: "1_bicycle_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "1_vehicle_F", ofType: "mp3")!,
    Bundle.main.path(forResource: "1_vehicle_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "1_motorcycle_F", ofType: "mp3")!,
    Bundle.main.path(forResource: "1_motorcycle_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "8_bus_F", ofType: "mp3")!,
    Bundle.main.path(forResource: "1_largevehicle_F", ofType: "mp3")!,
    Bundle.main.path(forResource: "1_largevehicle_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "2_cone_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "2_bollard_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "2_firehydrant_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "8_busfrontdoor_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "8_busbackdoor_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "7_busstation_F", ofType: "mp3")!,
    Bundle.main.path(forResource: "7_busstation_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "3_crosswalk_F", ofType: "mp3")!,
    Bundle.main.path(forResource: "3_crosswalk_A", ofType: "mp3")!,
    Bundle.main.path(forResource: "4_stairs_F", ofType: "mp3")!,
    Bundle.main.path(forResource: "4_stairs_A", ofType: "mp3")!,
    ]

    // Array to store the note URLs
    var noteFileURL = [URL]()

    // One audio file per note
    var noteAudioFile = [AVAudioFile]()

    // One audio buffer per note
    var noteAudioFileBuffer = [AVAudioPCMBuffer]()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
//        setupAVCapture()
//        print(noteFilePath.count)
        do
        {

            // For each note, read the note URL into an AVAudioFile,
            // setup the AVAudioPCMBuffer using data read from the file,
            // and read the AVAudioFile into the corresponding buffer
//            for i in 0...6
            for i in 0..<noteFilePath.count
            {
                noteFileURL.append(URL(fileURLWithPath: noteFilePath[i]))

                // Read the corresponding url into the audio file
                try noteAudioFile.append(AVAudioFile(forReading: noteFileURL[i]))

                // Read data from the audio file, and store it in the correct buffer
                let noteAudioFormat = noteAudioFile[i].processingFormat

                let noteAudioFrameCount = UInt32(noteAudioFile[i].length)

                noteAudioFileBuffer.append(AVAudioPCMBuffer(pcmFormat: noteAudioFormat, frameCapacity: noteAudioFrameCount)!)

                // Read the audio file into the buffer
                try noteAudioFile[i].read(into: noteAudioFileBuffer[i])
            }

           mainMixer = audioEngine.mainMixerNode

            // For each note, attach the corresponding node to the audioEngine, and connect the node to the audioEngine's mixer.
            for i in 0..<noteFilePath.count
            {
                audioEnvironment.append(AVAudioEnvironmentNode())
//                    environment = AVAudioEnvironmentNode()
                audioEnvironment[i].listenerPosition = AVAudioMake3DPoint(0, 0, 0)
                audioEnvironment[i].listenerVectorOrientation =
                  AVAudioMake3DVectorOrientation(AVAudioMake3DVector(0, 0, -1),
                                                 AVAudioMake3DVector(0, 1, 0))
//                    audioEnvironment[i].reverbParameters.loadFactoryReverbPreset(.largeHall2)
                audioEnvironment[i].reverbParameters.enable = true
                audioEnvironment[i].reverbParameters.level = 40
                audioEnvironment[i].distanceAttenuationParameters.maximumDistance = 2
                audioEnvironment[i].distanceAttenuationParameters.referenceDistance = 0.1
//                    audioEnvironment[i].distanceAttenuationParameters.rolloffFactor = .
                audioEnvironment[i].renderingAlgorithm = .HRTFHQ
                audioEnvironment[i].sourceMode = .bypass
                audioEnvironment[i].pointSourceInHeadMode = .bypass
//                    audioEnvironment[i].volume = 0.0
//                    audioEnvironment[i].pan = 1.0
                audioEnvironment[i].rate = 1.2
//                    audioEnvironment[i].reverbBlend = 40.0
                audioEnvironment[i].obstruction = -100.0
                audioEnvironment[i].occlusion = -100.0

                audioEngine.attach(audioEnvironment[i])
                audioEngine.connect(audioEnvironment[i], to: mainMixer, format: nil)
                
                audioFilePlayer.append(AVAudioPlayerNode())
                audioEngine.attach(audioFilePlayer[i])
//                    audioFilePlayer[i].i
//                    audioFilePlayer[i].renderingAlgorithm = .auto
//                    setSoundSourcePosition(index: i)

                audioEngine.connect(audioFilePlayer[i], to: audioEnvironment[i], fromBus: 0, toBus: i, format: noteAudioFileBuffer[i].format)/*                    audioEngine.connect(audioFilePlayer[i], to: mainMixer, fromBus: 0, toBus: i, format: noteAudioFileBuffer[i].format)*/
            }

            // Start the audio engine
            try audioEngine.start()

            // Setup the audio session to play sound in the app, and activate the audio session
            try
                AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        }
        catch let error
        {
            print(error.localizedDescription)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // 5 seconds delay
            self.setupAVCapture()
        }
//        setupAVCapture()
    }

    func playSound(senderTag: Int, x: CGFloat, y: CGFloat, z: CGFloat)
        {
            let sound: Int = senderTag - 1
//            print(sound)
//            audioFilePlayer[sound].position = AVAudioMake3DPoint(Float(x), Float(y), Float(z))
//            setSoundSourcePosition(index: <#T##Int#>, x: x, y: y, z: z)
//             Set up the corresponding audio player to play its sound.
//            audioFilePlayer[sound].scheduleBuffer(noteAudioFileBuffer[sound], at: nil, options: .interrupts, completionHandler: nil)
//            audioFilePlayer[sound].play()
            
//             Schedule the sound to play after a delay of 1.5 seconds
//            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            DispatchQueue.main.async() {
                self.audioFilePlayer[sound].position = AVAudioMake3DPoint(Float(x), Float(y), Float(z))
                // Set up the corresponding audio player to play its sound.
                self.audioFilePlayer[sound].scheduleBuffer(self.noteAudioFileBuffer[sound], at: nil, options: .interrupts, completionHandler: nil)
                self.audioFilePlayer[sound].play()
            }
            
//            // Check if the player is already playing a sound
//            if audioFilePlayer[sound].isPlaying {
//                // Optionally, you can stop the current sound or wait for it to finish
//                // audioFilePlayer[sound].stop()
//                return
//            }
//            print(audioFilePlayer[sound].isPlaying)
//
//            audioFilePlayer[sound].position = AVAudioMake3DPoint(Float(x), Float(y), Float(z))
//            // Set up the corresponding audio player to play its sound.
//            audioFilePlayer[sound].scheduleBuffer(noteAudioFileBuffer[sound], at: nil, options: .interrupts) {
//                // This is a completion handler that gets called when the sound finishes playing
//                // You can use this to trigger any follow-up actions
//            }
//            audioFilePlayer[sound].play()
//        

        }
    
            // Used to manipulate sound source position by the user.
//        func setSoundSourcePosition(index: Int) {
//        //          let coords : [Float] = [ -5.0, 0.0, 5.0 ]
//        //          let x = coords[xSegment.selectedSegmentIndex]
//        //          let y = coords[ySegment.selectedSegmentIndex]
//        //          let z = coords[zSegment.selectedSegmentIndex]
//        //          NSLog("Setting sound source position to (\(x), \(y), \(z))")
//            var x: Float = 0.0
//            var y: Float = 0.0
//            var z: Float = 0.0
//            // limits to F sound
//            // x (-1, 0 ,1)
//            // y (-1, 0, 1)
//            // z (-1, 0, 1)
//            audioFilePlayer[index].position = AVAudioMake3DPoint(x, y, z)
//            }
}


