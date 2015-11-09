#!/usr/bin/env swift -framework OptionKit -F Carthage/Build/Mac
import Cocoa
import CoreGraphics
import OptionKit

extension NSImage {
    var CGImage: CGImageRef {
        get {
            let imageData = self.TIFFRepresentation
            let source = CGImageSourceCreateWithData(imageData!, nil)
            let maskRef = CGImageSourceCreateImageAtIndex(source!, 0, nil)!
            return maskRef;
        }
    }
}

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
    
    func createGIF(with images: [NSImage], quality: Float = 1.0, loopCount: UInt = 0, frameDelay: Double, destinationURL : NSURL, callback : ConvertFinishedCallback?) {
        let frameCount = images.count
        let animationProperties = 
        [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: loopCount], 
            kCGImageDestinationLossyCompressionQuality as String: quality]
        let frameProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: frameDelay, kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay]]
        
        let destination = CGImageDestinationCreateWithURL(destinationURL, kUTTypeGIF, frameCount, nil)
        if let destination = destination {
            CGImageDestinationSetProperties(destination, animationProperties)
            for var i = 0; i < frameCount; ++i {
                autoreleasepool {
                    let image = images[i];
                    CGImageDestinationAddImage(destination, image.CGImage, frameProperties)
                }
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
}

class Recorder {
    private var windowID : CGWindowID?
    private var frame: UInt = 0
    private var timer: NSTimer!
    private let storage: Storage = Storage()
    private let converter: Converter = Converter()
    private var images: [NSImage] = []
    var quality: Float = 1.0
    var fps: UInt = 5
    var outputPath: String = "animation.gif"
    var loopCount: UInt = 0
    
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
                let windowIDNumber: NSNumber = dict["kCGWindowNumber"] as! NSNumber
                let ownerPID: NSNumber = dict["kCGWindowOwnerPID"] as! NSNumber
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
        let newRef = removeAlpha(imageRef)
        let data : NSData = self.storage.writeToFile(newRef, filename: "\(self.frame).png")
        ++self.frame
        let image = NSImage(data: data)
        if let image = image {
            self.images.append(image)
        }
    }
    
    private func removeAlpha(imageRef: CGImageRef) -> CGImageRef {
        let width = CGImageGetWidth(imageRef)
        let height = CGImageGetHeight(imageRef)
        let bitmapContext: CGContextRef? = CGBitmapContextCreate(nil,
            width,
            height,
            CGImageGetBitsPerComponent(imageRef), 
            CGImageGetBytesPerRow(imageRef), 
            CGImageGetColorSpace(imageRef), 
            CGImageAlphaInfo.NoneSkipLast.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue)
        let rect: CGRect = CGRectMake(0, 0, CGFloat(width), CGFloat(height))
        if let bitmapContext = bitmapContext {
            CGContextDrawImage(bitmapContext, rect, imageRef);
            return CGBitmapContextCreateImage(bitmapContext)!
        }
        return imageRef
    }
    
    func startCapture() {
        self.timer = NSTimer.scheduledTimerWithTimeInterval(self.secPerFrame(), target: self, selector: "takeScreenshot", userInfo: nil, repeats: true)
    }
    
    func endCapture(callback : Converter.ConvertFinishedCallback?) {
        self.timer?.invalidate()
        let destinationURL : NSURL = NSURL(fileURLWithPath: self.outputPath)
        self.converter.createGIF(with: self.images, quality: self.quality, loopCount: self.loopCount, frameDelay: self.secPerFrame(), destinationURL: destinationURL, callback: callback)
    }
}

class Command {
    typealias SignalCallback = @convention(c) (Int32) -> Void

    static func execute(arguments : [String]) {
        let frameRateOption = Option(trigger: OptionTrigger.Mixed("f", "fps"), numberOfParameters: 1, helpDescription: "Recording frames per second")
        let outputPathOption = Option(trigger: OptionTrigger.Mixed("o", "outputPath"), numberOfParameters: 1, helpDescription: "Animation output path")
        let qualityOption = Option(trigger: OptionTrigger.Mixed("q", "quality"), numberOfParameters: 1, helpDescription: "Quality of animations 0.0 ~ 1.0")
        let loopCountOption = Option(trigger: OptionTrigger.Mixed("l", "loopCount"), numberOfParameters: 1, helpDescription: "Loop count of animations. if you passed 0, it animate eternally")
        
        let parser = OptionParser(definitions: [frameRateOption, outputPathOption, qualityOption])
        
        do {
            let (options, _) = try parser.parse(arguments)
            
            let recorder : Recorder = Recorder()
            guard recorder.isAttachSimulator() else {
                print("iOS simulator seems not to launch")
                exit(EXIT_FAILURE)
            }
            
            if let frameRate: UInt = options[frameRateOption]?.flatMap({ UInt($0) }).first {
                recorder.fps = frameRate
            }
            
            if let outputPath = options[outputPathOption]?.first {
                recorder.outputPath = outputPath
            }
            
            if let quality: Float = options[qualityOption]?.flatMap({ Float($0) }).first {
                recorder.quality = quality
            }
            
            if let loopCount: UInt = options[loopCountOption]?.flatMap({ UInt($0) }).first {
                recorder.loopCount = loopCount
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

