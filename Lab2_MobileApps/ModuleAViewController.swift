
import UIKit
import Metal

class ModuleAViewController: UIViewController {
    
    
    @IBOutlet weak var userView: UIView!
    @IBOutlet weak var SecondHighest: UILabel!
    @IBOutlet weak var Highest: UILabel!
    @IBOutlet weak var highest200ms: UILabel!
    @IBOutlet weak var secondHighest200ms: UILabel!
    
    var highSigFreq:Int?
    var secondSigFreq:Int?
    var lastHighestFrequency: Int? = nil
    var stableHighestStartTime: Date? = nil
    var lastSecondHighestFrequency: Int? = nil
    var stableStartTimeSecondHighest: Date? = nil
    
    
    
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 8192
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display
            // note that we need to normalize the scale of this graph
            // because the fft is returned in dB which has very large negative values and some large positive values
            
            
            graph.addGraph(withName: "fft",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            
            
            
            graph.makeGrids() // add grids to graph
        }
        
        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessingA(withFps: 20) // preferred number of FFT calculations per second
        
        audio.play()
                   
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
        
    }
    
    // periodically, update the graph with refreshed FFT Data
    func updateGraph(){
        
        if let graph = self.graph{
            graph.updateGraph(
                data: self.audio.fftData,
                forKey: "fft"
            )
            
        
            
                updateHighestFrequencyLabels()
            }
           
        
    }
    
  
    func updateHighestFrequencyLabels() {
        //Check if there's a max value in the fftData
        if let maxValue = self.audio.fftData.max(), maxValue < -0.5 {
            self.Highest.text = "Noise"
            self.SecondHighest.text = "Noise"
        } else if let maxValue = self.audio.fftData.max(),
                  let maxIndex = self.audio.fftData.firstIndex(of: maxValue) {

            //Calculate the frequency for the max value
            let frequencyMaxIndex: Int = maxIndex * 48000 / 8192
            self.Highest.text = String(frequencyMaxIndex)
            test200mslengthHighest(frequency: frequencyMaxIndex)

            // Step 3: Exclude indexes around maxIndex (±7)
            let startExcludeIndex = max(maxIndex - 6, 0)
            let endExcludeIndex = min(maxIndex + 6, self.audio.fftData.count - 1)

            // Filter out the values around maxIndex (±7)
            let filteredData = self.audio.fftData.enumerated().filter { (index, value) in
                return index < startExcludeIndex || index > endExcludeIndex
            }.map { $0.element } // Extract the values from the enumerated result

            // Step 4: Find the second highest value and its index
            if let secondMaxValue = filteredData.max(),
               let secondMaxIndexInFiltered = filteredData.firstIndex(of: secondMaxValue) {
                
                // We need to adjust the index to account for the excluded range
                let secondMaxIndex = secondMaxIndexInFiltered >= startExcludeIndex ?
                                     secondMaxIndexInFiltered + (endExcludeIndex - startExcludeIndex + 1) :
                                     secondMaxIndexInFiltered

                // Calculate the frequency for the second highest value
                let frequencySecondMaxIndex: Int = secondMaxIndex * 48000 / 8192
                self.SecondHighest.text = String(frequencySecondMaxIndex)
                test200mslengthSecondHighest(frequency: frequencySecondMaxIndex)
            }
        }
    }
    
    func test200mslengthHighest(frequency: Int) {
       
        let currentTime = Date()
        
        // Check if frequency is the same as the previous one
        if frequency == lastHighestFrequency {
            // If we haven't already started timing, set the start time
            if stableHighestStartTime == nil {
                stableHighestStartTime = currentTime
            }
            
            // Check if the frequency has been stable for at least 0.2 seconds
            if let startTime = stableHighestStartTime, currentTime.timeIntervalSince(startTime) >= 0.18 {
                // Frequency is stable for over 200 ms, update the label
                self.highest200ms.text = String(frequency)
            }
        } else {
            // If the frequency changed, reset the tracking variables
            lastHighestFrequency = frequency
            stableHighestStartTime = nil // Reset start time since the frequency changed
        }
    }
    
    func test200mslengthSecondHighest(frequency: Int) {
            let currentTime = Date()

            // Handle second-highest frequency
            if frequency == lastSecondHighestFrequency {
                // If we haven't already started timing for the second-highest frequency, set the start time
                if stableStartTimeSecondHighest == nil {
                    stableStartTimeSecondHighest = currentTime
                }
                
                // Check if the second-highest frequency has been stable for at least 0.1 seconds
                if let startTime = stableStartTimeSecondHighest, currentTime.timeIntervalSince(startTime) >= 0.1 {
                    // Frequency is stable for over 100 ms, update the label (we changed this to 0.1 to lower the threshold because there are a lot of calculations going on before this timer
                    self.secondHighest200ms.text = String(frequency)
                }
            } else {
                // If the second-highest frequency changed, reset the tracking variables
                lastSecondHighestFrequency = frequency
                stableStartTimeSecondHighest = nil // Reset start time since the frequency changed
            }
        }

    
        

}
