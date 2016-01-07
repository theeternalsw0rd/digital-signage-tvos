//
//  Countdown.swift
//  Digital Signage
//
//  Created by Micah Bucy on 1/7/16.
//  Copyright © 2016 Micah Bucy. All rights reserved.
//

import Foundation
class Countdown {
    var day = 1
    var hour = 0
    var minute = 0
    var duration = 0
    
    init(day: String, hour: String, minute: String, duration: String) {
        if let _day = Int(day) {
            self.day = _day
        }
        if let _hour = Int(hour) {
            self.hour = _hour
        }
        if let _minute = Int(minute) {
            self.minute = _minute
        }
        if let _duration = Int(duration) {
            self.duration = _duration
        }
    }
    
    init(day: Int, hour: Int, minute: Int, duration: Int) {
        self.day = day
        self.hour = hour
        self.minute = minute
        self.duration = duration
    }
}