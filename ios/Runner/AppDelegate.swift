import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    // Key to store/retrieve bookmark data from UserDefaults
    let bookmarkKey = "ios_secure_bookmark"
    var secureURL: URL?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "com.noaisu.loliSnatcher/services",
                                           binaryMessenger: controller.binaryMessenger)
        
        // Restore bookmark access on launch
        restoreBookmarkAccess()
        
        channel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else { return }
            
            if call.method == "getSdkVersion" {
                // Not applicable for iOS, but needed to avoid exception if called
                result(0)
            } else if call.method == "saveIOSBookmark" {
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String {
                    if self.saveBookmark(path: path) {
                        result(true)
                    } else {
                        result(false)
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Path argument missing", details: nil))
                }
            } else if call.method == "releaseIOSBookmark" {
                self.releaseBookmarkAccess()
                result(true)
            } else if call.method == "getExtPath" {
               // If we have a custom secure URL, return its path, otherwise default documents
                if let safeURL = self.secureURL {
                    result(safeURL.path)
                } else {
                    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    result(paths[0].path)
                }
            } else if (call.method == "existsFileByName") {
                if let args = call.arguments as? [String: Any],
                   let uri = args["uri"] as? String,
                   let fileName = args["fileName"] as? String {
                    let url = URL(fileURLWithPath: uri).appendingPathComponent(fileName)
                    if FileManager.default.fileExists(atPath: url.path) {
                        result(true)
                    } else {
                        result(false)
                    }
                } else {
                    result(false)
                } 
            } else if (call.method == "testSAF") {
                 if let args = call.arguments as? [String: Any],
                   let path = args["uri"] as? String {
                     // Check if we have secure access to this path or if it is in our sandbox
                     let url = URL(fileURLWithPath: path)
                     // If it's the secure URL we restored/saved
                     if let secure = self.secureURL, secure.path == url.path {
                         result("ok")
                         return
                     }
                     
                     // Or check if we can write to it
                     if FileManager.default.isWritableFile(atPath: path) {
                         result("ok")
                     } else {
                         // Attempt to create a file to check
                         let testFile = url.appendingPathComponent("test_perm_check")
                         do {
                             try "test".write(to: testFile, atomically: true, encoding: .utf8)
                             try FileManager.default.removeItem(at: testFile)
                             result("ok")
                         } catch {
                             result("fail")
                         }
                     }
                 } else {
                     result("fail")
                 }
            } else {
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func saveBookmark(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            // Start accessing to create bookmark
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
                
                // Now start persistent access for this session
                return startAccessing(bookmarkData: bookmarkData)
            }
        } catch {
            print("Error creating bookmark: \(error)")
        }
        return false
    }
    
    func restoreBookmarkAccess() {
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            _ = startAccessing(bookmarkData: bookmarkData)
        }
    }
    
    func startAccessing(bookmarkData: Data) -> Bool {
        // Stop previous access if any
        releaseBookmarkAccess()
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                              options: .withoutUI,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("Bookmark is stale")
                // In a real app we might want to recreate it, but we need the original URL access first.
                // For now, try to use it.
            }
            
            if url.startAccessingSecurityScopedResource() {
                secureURL = url
                return true
            }
        } catch {
            print("Error resolving bookmark: \(error)")
        }
        return false
    }
    
    func releaseBookmarkAccess() {
        secureURL?.stopAccessingSecurityScopedResource()
        secureURL = nil
    }
}
