//
//  ViewController.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/17/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import Cocoa
import FileKit
import AVKit
import AVFoundation
import SwiftyJSON

class ViewController: NSViewController {
    private var url = NSURL()
    private var slideshow : [SlideshowItem] = []
    private var slideshowLoader : [SlideshowItem] = []
    private var slideshowLength = 0
    private var currentSlideIndex = -1
    private var timer = NSTimer()
    private var updateTimer = NSTimer()
    private var updateReady = false
    private var initializing = true
    private var applicationSupport = Path.UserApplicationSupport + "/theeternalsw0rd/Digital Signage"
    private let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate
    private let downloadQueue = NSOperationQueue()
    
    @IBOutlet weak var button: NSButton!
    @IBOutlet weak var addressBox: NSTextField!
    @IBOutlet weak var label: NSTextField!
    @IBAction func loadSignage(sender: AnyObject) {
        self.setUpdateTimer()
        if(!Path(stringInterpolation: self.applicationSupport).exists) {
            do {
                try Path(stringInterpolation: self.applicationSupport).createDirectory()
            }
            catch {
                let alert = NSAlert()
                alert.messageText = "Could not create caching directory."
                alert.addButtonWithTitle("OK")
                let _ = alert.runModal()
                return
            }
        }
        let urlString = self.addressBox.stringValue
        if let _url = NSURL(string: urlString) {
            self.url = _url
            getJSON()
        }
        else {
            let alert = NSAlert()
            alert.messageText = "URL appears to be malformed."
            alert.addButtonWithTitle("OK")
            let _ = alert.runModal()
        }
    }
    
    func backgroundUpdate(timer:NSTimer) {
        self.showNextSlide()
    }
    
