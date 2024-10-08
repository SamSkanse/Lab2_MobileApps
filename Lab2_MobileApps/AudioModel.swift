//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//



import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    var timeData:[Float]
    var fftData:[Float]
    var anotherData: [Float]  // New 20-point array property
    private var volume:Float = 1.0
    private var isPlaying = false
    
    lazy var samplingRate:Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        anotherData = Array(repeating: 0.0, count: 20)
    }
    
    // public function for starting processing of the audio file
    func startAudioFileProcessing(withFps: Double){
        if let manager = self.audioManager, let fileReader = self.fileReader {
            manager.outputBlock = self.handleSpeakerQueryWithAudioFile
            
            // Timer to process audio file data at specified FPS
            Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
            
            // Play the song through speakers
            manager.play()
            isPlaying = true
        }
    }
    
    func pause() {
        if let manager = self.audioManager {
            manager.pause()
            isPlaying = false
        }
    }
    
    private func calculateWindowedMaxima() {
        let windowSize = fftData.count / 20
        for i in 0..<20 {
            let start = i * windowSize
            let end = (i + 1) * windowSize
            let window = fftData[start..<min(end, fftData.count)]
            anotherData[i] = window.max() ?? 0.0  // Find max in the window
        }
    }
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var fileReader:AudioFileReader? = {
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3"){
            var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url,
                                                   samplingRate: Float(audioManager!.samplingRate),
                                                   numChannels: audioManager!.numOutputChannels)
            tmpFileReader!.currentTime = 0.0 // start from time zero!
            print("Audio file succesfully loaded for \(url)")
            return tmpFileReader
        } else {
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    private func runEveryInterval(){
        if let file = self.fileReader {
            // Get fresh audio data from file
            file.retrieveFreshAudio(&timeData, numFrames: UInt32(BUFFER_SIZE), numChannels: 1)
            
            // Perform FFT on the audio data
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            calculateWindowedMaxima()
        }
    }
    
    private func handleSpeakerQueryWithAudioFile(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32){
        if let file = self.fileReader, let arrayData = data {
            // Get samples from audio file, adjust volume
            file.retrieveFreshAudio(arrayData, numFrames: numFrames, numChannels: numChannels)
            vDSP_vsmul(arrayData, 1, &(self.volume), arrayData, 1, vDSP_Length(numFrames * numChannels))
        }
    }
}
