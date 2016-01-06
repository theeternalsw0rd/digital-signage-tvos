//
//  Downloader.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/22/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import Foundation
import AppKit
import FileKit
import Alamofire

class Downloader: NSOperation {
    let item: SlideshowItem
    
    init(item: SlideshowItem) {
        self.item = item
        super.init()
    }
    
    override func main() {
        let destination: (NSURL, NSHTTPURLResponse) -> (NSURL) = {
            (temporaryURL, response) in
            let destinationURL = NSURL(fileURLWithPath: self.item.path.rawValue, isDirectory: false)
            return destinationURL
        }
        Alamofire.download(Alamofire.Method.GET, self.item.url.absoluteString, destination: destination)
        .response { _, _, _, error in
            if let error = error {
                NSLog("Failed with error: %@", error)
                self.item.status = -1
            } else {
                self.item.status = 1
                NSLog("Downloaded %@", self.item.path.rawValue)
            }
        }
        while(self.item.status == 0) {
            usleep(100000)
        }
    }
}