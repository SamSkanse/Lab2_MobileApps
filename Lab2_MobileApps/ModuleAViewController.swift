//
//  ViewController.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//

/*TODO!!! figure out how to call the function getFundamentalPeaksFromBuffer in order to get the peaks to
 to output to labels
 */


import UIKit
import Metal





class ModuleAViewController: UIViewController {
    
    
    @IBOutlet weak var userView: UIView!
    @IBOutlet weak var SecondHighest: UILabel!
    @IBOutlet weak var Highest: UILabel!
    
    let peakFinder = PeakFinder(frequencyResolution: 44100.0)
    
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
        audio.startMicrophoneProcessing(withFps: 20) // preferred number of FFT calculations per second
        
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
//            peakFinder?.getFundamentalPeaks(fromBuffer: <#T##UnsafeMutablePointer<Float>!#>, withLength: <#T##UInt#>, usingWindowSize: <#T##UInt#>, andPeakMagnitudeMinimum: <#T##Float#>, aboveFrequency: <#T##Float#>)
            }
           
        
    }
    
  
    
    func updateHighestFrequencyLabels() {
        // Step 1: Check if there's a max value in the fftData
        if let maxValue = self.audio.fftData.max(), maxValue < -0.5 {
            self.Highest.text = "Noise"
            self.SecondHighest.text = "Noise"
        } else if let maxValue = self.audio.fftData.max(),
                  let maxIndex = self.audio.fftData.firstIndex(of: maxValue) {

            // Step 2: Calculate the frequency for the max value
            let frequencyMaxIndex: Int = maxIndex * 48000 / 8192
            self.Highest.text = String(frequencyMaxIndex)

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
            }
        }
    }

    
        

}
