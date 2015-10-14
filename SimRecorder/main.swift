#!/usr/bin/env swift

import Cocoa

func writeToFile(image : CGImageRef, path : String) {
    let bitmapRep : NSBitmapImageRep = NSBitmapImageRep(CGImage: image)
    let properties = Dictionary<String, AnyObject>()
    let data : NSData = bitmapRep.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: properties)!
    data.writeToFile(path, atomically: false)
}

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
        let windowID : NSNumber = dict["kCGWindowNumber"] as! NSNumber
        let ownerPID : NSNumber = dict["kCGWindowOwnerPID"] as! NSNumber
        if ownerPID.intValue == Int32(simulator.processIdentifier)
        {
            print(windowID)
            let windowID : CGWindowID = CGWindowID(windowID.intValue)
            let rect : CGRect = CGRectNull
            let imageRef : CGImageRef = CGWindowListCreateImage(rect, CGWindowListOption.OptionIncludingWindow, windowID, CGWindowImageOption.Default)!
            writeToFile(imageRef, path: "/Users/giginet/Desktop/test.png")
        }
    }
}
