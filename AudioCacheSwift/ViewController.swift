//
//  ViewController.swift
//  AudioCacheSwift
//
//  Created by RYOKATO on 2015/04/12.
//  Copyright (c) 2015年 Denkinovel. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices

var playSongContext = "playSongContext"

class ViewController: UIViewController, AVAssetResourceLoaderDelegate, NSURLConnectionDataDelegate {
    var musicPlayer: AVPlayer?
    var musicPlayerItems = [AVPlayerItem]()
    var isObserving = false
    var pendingRequests = [AVAssetResourceLoadingRequest]()
    var songData = NSMutableData()
    var response: NSURLResponse?
    var connection: NSURLConnection?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func songURL() -> NSURL {
        let url = NSURL(string:"http://sampleswap.org/mp3/artist/earthling/Chuck-Silva_Ninety-Nine-Percent-320.mp3")
        return url!
    }
    
    private func songURLWithCustomScheme(scheme: String) -> NSURL {
        var components = NSURLComponents(URL: self.songURL(), resolvingAgainstBaseURL: false)!
        components.scheme = scheme
        return components.URL!
    }
    
    @IBAction func buttonPushed(sender: AnyObject) {
        playSong()
    }
    private func playSong() {
        var asset = AVURLAsset(URL: self.songURLWithCustomScheme("streaming"), options: nil)
        asset.resourceLoader.setDelegate(self, queue: dispatch_get_main_queue())
        self.pendingRequests = []
        var playerItem = AVPlayerItem(asset: asset)
        self.musicPlayer = AVPlayer(playerItem: playerItem)
        playerItem.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.New, context: &playSongContext)
    }
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        self.songData = NSMutableData()
        self.response = response as! NSHTTPURLResponse
        self.processPendingRequests()
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.songData.appendData(data)
        self.processPendingRequests()
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        self.processPendingRequests()
        let cachedFilePath = NSTemporaryDirectory().stringByAppendingPathComponent("cached.mp3")
        self.songData.writeToFile(cachedFilePath, atomically: true)
    }
    
    func processPendingRequests() {
        var requestsCompleted = [AVAssetResourceLoadingRequest]()
        for loadingRequest in self.pendingRequests {
            self.fillInContentInformation(loadingRequest.contentInformationRequest)
       /*     println("\n")
            println("requestedLength\n")
            println(CLong(loadingRequest.dataRequest.requestedLength))
            println("\n")
        */
            let didRespondCompetely = self.respondWithDataForRequest(loadingRequest.dataRequest)
            if didRespondCompetely {
                requestsCompleted.append(loadingRequest)
                println(loadingRequest.contentInformationRequest)
                loadingRequest.finishLoading()
            }
        }
        for requestCompleted in requestsCompleted {
            for (i, pendingRequest) in enumerate(self.pendingRequests) {
              /*  println("pendingRequest is")
                println(pendingRequest)
                
                println("\n")
                
                println("requestsCompleted")
                println(requestsCompleted)
*/
                if requestCompleted == pendingRequest {
                    self.pendingRequests.removeAtIndex(i)
                }
            }
        }
    }
    
    func fillInContentInformation(contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?) {
        if(contentInformationRequest == nil) {
            return
        }
        if (self.response == nil) {
            return
        }
        
        let mimeType = self.response!.MIMEType
        var unmanagedContentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, mimeType, nil)
        var cfContentType = unmanagedContentType.takeRetainedValue()
        contentInformationRequest!.contentType = String(cfContentType)
        contentInformationRequest!.byteRangeAccessSupported = true
        contentInformationRequest!.contentLength = self.response!.expectedContentLength
    }
    
    func respondWithDataForRequest(dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
        var startOffset = dataRequest.requestedOffset
        if dataRequest.currentOffset != 0 {
            startOffset = dataRequest.currentOffset
        }
        //println("startOffset")
        //println(startOffset)
        let songDataLength = Int64(self.songData.length)
        if songDataLength < startOffset {
            return false
        }
        let unreadBytes = songDataLength - startOffset
       /*
        println("unreadBytes")
        println(unreadBytes)
    
        println("dataRequest.requestedLength")
        println(dataRequest.requestedLength)
        
        println("\n\n")
*/
        
        let numberOfBytesToRespondWith: Int64
        if Int64(dataRequest.requestedLength) > unreadBytes {
            numberOfBytesToRespondWith = unreadBytes
        } else {
            numberOfBytesToRespondWith = Int64(dataRequest.requestedLength)
        }
        dataRequest.respondWithData(self.songData.subdataWithRange(NSMakeRange(Int(startOffset), Int(numberOfBytesToRespondWith))))
        let endOffset = startOffset + dataRequest.requestedLength
        let didRespondFully = songDataLength >= endOffset
        return didRespondFully
    }
    
    func resourceLoader(resourceLoader: AVAssetResourceLoader!, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest!) -> Bool {
        if self.connection == nil {
            let interceptedURL = loadingRequest.request.URL
            var actualURLComponents = NSURLComponents(URL: interceptedURL!, resolvingAgainstBaseURL: false)
            actualURLComponents!.scheme = "http"
            
            let request = NSURLRequest(URL: actualURLComponents!.URL!)
            self.connection = NSURLConnection(request: request, delegate: self, startImmediately: false)
            self.connection!.setDelegateQueue(NSOperationQueue.mainQueue())
            self.connection!.start()
        }
        println(loadingRequest)
        println("shouldWaitFor")
        println("\n")
        self.pendingRequests.append(loadingRequest)
        return true
    }
    
    func resourceLoader(resourceLoader: AVAssetResourceLoader!, didCancelLoadingRequest loadingRequest: AVAssetResourceLoadingRequest!) {
        for (i, pendingRequest) in enumerate(self.pendingRequests) {
            if pendingRequest == pendingRequests[i] {
                pendingRequests.removeAtIndex(i)
            }
        }
        pendingRequests = []
       // println("removeRequest")
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if self.musicPlayer!.currentItem.status == AVPlayerItemStatus.ReadyToPlay {
            if keyPath == "status" {
                musicPlayer!.play()
            }
        }
    }
}



