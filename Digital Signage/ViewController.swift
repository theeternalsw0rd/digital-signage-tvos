//
//  ViewController.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/17/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import UIKit
import FileKit
import AVKit
import AVFoundation
import SwiftyJSON

class ViewController: UIViewController {
    private var url = NSURL()
    private var slideshow : [SlideshowItem] = []
    private var slideshowLoader : [SlideshowItem] = []
    private var countdowns : [Countdown] = []
    private var slideshowLength = 0
    private var currentSlideIndex = -1
    private var timer = NSTimer()
    private var updateTimer = NSTimer()
    private var countdownTimer = NSTimer()
    private var updateReady = false
    private var initializing = true
    private var animating = false
    private let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    private var applicationSupport = Path(NSTemporaryDirectory())
    private let downloadQueue = NSOperationQueue()
    
    
    @IBOutlet weak var countdown: UILabel!
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var addressBox: UITextField!
    @IBOutlet weak var label: UILabel!
    @IBAction func goButtonAction(sender: AnyObject) {
        let urlString = self.addressBox.text
        NSUserDefaults.standardUserDefaults().setObject(urlString, forKey: "url")
        self.loadSignage(urlString!)
    }
    
    func resetView() {
        self.appDelegate.backgroundThread(background: {
            while(self.animating) {
                usleep(10000)
            }
        }, completion: {
            self.stopSlideshow()
            self.stopUpdater()
            self.stopCountdowns()
            self.countdown.hidden = true
            let urlString = NSUserDefaults.standardUserDefaults().stringForKey("url")
            self.initializing = true
            self.releaseOtherViews(nil)
            self.label.hidden = false
            self.addressBox.hidden = false
            if(urlString != nil) {
                self.addressBox.text = urlString!
            }
            self.addressBox.becomeFirstResponder()
            self.goButton.hidden = false
        })
    }
    
