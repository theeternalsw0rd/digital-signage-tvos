//
//  MyImageView.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/27/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//

import Cocoa

class MyImageView: NSImageView {
    
    func imageWithSize(path: String, w: CGFloat, h: CGFloat) {
        let image = NSImage(contentsOfFile: path)
        let destSize = NSMakeSize(w, h)
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        image!.drawInRect(NSMakeRect(0, 0, destSize.width, destSize.height), fromRect: NSMakeRect(0, 0, image!.size.width, image!.size.height), operation: NSCompositingOperation.CompositeSourceOver, fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = destSize
        self.image = NSImage(data: newImage.TIFFRepresentation!)!
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
    }
    
    override func mouseMoved(theEvent: NSEvent) {
        super.mouseMoved(theEvent)
    }
    
    override func updateTrackingAreas() {
        if(trackingAreas.count > 0) {
            for trackingArea in trackingAreas {
                removeTrackingArea(trackingArea)
            }
        }
        let options = NSTrackingAreaOptions.ActiveAlways.exclusiveOr(NSTrackingAreaOptions.MouseMoved)
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
}
