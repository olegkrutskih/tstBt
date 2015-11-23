//
//  AVSpeechSynthesizer.swift
//  tstAVS
//
//  Created by Круцких Олег on 23.11.15.
//  Copyright © 2015 Круцких Олег. All rights reserved.
//

import Foundation
import AVFoundation

class AVSS: AVSpeechSynthesizer {
    
    var synthesier: AVSpeechSynthesizer
    //var listener: avspee
    var utterance: AVSpeechUtterance
    var session: AVAudioSession
    
    override init() {
        
        self.synthesier = AVSpeechSynthesizer()
        
        self.utterance = AVSpeechUtterance(string: "Hello")
        
        self.session = AVAudioSession.sharedInstance()
        try! self.session.setCategory(AVAudioSessionCategoryPlayback)
        try! self.session.setActive(true)
            
        super.init()
        
    }
    
    func say(toSay: String) {
        
        self.utterance = AVSpeechUtterance(string: toSay)
        self.synthesier.speakUtterance(self.utterance)
        
    }
    
    func listen(){
        //self.
    }
    
    
    
    
}
