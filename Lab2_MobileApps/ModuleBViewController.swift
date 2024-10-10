//
//  ModuleBViewControllerV2.swift
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
    @IBAction func sliderF(_ sender: UISlider) {
            frequency = sender.value
            audio.updateBaselineFrequency(frequency)
        }
    
    
    struct AudioConstants{
            static let AUDIO_BUFFER_SIZE = 1024*8
        }
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
            return MetalGraph(userView: self.userView)
        }()
    
    var timer:Timer? = nil
    var frequency:Float = 300 {
        didSet {
            audio.sineFrequency = frequency
            labelF.text = "Frequency: \(frequency)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        frequency = 18000
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
            
            graph.addGraph(withName: "fftZoomed",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: 300) // 300 points to display
            
            graph.addGraph(withName: "fft",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            
            graph.addGraph(withName: "time",
                numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
            
            graph.makeGrids()
        }
        audio.startMicrophoneProcessingB(withFps: 20)
        audio.play()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
            self.detectGesture()
        }
    }//end of viewWillAppear
    
    override func viewDidDisappear(_ animated: Bool) {
        
        timer?.invalidate()
        graph?.teardown()
        graph = nil
        audio.stop()
        super.viewDidDisappear(animated)
    }
    
    
    func updateGraph(){
        
        if let graph = self.graph{
            graph.updateGraph(
                data: self.audio.fftData,
                forKey: "fft"
            )
            
            graph.updateGraph(
                data: self.audio.timeData,
                forKey: "time"
            )
            
            // BONUS: show the zoomed FFT
            // we can start at about 150Hz and show the next 300 points
            // actual Hz = f_0 * N/F_s
            let minfreq = frequency
            let startIdx:Int = (Int(minfreq)-50) * AudioConstants.AUDIO_BUFFER_SIZE/audio.samplingRate
            let subArray:[Float] = Array(self.audio.fftData[startIdx...startIdx+300])
            graph.updateGraph(
                data: subArray,
                forKey: "fftZoomed")
        }
    }
    
    
    func detectGesture() {
        let gesture = audio.detectGesture()
        switch gesture {
            case .toward:
                gestureStatusLabel.text = "Gesture: Toward Microphone"
            case .away:
                gestureStatusLabel.text = "Gesture: Away from Microphone"
            case .none:
                gestureStatusLabel.text = "Gesture: No Movement"
            }
        }
    
}//end of class
