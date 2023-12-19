/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the object recognition view controller for the Breakfast Finder.
*/

import UIKit
import AVFoundation
import Vision
import Accelerate

class VisionObjectRecognitionViewController: ViewController {
    
    private var detectionOverlay: CALayer! = nil
    
    // Vision parts
    private var requests = [VNRequest]()
    private var thresholdProvider = ThresholdProvider()
    private var lastExecutionTime: Date?
    private var timer: Timer?

    // yolov8m SETTINGS
//    let iouThreshold: Double = 0.55
//    let confidenceThreshold: Double = 0.85
    // it SETTINGS <0.646
//    let iouThreshold: Double = 0.646
//    let confidenceThreshold: Double = 0.8
    // obs SETTINGS <0.667
    let iouThreshold: Double = 0.667
    let confidenceThreshold: Double = 0.85
    
    // Update the structure to include depth
    struct DetectedObject {
        var id: String
        var objectObservation: VNClassificationObservation
        var boundingBox: CGRect
        var lastSeen: Date
        var depthY: CGFloat
        var depthX: CGFloat
        var depth: CGFloat
        var near: Bool
        var far: Bool
    }
    
    // Dictionary to keep track of detected objects
    var trackedObjects = [String: DetectedObject]()
    
//    @objc func runCode() {
//        let currentTime = Date()
//        if let lastRun = lastExecutionTime, currentTime.timeIntervalSince(lastRun) < 1.0 {
//            // If the last execution was less than a second ago, skip this run
//            return
//        }
//
//        if trackedObjects.isEmpty {
//            writeListToArduino( withCharacteristic: customChar!, data: "0,0,0#")
//        }
////        print(trackedObjects)
//
//        lastExecutionTime = currentTime // Update the last execution time
//    }

    
//    @discardableResult
//    func setupVision() -> NSError? {
////        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(runCode), userInfo: nil, repeats: true)
//        // Setup Vision parts
//        let error: NSError! = nil
//        
//        // Initialize a model configuration
//        let config = MLModelConfiguration()
////        config.setValue(1, forKey: "experimentalMLE5EngineUsage")
//        config.computeUnits = .all  // Use all available compute units
//        
//        guard let modelURL = Bundle.main.url(forResource: "it", withExtension: "mlmodelc") else {
//            return NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
//        }
//        do {
//            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
//            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
//                DispatchQueue.main.async(execute: {
//                    // perform all the UI updates on the main queue
//                    if let results = request.results {
//                        self.thresholdProvider.values = [
//                            "iouThreshold": MLFeatureValue(double: self.iouThreshold),
//                            "confidenceThreshold": MLFeatureValue(double: self.confidenceThreshold)]
//                        visionModel.featureProvider = self.thresholdProvider
//                        self.drawVisionRequestResults(results)
//                    } else {
//                        self.writeListToArduino( withCharacteristic: self.customChar!, data: "0,0,0#")
//                    }
//                })
//            })
//            objectRecognition.imageCropAndScaleOption = .scaleFit
//            self.requests = [objectRecognition]
//        } catch let error as NSError {
//            print("Model loading went wrong: \(error)")
//        }
//        
//        return error
//    }
    
    @discardableResult
    func setupVision() -> NSError? {
        let error: NSError! = nil

        let config = MLModelConfiguration()
        config.computeUnits = .all

        // Load and set up each model
        let modelURLs = ["yolov8m", "it", "obs"].compactMap {
            Bundle.main.url(forResource: $0, withExtension: "mlmodelc")
        }

        var requests = [VNCoreMLRequest]()

        for modelURL in modelURLs {
            do {
                let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
                let objectRecognition = VNCoreMLRequest(model: visionModel) { request, error in
                    // Handle each request's results
                    DispatchQueue.main.async(execute: {
                        // perform all the UI updates on the main queue
                        if let results = request.results {
                            self.thresholdProvider.values = [
                                "iouThreshold": MLFeatureValue(double: self.iouThreshold),
                                "confidenceThreshold": MLFeatureValue(double: self.confidenceThreshold)]
                            visionModel.featureProvider = self.thresholdProvider
                            self.drawVisionRequestResults(results)
                        } else {
                            self.writeListToArduino( withCharacteristic: self.customChar!, data: "0,0,0#")
                        }
                    })
                }
                objectRecognition.imageCropAndScaleOption = .scaleFit
                requests.append(objectRecognition)
            } catch let error as NSError {
                print("Model loading went wrong: \(error)")
                return error
            }
        }

        self.requests = requests
        return error
    }

    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
//        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(runCode), userInfo: nil, repeats: true)
//        if trackedObjects.isEmpty {
//            writeListToArduino( withCharacteristic: customChar!, data: "0,0,0#")
//        }
        
