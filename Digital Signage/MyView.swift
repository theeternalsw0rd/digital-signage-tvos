//
//  MyView.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/27/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import Cocoa

class MyView: NSView {
    private var mouseTimer = NSTimer()
    var trackMouse = false
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
    }
    
    func hideCursor() {
        NSCursor.setHiddenUntilMouseMoves(true)
    }
    
    func setTimeout() {
        dispatch_async(dispatch_get_main_queue(),{
            self.mouseTimer.invalidate()
            self.mouseTimer = NSTimer(timeInterval: 5, target: self, selector: "hideCursor", userInfo: nil, repeats: false)
            NSRunLoop.currentRunLoop().addTimer(self.mouseTimer, forMode: NSRunLoopCommonModes)
        })
    }
    
    override func mouseMoved(theEvent: NSEvent) {
        if(!self.trackMouse) {
            return
        }
        self.setTimeout()
    }
}