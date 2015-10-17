#!/usr/bin/env swift -framework OptionKit -F Carthage/Build/Mac
import Cocoa
import CoreGraphics
import OptionKit

class Storage {
    private let DefaultTempDirName = "simrec"
    private var url : NSURL?
    
    init() {
        self.url = createTemporaryDirectory()
    }
    
    func createTemporaryDirectory() -> NSURL? {
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
    
    func writeToFile(image : CGImageRef, filename : String) -> NSData {
        let bitmapRep : NSBitmapImageRep = NSBitmapImageRep(CGImage: image)
        let fileURL : NSURL = NSURL(string: filename, relativeToURL: self.url)!
        let properties = Dictionary<String, AnyObject>()
        let data : NSData = bitmapRep.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: properties)!
        if !data.writeToFile(fileURL.path!, atomically: false) {
            print("write to file failed")
        }
        return data
    }
}

class Converter {
    typealias ConvertFinishedCallback = (data: NSData?, succeed: Bool) -> ()
    
    func createGIF(with images: [NSImage], loopCount: Int = 0, frameDelay: Double, destinationURL : NSURL, callback : ConvertFinishedCallback?) {
        let fileProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: loopCount]]
        let frameProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: frameDelay]]
        
        let destination = CGImageDestinationCreateWithURL(destinationURL, kUTTypeGIF, images.count, nil)
        
        if let destination = destination {
            CGImageDestinationSetProperties(destination, fileProperties)
            
            for image in images {
                let imageRef : CGImageRef = self.createCGImageFromNSImage(image)!
                CGImageDestinationAddImage(destination, imageRef, frameProperties)
            }
            
            if CGImageDestinationFinalize(destination) {
                if let callback = callback {
                    callback(data: NSData(contentsOfURL: destinationURL), succeed: true)
                }
            } else {
                if let callback = callback {
                    callback(data: nil, succeed: false)
                }
            }
        }
    }
    
    private func createCGImageFromNSImage(image : NSImage) -> CGImageRef? {
        var imageRect:CGRect = CGRectMake(0, 0, image.size.width, image.size.height)
        let imageRef = image.CGImageForProposedRect(&imageRect, context: nil, hints: nil)
        return imageRef
    }
}

class Recorder {
    private var windowID : CGWindowID?
    private var frame : UInt = 0
    private var timer : NSTimer?
    private let storage : Storage = Storage()
    private let converter : Converter = Converter()
    private var images : [NSImage] = []
    var fps : UInt = 12
    var outputPath : String = "animation.gif"
    
    init() {
        self.windowID = self.simulatorWindowID()
    }

    private func simulatorWindowID() -> CGWindowID? {
        var windowIDs : [CGWindowID] = []
        
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
                    windowIDs.append(CGWindowID(windowIDNumber.intValue))
                }
            }
        }
        if windowIDs.count > 0 {
            return windowIDs.last;
        }
        return nil
    }
    
    func secPerFrame() -> Double {
        return 1.0 / Double(self.fps)
    }
    
    func outputURL() -> NSURL {
        return NSURL(string: self.outputPath)!
    }
    
    func isAttachSimulator() -> Bool {
        return self.windowID != nil
    }

    @objc private func takeScreenshot() {
        let imageRef : CGImageRef = CGWindowListCreateImage(CGRectNull, CGWindowListOption.OptionIncludingWindow, windowID!, CGWindowImageOption.BoundsIgnoreFraming)!
        let data : NSData = self.storage.writeToFile(imageRef, filename: "\(self.frame).png")
        ++self.frame
        let image = NSImage(data: data)
        if let image = image {
            self.images.append(image)
        }
    }
    
    func startCapture() {
        self.timer = NSTimer.scheduledTimerWithTimeInterval(self.secPerFrame(), target: self, selector: "takeScreenshot", userInfo: nil, repeats: true)
    }
    
    func endCapture(callback : Converter.ConvertFinishedCallback?) {
        self.timer?.invalidate()
        let destinationURL : NSURL = NSURL(fileURLWithPath: self.outputPath)
        self.converter.createGIF(with: self.images, frameDelay: self.secPerFrame(), destinationURL: destinationURL, callback: callback)
    }
}

class Command {
    typealias SignalCallback = (@convention(c) (Int32) -> Void)!

    static func execute(arguments : [String]) {
        let frameRateOption = Option(trigger: OptionTrigger.Mixed("f", "fps"), numberOfParameters: 1, helpDescription: "")
        let outputPathOption = Option(trigger: OptionTrigger.Mixed("o", "outputPath"), numberOfParameters: 1, helpDescription: "")
        
        let parser = OptionParser(definitions: [frameRateOption, outputPathOption])
        
        do {
            let (options, _) = try parser.parse(actualArguments)
            
            let recorder : Recorder = Recorder()
            if !recorder.isAttachSimulator() {
                print("iOS simulator seems not to launch")
                exit(EXIT_FAILURE)
            }
            
            if let frameRate = options[frameRateOption]?.first {
                recorder.fps = UInt(frameRate)!
            }
            
            if let outputPath = options[outputPathOption]?.first {
                recorder.outputPath = outputPath
            }
            
            let callback : @convention(block) (Int32) -> Void = { (Int32) -> Void in
                recorder.endCapture({ (data : NSData?, succeed : Bool) in
                    if succeed {
                        print("Gif animation generated")
                        exit(EXIT_SUCCESS)
                    } else {
                        print("Gif animation generation is failed")
                        exit(EXIT_FAILURE)
                    }
                })
            }
            
            // Convert Objective-C block to C function pointer
            let imp = imp_implementationWithBlock(unsafeBitCast(callback, AnyObject.self))
            signal(SIGINT, unsafeBitCast(imp, SignalCallback.self))
            recorder.startCapture()
            autoreleasepool {
                NSRunLoop.currentRunLoop().run()
            }
            
        } catch {
        }
    }
}

let actualArguments = Array(Process.arguments[1..<Process.arguments.count])

Command.execute(actualArguments)