    private func loadSignage(urlString: String) {
        self.setUpdateTimer()
        if let _url = NSURL(string: urlString) {
            self.url = _url
            getJSON()
            self.setCountdowns()
        }
        else {
            let alert = UIAlertController(title: "Error", message: "URL appears to be malformed.", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .Default) { _ in })
            self.presentViewController(alert, animated: true){}
        }
    }
    
    func backgroundUpdate(timer:NSTimer) {
        self.showNextSlide()
    }
    
    private func releaseOtherViews(imageView: UIView?) {
        for view in self.view.subviews {
            // hide views that need to retain properties
            if(view != imageView && view != self.countdown && !(view.hidden)) {
                view.removeFromSuperview()
            }
        }
    }
    
    private func playVideo(uri: NSURL) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            let videoView = UIView()
            let frameSize = CGSize(width: 1920, height: 1080)
            let boundsSize = CGSize(width: 1920, height: 1080)
            videoView.frame.size = frameSize
            videoView.bounds.size = boundsSize
            let player = AVPlayer(URL: uri)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = videoView.frame
            playerLayer.videoGravity = AVLayerVideoGravityResize
            videoView.layer.addSublayer(playerLayer)
            videoView.alpha = 0
            self.view.insertSubview(videoView, belowSubview: self.countdown)
            let time = CMTimeMake(0, 1)
            player.seekToTime(time)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerDidFinishPlaying:", name: AVPlayerItemDidPlayToEndTimeNotification, object: player.currentItem)
            self.view.layoutIfNeeded()
            UIView.animateWithDuration(2.0, animations: { videoView.alpha = 1.0}, completion: { (finished: Bool) -> Void in
                player.play()
            })
        })
    }
    
    private func createImageView(image: UIImage, thumbnail: Bool) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            let imageView = UIImageView()
            imageView.contentMode = .ScaleAspectFill
            imageView.removeConstraints(imageView.constraints)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.alpha = 0
            imageView.image = image
            imageView.frame.size = CGSize(width: 1920, height: 1080)
            self.view.insertSubview(imageView, belowSubview: self.countdown)
            self.animating = true
            self.view.layoutIfNeeded()
            UIView.animateWithDuration(2.0, animations: { imageView.alpha = 1.0}, completion: { (finished: Bool) -> Void in
                self.releaseOtherViews(imageView)
                if(thumbnail) {
                    let item = self.slideshow[self.currentSlideIndex]
                    let path = item.path.rawValue
                    let uri = NSURL(fileURLWithPath: path)
                    self.playVideo(uri)
                }
                else {
                    self.setTimer()
                }
                self.animating = false
            })
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
            if(type == "image") {
                let image = UIImage(contentsOfFile: path)
                self.createImageView(image!, thumbnail: false)
            }
            else if(type == "video") {
                let uri = NSURL(fileURLWithPath: path)
                self.playVideo(uri)
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
    
    private func stopUpdater() {
        dispatch_async(dispatch_get_main_queue(),{
            self.updateTimer.invalidate()
        })
    }
    
    private func stopCountdowns() {
        dispatch_async(dispatch_get_main_queue(),{
            self.countdownTimer.invalidate()
        })
    }
    
    private func setCountdowns() {
        dispatch_async(dispatch_get_main_queue(),{
            self.countdownTimer.invalidate()
            self.countdownTimer = NSTimer(timeInterval: 0.1, target: self, selector: "updateCountdowns", userInfo: nil, repeats: true)
            NSRunLoop.currentRunLoop().addTimer(self.countdownTimer, forMode: NSRunLoopCommonModes)
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
                usleep(100000)
            }
        }, completion: {
            if(self.initializing) {
                self.initializing = false
                self.goButton.hidden = true
                self.addressBox.resignFirstResponder()
                self.addressBox.hidden = true
                self.label.hidden = true
                self.view.becomeFirstResponder()
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
    
    func getDayOfWeek(date: NSDate)->Int? {
        let myCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
        let myComponents = myCalendar?.components(NSCalendarUnit.Weekday, fromDate: date)
        let weekDay = myComponents?.weekday
        return weekDay
    }
    
    func updateCountdowns() {
        let date = NSDate()
        let currentDay = getDayOfWeek(date)
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([NSCalendarUnit.Hour, NSCalendarUnit.Minute, NSCalendarUnit.Second], fromDate: date)
        let seconds = components.hour * 3600 + components.minute * 60 + components.second
        var hide = true
        for countdown in self.countdowns {
            if(countdown.day != currentDay || countdown.duration > countdown.minute + countdown.hour * 60) {
                continue
            }
            let countdownSeconds = countdown.hour * 3600 + countdown.minute * 60
            let difference = countdownSeconds - seconds
            if(difference > 0 && difference <= countdown.duration * 60) {
                var minuteString = ""
                var secondString = ""
                hide = false
                let minuteDifference = Int(difference / 60)
                let secondDifference = difference % 60
                if(minuteDifference < 10) {
                    minuteString = "0" + String(minuteDifference)
                }
                else {
                    minuteString = String(minuteDifference)
                }
                if(secondDifference < 10) {
                    secondString = "0" + String(secondDifference)
                }
                else {
                    secondString = String(secondDifference)
                }
                self.countdown.text = minuteString + ":" + secondString
                break
            }
        }
        self.countdown.hidden = hide
    }
    
    func update() {
        self.getJSON()
    }
    
    private func generateCountdowns(countdowns: [JSON]) {
        self.countdowns = []
        for countdown in countdowns {
            let day = countdown["day"].stringValue
            let hour = countdown["hour"].stringValue
            let minute = countdown["minute"].stringValue
            let duration = countdown["duration"].stringValue
            let newCountdown = Countdown(day: day, hour: hour, minute: minute, duration: duration)
            self.countdowns.append(newCountdown)
        }
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
                if let countdowns = json["countdowns"].array {
                    self.generateCountdowns(countdowns)
                }
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
                                            NSLog("Path :" + cachePath.rawValue + "\n\n\n\n\n\n")
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
                        var message = ""
                        if let dataString = String(data: dumpData!, encoding: NSUTF8StringEncoding) {
                            message = "Couldn't load any items.\n" + dataString
                        }
                        else {
                            message = "Couldn't load any items."
                        }
                        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: .Default) { _ in })
                        self.presentViewController(alert, animated: true){}
                    }
                }
                else {
                    let alert = UIAlertController(title: "Error", message: "Couldn't process data.", preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: "Ok", style: .Default) { _ in })
                    self.presentViewController(alert, animated: true){}
                }
            }
            else {
                if(self.initializing) {
                    if let cachedData = NSData(contentsOfFile: String(jsonLocation)) {
                        let json = JSON(data: cachedData)
                        if let countdowns = json["countdowns"].array {
                            self.generateCountdowns(countdowns)
                        }
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
                        let alert = UIAlertController(title: "Error", message: "Couldn't load data.", preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: .Default) { _ in })
                        self.presentViewController(alert, animated: true){}
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
        self.countdown.hidden = true
        self.countdown.alpha = 0.7
    }
    
    override func pressesBegan(presses: Set<UIPress>, withEvent event: UIPressesEvent?) {
        if(presses.first?.type == UIPressType.Menu) {
            self.resetView()
        } else {
            // perform default action (in your case, exit)
            super.pressesBegan(presses, withEvent: event)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        if let urlString = NSUserDefaults.standardUserDefaults().stringForKey("url") {
            self.loadSignage(urlString)
        }
        if(self.addressBox.isDescendantOfView(self.view)) {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.addressBox.becomeFirstResponder()
            })
        }
    }
}