        let observationGroup = DispatchGroup()
        for observation in results where observation is VNRecognizedObjectObservation {
            observationGroup.enter()
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                observationGroup.leave()
                continue
            }

            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            if (topLabelObservation.identifier == "bicycle") || (topLabelObservation.identifier == "bus") || (topLabelObservation.identifier == "car") || (topLabelObservation.identifier == "truck") || (topLabelObservation.identifier == "motorcycle") || (topLabelObservation.identifier == "cone") || (topLabelObservation.identifier == "bollard_normal") || (topLabelObservation.identifier == "bollard_abnormal") || (topLabelObservation.identifier == "fire_hydrant") || (topLabelObservation.identifier == "bus_door_front") || (topLabelObservation.identifier == "bus_door_back") || (topLabelObservation.identifier == "bus_stop") || (topLabelObservation.identifier == "crosswalk") || (topLabelObservation.identifier == "stair") {
//            if (topLabelObservation.identifier == "bus") || (topLabelObservation.identifier == "car") || (topLabelObservation.identifier == "bus_door_front") || (topLabelObservation.identifier == "bus_door_back") {
            } else {
                observationGroup.leave()
                continue
            }
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
//            print(topLabelObservation.identifier)
            
            var midX = objectBounds.midX / CGFloat(bufferSize.width)
            if midX > 0.5 {
                midX = -(midX-0.5)/0.5
            } else {
                midX = (0.5-midX)/0.5
            }
            
            var midY = objectBounds.midY / CGFloat(bufferSize.height)
            if midY > 0.5 {
                midY = -(midY-0.5)/0.5
            } else {
                midY = (0.5-midY)/0.5
            }
            
            var depth = 0.0
            let depthY = objectBounds.height / CGFloat(bufferSize.height)
            let depthX = objectBounds.width / CGFloat(bufferSize.width)
            if objectBounds.height > objectBounds.width {
                depth = depthY
            } else {
                depth = depthX
            }
            