    private func playVideo(frameSize: NSSize, boundsSize: NSSize, uri: NSURL) {
        let videoView = NSView()
        videoView.frame.size = frameSize
        videoView.bounds.size = boundsSize
        videoView.wantsLayer = true
        videoView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawPolicy.OnSetNeedsDisplay
        let player = AVPlayer(URL: uri)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = AVLayerVideoGravityResize
        videoView.layer = playerLayer
        videoView.layer?.backgroundColor = CGColorCreateGenericRGB(0, 0, 0, 0)
        self.view.addSubview(videoView, positioned: NSWindowOrderingMode.Above, relativeTo: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerDidFinishPlaying:", name: AVPlayerItemDidPlayToEndTimeNotification, object: player.currentItem)
        player.play()
    }
    
    private func createImageView(image: NSImage, thumbnail: Bool, frameSize: NSSize, boundsSize: NSSize) {
        let imageView = MyImageView()
        imageView.removeConstraints(imageView.constraints)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alphaValue = 0
        if(thumbnail) {
            imageView.image = image
        }
        else {
            imageView.imageWithSize(image, w: frameSize.width, h: frameSize.height)
        }
        imageView.frame.size = frameSize
        imageView.bounds.size = boundsSize
        imageView.wantsLayer = true
        imageView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawPolicy.OnSetNeedsDisplay
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.view.addSubview(imageView, positioned: NSWindowOrderingMode.Above, relativeTo: nil)
            NSAnimationContext.runAnimationGroup(
                { (context) -> Void in
                    context.duration = 1.0
                    imageView.animator().alphaValue = 1.0
                    
                }, completionHandler: { () -> Void in
                    for view in self.view.subviews {
                        if(view != imageView) {
                            view.removeFromSuperview()
                        }
                    }
                    if(thumbnail) {
                        let item = self.slideshow[self.currentSlideIndex]
                        let path = item.path.rawValue
                        let uri = NSURL(fileURLWithPath: path)
                        self.playVideo(frameSize, boundsSize: boundsSize, uri: uri)
                    }
                    else {
                        self.setTimer()
                    }
                }
            )
        })
    }
    
    private func showNextSlide() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            self.currentSlideIndex++
            if(self.currentSlideIndex == self.slideshowLength) {
                if(self.updateReady) {
                    self.updateSlideshow()
                    self.updateReady = false
                    return
                }
                self.currentSlideIndex = 0
            }
            let item = self.slideshow[self.currentSlideIndex]
            let type = item.type
            let path = item.path.rawValue
            let frameSize = self.view.frame.size
            let boundsSize = self.view.bounds.size
            if(type == "image") {
                let image = NSImage(contentsOfFile: path)
                self.createImageView(image!, thumbnail: false, frameSize: frameSize, boundsSize: boundsSize)
            }
            else if(type == "video") {
                let uri = NSURL(fileURLWithPath: path)
                let avAsset = AVURLAsset(URL: uri)
                let avAssetImageGenerator = AVAssetImageGenerator(asset: avAsset)
                let time = NSValue(CMTime: CMTimeMake(0, 1))
                avAssetImageGenerator.generateCGImagesAsynchronouslyForTimes([time],
                    completionHandler: {(_, image:CGImage?, _, _, error:NSError?) in
                        if(error == nil) {
                            self.createImageView(NSImage(CGImage: image!, size: frameSize), thumbnail: true, frameSize: frameSize, boundsSize: boundsSize)
                        }
                        else {
                            self.playVideo(frameSize, boundsSize: boundsSize, uri: uri)
                        }
                    }
                )
            }
            else {
                self.setTimer()
            }
        })
    }
    
    func playerDidFinishPlaying(note: NSNotification) {
        self.showNextSlide()
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    private func stopSlideshow() {
        dispatch_async(dispatch_get_main_queue(),{
            self.timer.invalidate()
        })
    }
    
    private func setUpdateTimer() {
        dispatch_async(dispatch_get_main_queue(),{
            self.updateTimer.invalidate()
            self.updateTimer = NSTimer(timeInterval: 30, target: self, selector: "update", userInfo: nil, repeats: false)
            NSRunLoop.currentRunLoop().addTimer(self.updateTimer, forMode: NSRunLoopCommonModes)
        })
    }
    
    private func setTimer() {
        dispatch_async(dispatch_get_main_queue(),{
            self.timer = NSTimer(timeInterval: 5.0, target: self, selector: "backgroundUpdate:", userInfo: nil, repeats: false)
            NSRunLoop.currentRunLoop().addTimer(self.timer, forMode: NSRunLoopCommonModes)
        })
    }
    
    private func startSlideshow() {
        self.showNextSlide()
    }
    
    private func downloadItems() {
        if(self.downloadQueue.operationCount > 0) {
            return
        }
        self.downloadQueue.suspended = true
        for item in self.slideshowLoader {
            if(Path(stringInterpolation: item.path).exists) {
                if(item.status == 1) {
                    continue
                }
                let fileManager = NSFileManager.defaultManager()
                do {
                    try fileManager.removeItemAtPath(item.path.rawValue)
                } catch {
                    NSLog("Could not remove existing file: %@", item.path.rawValue)
                    continue
                }
                let operation = Downloader(item: item)
                self.downloadQueue.addOperation(operation)
            }
            else {
                let operation = Downloader(item: item)
                self.downloadQueue.addOperation(operation)
            }
        }
        self.appDelegate.backgroundThread(background: {
            self.downloadQueue.suspended = false
            while(self.downloadQueue.operationCount > 0) {
            }
        }, completion: {
            if(self.initializing) {
                self.initializing = false
                self.button.removeFromSuperview()
                self.addressBox.resignFirstResponder()
                self.addressBox.removeFromSuperview()
                self.label.removeFromSuperview()
                self.view.becomeFirstResponder()
                if(!((self.view.window?.styleMask)! & NSFullScreenWindowMask == NSFullScreenWindowMask)) {
                    self.view.window?.toggleFullScreen(nil)
                }
                let view = self.view as! MyView
                view.trackMouse = true
                view.setTimeout()
                self.updateSlideshow()
            }
            else {
                self.updateReady = true
            }
        })
    }
    
    private func updateSlideshow() {
        self.stopSlideshow()
        self.slideshow = self.slideshowLoader
        self.slideshowLength = self.slideshow.count
        self.currentSlideIndex = -1
        self.slideshowLoader = []
        self.appDelegate.backgroundThread(
            background: {
                let items = self.slideshow
                let files = self.applicationSupport.find(searchDepth: 1) {
                    path in path.rawValue != self.applicationSupport.rawValue + "/json.txt"
                }
                for file in files {
                    var remove = true
                    for item in items {
                        if(item.path.rawValue == file.rawValue) {
                            remove = false
                            break
                        }
                    }
                    if(remove) {
                        let fileManager = NSFileManager.defaultManager()
                        do {
                            try fileManager.removeItemAtPath(file.rawValue)
                        } catch {
                            NSLog("Could not remove existing file: %@", file.rawValue)
                            continue
                        }
                    }
                }
            }, completion: {
                self.setUpdateTimer()
            }
        )
        self.startSlideshow()
    }
    
    func update() {
        self.getJSON()
    }
    
    private func getJSON() {
        if(self.updateReady) {
            // don't update while previous update in queue
            self.setUpdateTimer()
            return
        }
        let jsonLocation = self.applicationSupport + "/json.txt"
        let userAgent = "Digital Signage"
        let request = NSMutableURLRequest(URL: self.url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
            if error == nil {
                let dumpData = data
                var cachedJSON = JSON(data: dumpData!)
                if let cachedData = NSData(contentsOfFile: String(jsonLocation)) {
                    cachedJSON = JSON(data: cachedData)
                    if(dumpData!.isEqualToData(cachedData) && !self.initializing) {
                        self.setUpdateTimer()
                        NSLog("No changes")
                        return
                    }
                    if (!(dumpData!.writeToFile(jsonLocation.rawValue, atomically: true))) {
                        NSLog("Unable to write to file %@", jsonLocation.rawValue)
                    }
                }
                else {
                    if (!(dumpData!.writeToFile(jsonLocation.rawValue, atomically: true))) {
                        NSLog("Unable to write to file %@", jsonLocation.rawValue)
                    }
                }
                let json = JSON(data: dumpData!)
                if let items = json["items"].array {
                    let cachedItems = cachedJSON["items"].array
                    if(items.count > 0) {
                        self.slideshowLoader.removeAll()
                        for item in items {
                            if let itemUrl = item["url"].string {
                                if let itemNSURL = NSURL(string: itemUrl) {
                                    if let type = item["type"].string {
                                        if let filename = itemNSURL.lastPathComponent {
                                            let cachePath = Path(stringInterpolation: self.applicationSupport + "/" + filename)
                                            let slideshowItem = SlideshowItem(url: itemNSURL, type: type, path: cachePath)
                                            do {
                                                let fileAttributes = try NSFileManager.defaultManager().attributesOfItemAtPath(NSURL(fileURLWithPath: cachePath.rawValue, isDirectory: false).path!)
                                                let fileSize = fileAttributes[NSFileSize]
                                                for cachedItem in cachedItems! {
                                                    if(itemUrl == cachedItem["url"].stringValue) {
                                                        if(item["md5sum"] == cachedItem["md5sum"] && item["filesize"].stringValue == fileSize?.stringValue) {
                                                            slideshowItem.status = 1
                                                        }
                                                    }
                                                }
                                            }
                                            catch {
                                            }
                                            self.slideshowLoader.append(slideshowItem)
                                        }
                                        else {
                                            NSLog("Could not retrieve filename from url: %@", itemUrl)
                                        }
                                    }
                                    else {
                                        continue
                                    }
                                }
                                else {
                                    continue
                                }
                            }
                            else {
                                continue
                            }
                        }
                        self.downloadItems()
                    }
                    else {
                        let alert = NSAlert()
                        alert.messageText = "Couldn't load any items."
                        if let dataString = String(data: dumpData!, encoding: NSUTF8StringEncoding) {
                            alert.informativeText = dataString
                        }
                        alert.addButtonWithTitle("OK")
                        let _ = alert.runModal()
                    }
                }
                else {
                    let alert = NSAlert()
                    alert.messageText = "Couldn't process data."
                    alert.addButtonWithTitle("OK")
                    let _ = alert.runModal()
                }
            }
            else {
                if(self.initializing) {
                    if let cachedData = NSData(contentsOfFile: String(jsonLocation)) {
                        let json = JSON(data: cachedData)
                        if let items = json["items"].array {
                            if(items.count > 0) {
                                for item in items {
                                    if let itemUrl = item["url"].string {
                                        if let itemNSURL = NSURL(string: itemUrl) {
                                            if let type = item["type"].string {
                                                if let filename = itemNSURL.lastPathComponent {
                                                    let cachePath = Path(stringInterpolation: self.applicationSupport + "/" + filename)
                                                    if(cachePath.exists) {
                                                        let slideshowItem = SlideshowItem(url: itemNSURL, type: type, path: cachePath)
                                                        slideshowItem.status = 1
                                                        self.slideshowLoader.append(slideshowItem)
                                                    }
                                                }
                                                else {
                                                    NSLog("Could not retrieve filename from url: %@", itemUrl)
                                                }
                                            }
                                            else {
                                                continue
                                            }
                                        }
                                        else {
                                            continue
                                        }
                                    }
                                    else {
                                        continue
                                    }
                                }
                                self.downloadItems()
                            }
                        }
                    }
                    else {
                        let alert = NSAlert()
                        alert.messageText = "Couldn't load data."
                        alert.addButtonWithTitle("OK")
                        let _ = alert.runModal()
                    }
                }
                else {
                    NSLog("Offline")
                    self.setUpdateTimer()
                }
            }
        }
        task.resume()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.window?.acceptsMouseMovedEvents = true
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.addressBox.becomeFirstResponder()
        })
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}