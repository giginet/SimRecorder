#!/usr/bin/env swift

import Cocoa

class Recorder {

    var windowID : CGWindowID?
    var frame : UInt = 0
    
    init()
    {
        self.searchWindowID()
    }

    func writeToFile(image : CGImageRef, path : String) {
        let bitmapRep : NSBitmapImageRep = NSBitmapImageRep(CGImage: image)
        let properties = Dictionary<String, AnyObject>()
        let data : NSData = bitmapRep.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: properties)!
        data.writeToFile(path, atomically: false)
    }

    func createTemporaryDirectory() -> NSURL?
    {
        let url : NSURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
        let pathURL : NSURL = url.URLByAppendingPathComponent("simrec")
        let fileManager = NSFileManager.defaultManager()
        do {
            try fileManager.createDirectoryAtURL(pathURL, withIntermediateDirectories: true, attributes: nil)
            return pathURL
        } catch {
            return nil
        }
    }

    func searchWindowID()
    {
        let simulators : [NSRunningApplication] = NSWorkspace.sharedWorkspace().runningApplications.filter({
            (app : NSRunningApplication) in
            return app.bundleIdentifier == "com.apple.iphonesimulator"
        })
        if (simulators.count > 0) {
            let simulator : NSRunningApplication = simulators.first!
            
            let windowArray : CFArrayRef = CGWindowListCopyWindowInfo(CGWindowListOption.OptionOnScreenOnly, 0)!
            let windows : NSArray = windowArray as NSArray
            for window in windows
            {
                let dict = window as! Dictionary<String, AnyObject>
                let windowIDNumber : NSNumber = dict["kCGWindowNumber"] as! NSNumber
                let ownerPID : NSNumber = dict["kCGWindowOwnerPID"] as! NSNumber
                if ownerPID.intValue == Int32(simulator.processIdentifier)
                {
                    self.windowID = CGWindowID(windowIDNumber.intValue)
                }
            }
        }
    }

    func takeScreenshot()
    {
        let rect : CGRect = CGRectNull
        let imageRef : CGImageRef = CGWindowListCreateImage(rect, CGWindowListOption.OptionIncludingWindow, windowID!, CGWindowImageOption.Default)!
        writeToFile(imageRef, path: "/Users/giginet/Desktop/ss\(self.frame).png")
        ++self.frame
    }
    
    func takeScreenshots() {
        NSTimer.scheduledTimerWithTimeInterval(0.2, target: self, selector: "takeScreenshot", userInfo: nil, repeats: true)
    }
    
}

let recorder : Recorder = Recorder()
while true {
    sleep(1)
    recorder.takeScreenshot()
}