            let newObject = DetectedObject(
                id: UUID().uuidString,
                objectObservation: topLabelObservation,
                boundingBox: objectBounds,
                lastSeen: Date(),
                depthY: depthY,
                depthX: depthX,
                depth: depth,
                near: false,
                far: false
            )

//            observationGroup.enter()
            // This would be called whenever new objects are detected
            updateTracking(for: [newObject], midX: midX, midY: midY, z: depth)
            observationGroup.leave()
//            print(trackedObjects.keys)
            let switchGroup = DispatchGroup()
            for key_value in trackedObjects {
                switchGroup.enter()
                let shapeLayer = self.createRoundedRectLayerWithBounds(key_value.value.boundingBox)
                let textLayer = self.createTextSubLayerInBounds(key_value.value.boundingBox,
                                                                identifier: key_value.value.objectObservation.identifier,
                                                                confidence: key_value.value.objectObservation.confidence)
                shapeLayer.addSublayer(textLayer)
                detectionOverlay.addSublayer(shapeLayer)
                // Normal mode
                let tolerance: CGFloat = 0.00
                
                switch key_value.value.objectObservation.identifier{
                // YOLOV8M
                // F A
                case "bicycle":

                    if ((key_value.value.depth-tolerance) < 0.3 || (key_value.value.depth+tolerance) < 0.3) && key_value.value.far == false {
                        trackedObjects[key_value.key]?.far = true
                        writeListToArduino( withCharacteristic: customChar!, data: "1,0,0#")
                        playSound(senderTag: 1, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else if ((key_value.value.depth-tolerance) >= 0.3 || (key_value.value.depth+tolerance) >= 0.3) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "3,1,3#")
                        playSound(senderTag: 2, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }    
                // F A
                case "car":

                    if ((key_value.value.depth-tolerance) < 0.4 || (key_value.value.depth+tolerance) < 0.4) && key_value.value.far == false {
                        trackedObjects[key_value.key]?.far = true
                        writeListToArduino( withCharacteristic: customChar!, data: "1,0,1#")
                        playSound(senderTag: 3, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else if ((key_value.value.depth-tolerance) >= 0.4 || (key_value.value.depth+tolerance) >= 0.4) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "3,3,3#")
                        playSound(senderTag: 4, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }        
                // F A
                case "motorcycle":

                    if ((key_value.value.depth-tolerance) < 0.5 || (key_value.value.depth+tolerance) < 0.5) && key_value.value.far == false {
                        trackedObjects[key_value.key]?.far = true
                        writeListToArduino( withCharacteristic: customChar!, data: "1,0,0#")
                        playSound(senderTag: 5, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else if ((key_value.value.depth-tolerance) >= 0.5 || (key_value.value.depth+tolerance) >= 0.5) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "3,1,3#")
                        playSound(senderTag: 6, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }            
                // F A
                case "bus":

                    if ((key_value.value.depth-tolerance) < 0.5 || (key_value.value.depth+tolerance) < 0.5) && key_value.value.far == false {
                        trackedObjects[key_value.key]?.far = true
                        writeListToArduino( withCharacteristic: customChar!, data: "1,0,0#")
                        playSound(senderTag: 7, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }               
                // F A
                case "truck":

                    if ((key_value.value.depth-tolerance) < 0.5 || (key_value.value.depth+tolerance) < 0.5) && key_value.value.far == false {
                        trackedObjects[key_value.key]?.far = true
                        writeListToArduino( withCharacteristic: customChar!, data: "1,0,0#")
                        playSound(senderTag: 8, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else if ((key_value.value.depth-tolerance) >= 0.5 || (key_value.value.depth+tolerance) >= 0.5) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "3,0,3#")
                        playSound(senderTag: 9, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }              
                    
                    
                    
                // OBSTACLE
                // F A
                case "cone":

                    if ((key_value.value.depth-tolerance) >= 0.3 || (key_value.value.depth+tolerance) >= 0.3) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,1#")
                        playSound(senderTag: 10, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }                  
                // F A
                case "bollard_normal":

                    if ((key_value.value.depth-tolerance) >= 0.3 || (key_value.value.depth+tolerance) >= 0.3) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,1#")
                        playSound(senderTag: 11, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }                  
                // F A
                case "bollard_abnormal":

                    if ((key_value.value.depth-tolerance) >= 0.3 || (key_value.value.depth+tolerance) >= 0.3) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,1#")
                        playSound(senderTag: 11, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }                  
                // F A
                case "fire_hydrant":

                    if ((key_value.value.depth-tolerance) >= 0.3 || (key_value.value.depth+tolerance) >= 0.3) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,1#")
                        playSound(senderTag: 12, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }                  
                // F A
//                case "bicycle":
//
//                    if ((key_value.value.depth-tolerance) < 0.5 || (key_value.value.depth+tolerance) < 0.5) && key_value.value.far == false {
//                        trackedObjects[key_value.key]?.far = true
//                        writeListToArduino( withCharacteristic: customChar!, data: "1,0,0#")
//                        playSound(senderTag: 1, x: midX, y: midY, z: depth)
//                        switchGroup.leave()
//                        continue
//                    } else if ((key_value.value.depth-tolerance) >= 0.5 || (key_value.value.depth+tolerance) >= 0.5) && key_value.value.near == false {
//                        trackedObjects[key_value.key]?.near = true
//                        writeListToArduino( withCharacteristic: customChar!, data: "3,1,3#")
//                        playSound(senderTag: 2, x: midX, y: midY, z: depth)
//                        switchGroup.leave()
//                        continue
//                    } else {
//                        switchGroup.leave()
//                        continue
//                    }
                // F A
//                case "motorcycle":
//
//                    if ((key_value.value.depth-tolerance) < 0.5 || (key_value.value.depth+tolerance) < 0.5) && key_value.value.far == false {
//                        trackedObjects[key_value.key]?.far = true
//                        writeListToArduino( withCharacteristic: customChar!, data: "1,0,0#")
//                        playSound(senderTag: 5, x: midX, y: midY, z: depth)
//                        switchGroup.leave()
//                        continue
//                    } else if ((key_value.value.depth-tolerance) >= 0.5 || (key_value.value.depth+tolerance) >= 0.5) && key_value.value.near == false {
//                        trackedObjects[key_value.key]?.near = true
//                        writeListToArduino( withCharacteristic: customChar!, data: "3,1,3#")
//                        playSound(senderTag: 6, x: midX, y: midY, z: depth)
//                        switchGroup.leave()
//                        continue
//                    } else {
//                        switchGroup.leave()
//                        continue
//                    }
                    
                // INTERACTIVE
                // F A
//                case "bus":
//
//                    if ((key_value.value.depth-tolerance) < 0.5 || (key_value.value.depth+tolerance) < 0.5) && key_value.value.far == false {
//                        trackedObjects[key_value.key]?.far = true
//                        writeListToArduino( withCharacteristic: customChar!, data: "1,0,0#")
//                        playSound(senderTag: 7, x: midX, y: midY, z: depth)
//                        switchGroup.leave()
//                        continue
//                    } else {
//                        switchGroup.leave()
//                        continue
//                    }
                // F A
                case "bus_door_front":

                    if ((key_value.value.depth-tolerance) >= 0.4 || (key_value.value.depth+tolerance) >= 0.4) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,1#")
                        playSound(senderTag: 13, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }
                // F A
                case "bus_door_back":

                    if ((key_value.value.depth-tolerance) >= 0.4 || (key_value.value.depth+tolerance) >= 0.4) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,1#")
                        playSound(senderTag: 14, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }
                // F A
                case "bus_stop":

                    if ((key_value.value.depth-tolerance) < 0.5 || (key_value.value.depth+tolerance) < 0.5) && key_value.value.far == false {
                        trackedObjects[key_value.key]?.far = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,1#")
                        playSound(senderTag: 15, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else if ((key_value.value.depth-tolerance) >= 0.5 || (key_value.value.depth+tolerance) >= 0.5) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,2#")
                        playSound(senderTag: 16, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }
                // F A
                case "crosswalk":

                    if ((key_value.value.depth-tolerance) < 0.5 || (key_value.value.depth+tolerance) < 0.5) && key_value.value.far == false {
                        trackedObjects[key_value.key]?.far = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,1#")
                        playSound(senderTag: 17, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else if ((key_value.value.depth-tolerance) >= 0.5 || (key_value.value.depth+tolerance) >= 0.5) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,2#")
                        playSound(senderTag: 18, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }
                // F A
                case "stair":

                    if ((key_value.value.depth-tolerance) < 0.5 || (key_value.value.depth+tolerance) < 0.5) && key_value.value.far == false {
                        trackedObjects[key_value.key]?.far = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,1#")
                        playSound(senderTag: 19, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else if ((key_value.value.depth-tolerance) >= 0.5 || (key_value.value.depth+tolerance) >= 0.5) && key_value.value.near == false {
                        trackedObjects[key_value.key]?.near = true
                        writeListToArduino( withCharacteristic: customChar!, data: "0,0,2#")
                        playSound(senderTag: 20, x: midX, y: midY, z: depth)
                        switchGroup.leave()
                        continue
                    } else {
                        switchGroup.leave()
                        continue
                    }

                    
                default:
                    writeListToArduino( withCharacteristic: customChar!, data: "0,0,0#")
                    switchGroup.leave()
                    continue
                }
            }

        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    // Function to update object tracking
    func updateTracking(for detectedObjects: [DetectedObject], midX: CGFloat, midY: CGFloat, z: CGFloat) {
        let group = DispatchGroup()
        for object in detectedObjects {
            group.enter()
            if let existingObject = findExistingObject(for: object) {
                // Update the existing object's details
                trackedObjects[existingObject.id]?.objectObservation = object.objectObservation
                trackedObjects[existingObject.id]?.boundingBox = object.boundingBox
                trackedObjects[existingObject.id]?.lastSeen = Date()
                trackedObjects[existingObject.id]?.depthY = object.depthY
                trackedObjects[existingObject.id]?.depthX = object.depthX
                trackedObjects[existingObject.id]?.depth = object.depth
//                trackedObjects[existingObject.id]?.near = existingObject.near
//                trackedObjects[existingObject.id]?.far = existingObject.far
            } else {
                // This is a new object, add it to the dictionary
                let newID = UUID().uuidString
                trackedObjects[newID] = object
//                playSound(senderTag: 1, x: midX, y: midY, z: z)
            }
            group.leave()
        }
        group.enter()
        // Clean up old objects
        cleanupTrackedObjects()
        group.leave()
    }
    
    // Function to find an existing object based on depth comparison
    func findExistingObject(for newObject: DetectedObject) -> DetectedObject? {
        let group = DispatchGroup()
        for (_, trackedObject) in trackedObjects {
            group.enter()
            // Calculate depth for both objects
            let existingDepthY = trackedObject.boundingBox.height / CGFloat(bufferSize.height)
            let existingDepthX = trackedObject.boundingBox.width / CGFloat(bufferSize.width)

            // Check if the depths are similar within some tolerance
            let tolerance: CGFloat = 0.15 // Adjust the tolerance as needed
            if abs(newObject.depthY - existingDepthY) < tolerance && abs(newObject.depthX - existingDepthX) < tolerance {
                group.leave()
                return trackedObject
            }
            group.leave()
        }
        return nil
    }
    
    // Function to remove objects that haven't been seen for a certain threshold
    func cleanupTrackedObjects() {
        let threshold = 7.0 // Time in seconds
        let now = Date()
        let group = DispatchGroup()
        for (id, object) in trackedObjects {
            group.enter()
            if now.timeIntervalSince(object.lastSeen) > threshold { // Try to get instant Date()
//                print(now, object.lastSeen)
                trackedObjects.removeValue(forKey: id)
            }
            group.leave()
        }
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    override func setupAVCapture() {
        super.setupAVCapture()
        
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        setupVision()
        
        // start the capture
        startCaptureSession()
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: -scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(0)).scaledBy(x: -1.0, y: -1.0))
//        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
}

class ThresholdProvider: MLFeatureProvider {
   open var values = [
       "iouThreshold": MLFeatureValue(double: 0.6),
       "confidenceThreshold": MLFeatureValue(double: 0.9)
       ]
   var featureNames: Set<String> {
       return Set(values.keys)
   }
   func featureValue(for featureName: String) -> MLFeatureValue? {
       return values[featureName]
   }
}
