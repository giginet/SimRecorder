#!/usr/bin/env swift

import Cocoa

class Storage {
    private let DefaultTempDirName = "simrec"
    private var url : NSURL?;
    
    init() {
        self.url = createTemporaryDirectory()
    }
    
    func createTemporaryDirectory() -> NSURL?
    {
        let url : NSURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
        let pathURL : NSURL = url.URLByAppendingPathComponent(DefaultTempDirName)
        let fileManager = NSFileManager.defaultManager()
        do {
            try fileManager.createDirectoryAtURL(pathURL, withIntermediateDirectories: true, attributes: nil)
            return pathURL
        } catch {
            return nil
        }
    }
    
    func basePath() -> String? {
        return self.url?.absoluteString;
    }
    
    func writeToFile(image : CGImageRef, filename : String) {
        let bitmapRep : NSBitmapImageRep = NSBitmapImageRep(CGImage: image)
        let path : String = "\(self.basePath())/\(filename)"
        let properties = Dictionary<String, AnyObject>()
        let data : NSData = bitmapRep.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: properties)!
        data.writeToFile(path, atomically: false)
    }

}

class Recorder {
    var windowID : CGWindowID?
    var frame : UInt = 0
    let storage : Storage;
    
    init()
    {
        self.storage = Storage()
        self.windowID = self.simulatorWindowID()
    }

    func simulatorWindowID() -> CGWindowID?
    {
        let simulators : [NSRunningApplication] = NSWorkspace.sharedWorkspace().runningApplications.filter({
            (app : NSRunningApplication) in
            return app.bundleIdentifier == "com.apple.iphonesimulator"
        })
        if (simulators.count > 0) {
            let simulator : NSRunningApplication = simulators.first!
            
            let windowArray : CFArrayRef = CGWindowListCopyWindowInfo(CGWindowListOption.OptionOnScreenOnly, 0)!
            let windows : NSArray = windowArray as NSArray
            for window in windows {
                let dict = window as! Dictionary<String, AnyObject>
                let windowIDNumber : NSNumber = dict["kCGWindowNumber"] as! NSNumber
                let ownerPID : NSNumber = dict["kCGWindowOwnerPID"] as! NSNumber
                if ownerPID.intValue == Int32(simulator.processIdentifier) {
                    return CGWindowID(windowIDNumber.intValue)
                }
            }
        }
        return nil
    }
    
    func isAttachSimulator() -> Bool
    {
        return self.windowID != nil
    }

    func takeScreenshot()
    {
        let rect : CGRect = CGRectNull
        let imageRef : CGImageRef = CGWindowListCreateImage(rect, CGWindowListOption.OptionIncludingWindow, windowID!, CGWindowImageOption.Default)!
        self.storage.writeToFile(imageRef, filename: "\(self.frame).png")
        ++self.frame
    }
    
    func takeScreenshots() {
        NSTimer.scheduledTimerWithTimeInterval(0.2, target: self, selector: "takeScreenshot", userInfo: nil, repeats: true)
    }
}

class Command {
    static func execute()
    {
        let recorder : Recorder = Recorder()
        if !recorder.isAttachSimulator() {
            print("iOS simulator seems not to launch")
            exit(EXIT_FAILURE)
        }
        while true {
            let handler = NSFileHandle.fileHandleWithStandardInput()
            let inputData = handler.availableData
            let str = String(data: inputData, encoding: NSUTF8StringEncoding)
            print(str)
            sleep(1)
            recorder.takeScreenshot()
        }
    }
}

Command.execute()


