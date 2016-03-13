//
//  SlideshowItem.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/17/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import Foundation
import UIKit
import FileKit

class SlideshowItem: NSOperation {
    var url = NSURL()
    var type = "image"
    var image = UIImage()
    var path: Path
    var status = 0
    
    init(url: NSURL, type: String, path: Path) {
        self.url = url
        self.type = type
        self.path = path
    }
}