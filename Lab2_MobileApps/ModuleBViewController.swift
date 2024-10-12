//
//  ModuleBViewController.swift
//  Lab2_MobileApps
//
//  Created by Keaton Harvey on 10/10/24.
//
// MARK: Change slider back to 17,000 - 20,000 after done testing

import UIKit

class ModuleBViewController: UIViewController {
    
    @IBOutlet weak var userView: UIView!
    @IBOutlet weak var labelF: UILabel!
    @IBOutlet weak var gestureStatusLabel: UILabel!
    @IBOutlet weak var labelFFT: UILabel!
    
    @IBAction func sliderF(_ sender: UISlider) {
        frequency = sender.value
        audio.updateBaselineFrequency(frequency)
        leftOfFreq = frequency - 20
        rightOfFreq = frequency + 20
        resetDetectionValues()  // Reset compare values for new frequency
    }
    
    private var previousLeftAvg: Float?
    private var previousRightAvg: Float?
    private var leftOfFreq: Float?
    private var rightOfFreq: Float?
    
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 8
    }
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    var timer: Timer? = nil
    var frequency: Float = 18000 {
        didSet {
            audio.sineFrequency = frequency
            labelF.text = "Frequency: \(frequency)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        frequency = 18000
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
            
            graph.addGraph(withName: "fftZoomed", shouldNormalizeForFFT: true, numPointsInGraph: 300)
            graph.addGraph(withName: "fft", shouldNormalizeForFFT: true, numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
            graph.addGraph(withName: "time", numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
            graph.makeGrids()
        }
        
        audio.startMicrophoneProcessingB(withFps: 20)
        audio.play()
        
        // Timer to update graph and gesture detection
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        graph?.teardown()
        graph = nil
        audio.stop()
    }
    
    func resetDetectionValues() {
        previousLeftAvg = nil
        previousRightAvg = nil
    }
    
    private var gestureDisplayTimer: Timer?
    private var gestureText: String = "Gesture: No Movement"
    
    func updateGraph() {
        if let graph = self.graph {
            graph.updateGraph(data: self.audio.fftData, forKey: "fft")
            graph.updateGraph(data: self.audio.timeData, forKey: "time")
            
            let startIdx = (Int(frequency) - 900) * AudioConstants.AUDIO_BUFFER_SIZE / audio.samplingRate
            let endIdx = min(startIdx + 300, self.audio.fftData.count - 1)
            let subArray = Array(self.audio.fftData[startIdx...endIdx])
            graph.updateGraph(data: subArray, forKey: "fftZoomed")
            
            let leftStartIndex = Int(leftOfFreq ?? 17980) * AudioConstants.AUDIO_BUFFER_SIZE / audio.samplingRate
            let leftEndIndex = min(leftStartIndex + 20, self.audio.fftData.count - 1)
            
            let rightStartIndex = Int(rightOfFreq ?? 18020) * AudioConstants.AUDIO_BUFFER_SIZE / audio.samplingRate
            let rightEndIndex = min(rightStartIndex + 20, self.audio.fftData.count - 1)
            
            let leftSubArray = Array(self.audio.fftData[leftStartIndex...leftEndIndex])
            let rightSubArray = Array(self.audio.fftData[rightStartIndex...rightEndIndex])
            
            let leftAvg = leftSubArray.isEmpty ? 0.0 : leftSubArray.reduce(0, +) / Float(leftSubArray.count)
            let rightAvg = rightSubArray.isEmpty ? 0.0 : rightSubArray.reduce(0, +) / Float(rightSubArray.count)
            
            let threshold: Float = 1.75  // Adjusted threshold for sensitivity
            
            if let prevLeftAvg = previousLeftAvg, leftAvg > prevLeftAvg + threshold {
                gestureText = "Gesture: Detected - Moving Away"
            } else if let prevRightAvg = previousRightAvg, rightAvg > prevRightAvg + threshold {
                gestureText = "Gesture: Detected - Moving Toward"
            } else {
                gestureText = "Gesture: No Movement"
            }
            
            // Update previous averages
            previousLeftAvg = leftAvg
            previousRightAvg = rightAvg
            
            // Call the new function to handle label update with delay
            updateGestureLabel()
        }
    }
    
    func updateGestureLabel() {
            if gestureDisplayTimer == nil {
                gestureStatusLabel.text = gestureText
                gestureDisplayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                    self?.gestureDisplayTimer = nil  // Reset to allow future updates
                }
            }
        }
}//end of the class
