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
    @IBAction func sliderF(_ sender: UISlider) {
        frequency = sender.value
        audio.updateBaselineFrequency(frequency)
    }
    
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
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
            
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
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        timer?.invalidate()
        graph?.teardown()
        graph = nil
        audio.stop()
        super.viewDidDisappear(animated)
    }
    
    func updateGraph() {
        if let graph = self.graph {
            graph.updateGraph(
                data: self.audio.fftData,
                forKey: "fft"
            )
            
            graph.updateGraph(
                data: self.audio.timeData,
                forKey: "time"
            )
            
            // BONUS: show the zoomed FFT
            // We can start at about the frequency minus 50 Hz and show the next 300 points
            let minfreq = frequency
            let startIdx = max(0, (Int(minfreq) - 50) * AudioConstants.AUDIO_BUFFER_SIZE / audio.samplingRate)
            let endIdx = min(startIdx + 300, self.audio.fftData.count - 1)
            let subArray = Array(self.audio.fftData[startIdx...endIdx])
            graph.updateGraph(
                data: subArray,
                forKey: "fftZoomed"
            )
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
}






/* Attempted change for doppler shift but does not work
 import UIKit

 class ModuleBViewController: UIViewController {
     
     @IBOutlet weak var userView: UIView!
     @IBOutlet weak var labelF: UILabel!
     @IBOutlet weak var gestureStatusLabel: UILabel!
     @IBAction func sliderF(_ sender: UISlider) {
         frequency = sender.value
         audio.updateBaselineFrequency(frequency)
     }
     
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
             
             // Allow the sine wave to stabilize before updating baseline
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                 self.audio.updateBaselineFrequency(self.frequency)
             }
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
             
             graph.addGraph(withName: "fftZoomed",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: 300)
             
             graph.addGraph(withName: "fft",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
             
             graph.addGraph(withName: "time",
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
             
             graph.makeGrids()
         }
         audio.startMicrophoneProcessingB(withFps: 20)
         audio.play()
         
         // Set baseline frequency after a short delay to ensure audio has started
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             self.audio.updateBaselineFrequency(self.frequency)
         }
         
         timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
             self.updateGraph()
             self.detectGesture()
         }
     }
     
     override func viewDidDisappear(_ animated: Bool) {
         timer?.invalidate()
         graph?.teardown()
         graph = nil
         audio.stop()
         super.viewDidDisappear(animated)
     }
     
     func updateGraph() {
         if let graph = self.graph {
             graph.updateGraph(
                 data: self.audio.fftData,
                 forKey: "fft"
             )
             
             graph.updateGraph(
                 data: self.audio.timeData,
                 forKey: "time"
             )
             
             // Show the zoomed FFT around the sineFrequency
             let frequencyWindow: Float = 1000.0
             let minFreq = max(0, audio.sineFrequency - frequencyWindow)
             let maxFreq = min(Float(audio.samplingRate) / 2, audio.sineFrequency + frequencyWindow)
             
             let startIdx = Int(minFreq * Float(AudioConstants.AUDIO_BUFFER_SIZE) / Float(audio.samplingRate))
             let endIdx = Int(maxFreq * Float(AudioConstants.AUDIO_BUFFER_SIZE) / Float(audio.samplingRate))
             
             let minIdx = max(0, startIdx)
             let maxIdx = min(endIdx, self.audio.fftData.count - 1)
             
             let subArray = Array(self.audio.fftData[minIdx...maxIdx])
             graph.updateGraph(
                 data: subArray,
                 forKey: "fftZoomed"
             )
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
 }
 */





/* this works, now edit for doppler
 import UIKit

 class ModuleBViewController: UIViewController {
     
     @IBOutlet weak var userView: UIView!
     @IBOutlet weak var labelF: UILabel!
     @IBOutlet weak var gestureStatusLabel: UILabel!
     @IBAction func sliderF(_ sender: UISlider) {
         frequency = sender.value
         audio.updateBaselineFrequency(frequency)
     }
     
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
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
             
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
     }
     
     override func viewDidDisappear(_ animated: Bool) {
         timer?.invalidate()
         graph?.teardown()
         graph = nil
         audio.stop()
         super.viewDidDisappear(animated)
     }
     
     func updateGraph() {
         if let graph = self.graph {
             graph.updateGraph(
                 data: self.audio.fftData,
                 forKey: "fft"
             )
             
             graph.updateGraph(
                 data: self.audio.timeData,
                 forKey: "time"
             )
             
             // BONUS: show the zoomed FFT
             // We can start at about the frequency minus 50 Hz and show the next 300 points
             let minfreq = frequency
             let startIdx = max(0, (Int(minfreq) - 50) * AudioConstants.AUDIO_BUFFER_SIZE / audio.samplingRate)
             let endIdx = min(startIdx + 300, self.audio.fftData.count - 1)
             let subArray = Array(self.audio.fftData[startIdx...endIdx])
             graph.updateGraph(
                 data: subArray,
                 forKey: "fftZoomed"
             )
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
 }
 */





/*
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

 
 */
