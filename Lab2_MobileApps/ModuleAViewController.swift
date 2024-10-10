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

    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    // Tracking the persistence of the top two frequencies
    var highestFrequency: Int?
    var secondHighestFrequency: Int?
    var highestFrequencyTimer: Timer?
    var secondHighestFrequencyTimer: Timer?
    let persistenceThreshold: TimeInterval = 0.2 // 200 ms

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            graph.addGraph(withName: "fft",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
            graph.makeGrids()
        }

        audio.startMicrophoneProcessingA(withFps: 20)
        audio.play()

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
    }

    func updateGraph() {
        if let graph = self.graph {
            graph.updateGraph(data: self.audio.fftData, forKey: "fft")
            updateHighestFrequencyLabels()
        }
    }

    func updateHighestFrequencyLabels() {
        guard let maxValue = self.audio.fftData.max(), maxValue >= -0.5 else {
            self.Highest.text = "Noise"
            self.SecondHighest.text = "Noise"
            return
        }

        if let maxIndex = self.audio.fftData.firstIndex(of: maxValue) {
            let frequencyMaxIndex: Int = maxIndex * 48000 / 8192
            handleFrequencyUpdate(frequency: frequencyMaxIndex, isHighest: true)

            let startExcludeIndex = max(maxIndex - 6, 0)
            let endExcludeIndex = min(maxIndex + 6, self.audio.fftData.count - 1)
            
            let filteredData = self.audio.fftData.enumerated().filter { (index, value) in
                return index < startExcludeIndex || index > endExcludeIndex
            }.map { $0.element }
            
            if let secondMaxValue = filteredData.max(),
               let secondMaxIndexInFiltered = filteredData.firstIndex(of: secondMaxValue) {
                let secondMaxIndex = secondMaxIndexInFiltered >= startExcludeIndex ?
                                     secondMaxIndexInFiltered + (endExcludeIndex - startExcludeIndex + 1) :
                                     secondMaxIndexInFiltered
                let frequencySecondMaxIndex: Int = secondMaxIndex * 48000 / 8192
                handleFrequencyUpdate(frequency: frequencySecondMaxIndex, isHighest: false)
            }
        }
    }

    private func handleFrequencyUpdate(frequency: Int, isHighest: Bool) {
        if isHighest {
            if highestFrequency == frequency {
                return
            }
            highestFrequency = frequency
            highestFrequencyTimer?.invalidate()
            highestFrequencyTimer = Timer.scheduledTimer(withTimeInterval: persistenceThreshold, repeats: false) { [weak self] _ in
                self?.Highest.text = String(frequency)
            }
        } else {
            if secondHighestFrequency == frequency {
                return
            }
            secondHighestFrequency = frequency
            secondHighestFrequencyTimer?.invalidate()
            secondHighestFrequencyTimer = Timer.scheduledTimer(withTimeInterval: persistenceThreshold, repeats: false) { [weak self] _ in
                self?.SecondHighest.text = String(frequency)
            }
        }
    }
}

