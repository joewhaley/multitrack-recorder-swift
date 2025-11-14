import Foundation
import SwiftUI
import AVFoundation
import Cocoa

// MARK: - Bookmark Store for Export Directory

enum BookmarkStore {
    static let key = "ExportDirectoryBookmarkData"
    
    static func save(url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: key)
        print("✅ Saved bookmark for: \(url.path)")
    }
    
    static func load() -> Data? {
        return UserDefaults.standard.data(forKey: key)
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        print("🗑️ Cleared export directory bookmark")
    }
    
    static func resolveBookmark() -> URL? {
        guard let bookmarkData = load() else { 
            print("⚠️ No bookmark data found")
            return nil 
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("🔄 Bookmark is stale, attempting to refresh...")
                // Try to refresh the bookmark
                do {
                    try save(url: url)
                    print("✅ Successfully refreshed stale bookmark")
                } catch {
                    print("❌ Failed to refresh stale bookmark: \(error)")
                    // If refresh fails, clear the bookmark and return nil
                    clear()
                    return nil
                }
            }
            
            // Test if we can actually access the directory
            if !url.startAccessingSecurityScopedResource() {
                print("❌ Failed to access security scoped resource: \(url.path)")
                clear()
                return nil
            }
            
            // Simple validation - check if the directory exists and is accessible
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            
            if exists && isDirectory.boolValue {
                //print("✅ Directory access verified: \(url.path)")
                return url
            } else {
                print("❌ Directory validation failed: \(url.path)")
                url.stopAccessingSecurityScopedResource()
                clear()
                return nil
            }
            
        } catch {
            print("❌ Failed to resolve bookmark: \(error)")
            // Clear the invalid bookmark
            clear()
            return nil
        }
    }
    
    static func stopAccessingResource(for url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

// Use PortAudio types directly from bridging header

// PortAudio device structure
struct PortAudioDevice: Identifiable, Hashable, Codable {
    let id: Int32  // Stable hash-based ID for UI and internal use
    let portAudioIndex: Int32  // PortAudio device index for stream operations
    let name: String
    let hostApi: String
    let maxInputChannels: Int
    let maxOutputChannels: Int
    let defaultLowInputLatency: Double
    let defaultSampleRate: Double
    var isSelected: Bool = false
}

class PortAudioManager: ObservableObject {
    @Published var inputDevices: [PortAudioDevice] = []
    @Published var audioLevels: [Int32: Float] = [:]
    @Published var waveformData: [Int32: [Float]] = [:]
    @Published var selectedDevices: Set<Int32> = [] // main
    @Published var updateCounter: Int = 0
    
    @Published private(set) var isRecording = false
    
    // Dedicated dispatch queue for file I/O operations
    private let fileIOQueue = DispatchQueue(label: "com.multitrack.recorder.fileio", qos: .userInitiated)
    
    private var portAudioStreams: [Int32: UnsafeMutableRawPointer] = [:] // main
    private var userDataPointers: [Int32: UnsafeMutableRawPointer] = [:] // main
    private var wavFileHandles: [Int32: FileHandle] = [:] // fileIOQueue
    
    // Device labels for user customization
    @Published var deviceLabels: [Int32: String] = [:]
    
    // Computed property for available devices
    var availableDevices: [PortAudioDevice] {
        return inputDevices
    }
    
    // Static reference for callback access
    private static var currentManager: PortAudioManager?
    
    // MARK: - Export Directory Management
    
    func chooseExportDirectory() {
        // Clear any existing invalid bookmarks first
        BookmarkStore.clear()
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Export Folder"
        panel.message = "Choose a folder where all recorded WAV files will be saved"
        
        if panel.runModal() == .OK, let dirURL = panel.url {
            do {
                try BookmarkStore.save(url: dirURL)
                print("✅ Successfully set export directory: \(dirURL.path)")
                
                // Verify access immediately
                if let verifiedDir = getExportDirectory() {
                    print("✅ Export directory access verified: \(verifiedDir.path)")
                } else {
                    print("❌ Failed to verify export directory access")
                }
            } catch {
                print("❌ Failed to create bookmark: \(error)")
            }
        } else {
            print("⚠️ No export directory selected")
        }
    }
    
    func getExportDirectory() -> URL? {
        guard let url = BookmarkStore.resolveBookmark() else {
            print("⚠️ No valid export directory available")
            return nil
        }
        
        // The bookmark is already validated and security scope is started in resolveBookmark
        // Just return the URL - the security scope will be managed by the calling code
        return url
    }
    
    // MARK: - Device Label Management
    
    func setDeviceLabel(_ label: String, for deviceID: Int32) {
        deviceLabels[deviceID] = label
    }
    
    func getDeviceLabel(for deviceID: Int32) -> String {
        return deviceLabels[deviceID] ?? ""
    }
    
    func clearDeviceLabel(for deviceID: Int32) {
        deviceLabels.removeValue(forKey: deviceID)
    }
    
    init() {
        // Set static reference for callback access
        PortAudioManager.currentManager = self
        
        let result = Int32(Pa_Initialize())
        if result == paNoError.rawValue {
            loadInputDevices()
        } else {
            print("Failed to initialize PortAudio: \(result)")
        }
    }
    
    deinit {
        // Clean up any remaining userData pointers
        for (_, userData) in userDataPointers {
            userData.deallocate()
        }
        userDataPointers.removeAll()
        
        // Clear static reference
        //PortAudioManager.currentManager = nil

        Pa_Terminate()
    }
    
    func loadInputDevices() {
        print("🔍 Loading input devices...")
        let deviceCount = Pa_GetDeviceCount()
        print("🔍 Total devices found: \(deviceCount)")
        
        var devices: [PortAudioDevice] = []
        
        for i in 0..<deviceCount {
            guard let deviceInfo = Pa_GetDeviceInfo(Int32(i)) else { 
                print("⚠️ Failed to get device info for device \(i)")
                continue 
            }
            
            let deviceName = String(cString: deviceInfo.pointee.name)
            let maxInputChannels = deviceInfo.pointee.maxInputChannels
            let maxOutputChannels = deviceInfo.pointee.maxOutputChannels
            let defaultLowInputLatency = deviceInfo.pointee.defaultLowInputLatency
            let defaultSampleRate = deviceInfo.pointee.defaultSampleRate

            print("🔍 Device \(i): '\(deviceName)' - Input: \(maxInputChannels), Output: \(maxOutputChannels), Default sample rate=\(defaultSampleRate)")

            // Only include input devices
            if maxInputChannels > 0 {
                // Get host API name
                let hostApiName: String
                if let hostApiInfo = Pa_GetHostApiInfo(deviceInfo.pointee.hostApi) {
                    hostApiName = String(cString: hostApiInfo.pointee.name)
                } else {
                    hostApiName = "Unknown"
                }
                
                // Create a stable device identifier using host API, device name, and PortAudio index
                // This ensures the ID remains consistent even when PortAudio device indices change
                // We include the PortAudio index to handle duplicate device names from different host APIs
                //let stableDeviceID = Int32(truncatingIfNeeded: (deviceName.hashValue ^ hostApiName.hashValue) + Int(i))
                let stableDeviceID = Int32(i)
                let device = PortAudioDevice(
                    id: stableDeviceID,
                    portAudioIndex: Int32(i),  // Store the PortAudio index for stream operations
                    name: deviceName,
                    hostApi: hostApiName,
                    maxInputChannels: Int(maxInputChannels),
                    maxOutputChannels: Int(maxOutputChannels),
                    defaultLowInputLatency: defaultLowInputLatency,
                    defaultSampleRate: defaultSampleRate
                )
                devices.append(device)
                print("✅ Added input device: '\(deviceName)' with stable ID: \(stableDeviceID) (PortAudio index: \(i))")
            } else {
                print("⏭️ Skipping device \(i) (no input channels)")
            }
        }
        
        print("🔍 Total input devices found: \(devices.count)")
        
        DispatchQueue.main.async {
            self.inputDevices = devices
            print("✅ Updated UI with \(devices.count) input devices")
        }
    }
    
    func refreshInputDevices() {
        assert(Thread.isMainThread, "refreshInputDevices() must be called on the main queue")
        print("🔄 Refreshing input device list...")
        
        // Stop any active streams before refreshing
        if isRecording {
            print("⚠️ Cannot refresh while recording - stopping recording first")
            stopRecording()
        }
        
        // Close any existing streams
        while let element = portAudioStreams.first {
            let deviceID = element.key
            stopRecordingDevice(deviceID: deviceID)
        }

        // Clear audio buffers, levels, and selected devices
        audioLevels.removeAll()
        waveformData.removeAll()
        selectedDevices.removeAll()

        // Terminate PortAudio to clean up device list
        Pa_Terminate()
        print("🔄 Terminated PortAudio for device refresh")
        
        // Re-initialize PortAudio to get updated device list
        let result = Int32(Pa_Initialize())
        if result == paNoError.rawValue {
            print("✅ PortAudio re-initialized successfully")
            // Re-enumerate devices
            loadInputDevices()
        } else {
            print("❌ Failed to re-initialize PortAudio: \(result)")
        }
        
        print("✅ Input device list refreshed")
    }
    
    func toggleDeviceSelection(deviceID: Int32) {
        assert(Thread.isMainThread, "toggleDeviceSelection(deviceID:) must be called on the main queue")
        if selectedDevices.contains(deviceID) {
            selectedDevices.remove(deviceID)
        } else {
            selectedDevices.insert(deviceID)
        }
    }
    
    func isDeviceSelected(_ deviceID: Int32) -> Bool {
        assert(Thread.isMainThread, "isDeviceSelected(deviceID:) must be called on the main queue")
        return selectedDevices.contains(deviceID)
    }
    
    func getSelectedDeviceIndices() -> [Int32] {
        assert(Thread.isMainThread, "getSelectedDeviceIndices() must be called on the main queue")
        return Array(selectedDevices)
    }
    
    public func startRecordingDevice(deviceID: Int32) {
        assert(Thread.isMainThread, "startRecordingDevice(deviceID:) must be called on the main queue")
        
        // Add to selected devices if not already there
        if !selectedDevices.contains(deviceID) {
            selectedDevices.insert(deviceID)
        }
        
        // Start the audio stream for this device
        setupAudioUnit(deviceID: deviceID)
    }
    
    public func stopRecordingDevice(deviceID: Int32) {
        assert(Thread.isMainThread, "stopRecordingDevice(deviceID:) must be called on the main queue")

        // Stop and close the stream
        if let stream = portAudioStreams[deviceID] {
            Pa_StopStream(stream)
            Pa_CloseStream(stream)
            portAudioStreams.removeValue(forKey: deviceID)
        }
        
        // Free the allocated userData
        if let userData = userDataPointers[deviceID] {
            userData.deallocate()
            userDataPointers.removeValue(forKey: deviceID)
        }
        
        // Remove from selected devices
        selectedDevices.remove(deviceID)
        
        // Clear audio data for this device
        audioLevels.removeValue(forKey: deviceID)
        waveformData.removeValue(forKey: deviceID)
        
        print("Stopped recording for device \(deviceID)")
    }
    
    private func setupAudioUnit(deviceID: Int32) {
        assert(Thread.isMainThread, "setupAudioUnit(deviceID:) must be called on the main queue")
        guard let device = inputDevices.first(where: { $0.id == deviceID }) else { return }
        
        // Set up PortAudio stream parameters
        var inputParameters = PaStreamParameters()
        inputParameters.device = device.portAudioIndex  // Use the PortAudio index for stream operations
        inputParameters.channelCount = 1
        inputParameters.sampleFormat = paInt16  // Use 16-bit integer format instead of float
        inputParameters.suggestedLatency = device.defaultLowInputLatency
        inputParameters.hostApiSpecificStreamInfo = nil
        
        var stream: UnsafeMutableRawPointer?
        
        // Allocate userData for the callback (store the stable device ID)
        let userData = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<Int32>.size, alignment: MemoryLayout<Int32>.alignment)
        userData.assumingMemoryBound(to: Int32.self).pointee = deviceID  // Store stable ID for callback use

        let result = Pa_OpenStream(
            &stream,
            &inputParameters,
            nil, // No output parameters
            44100.0, // Sample rate
            256, // Frames per buffer
            paClipOff, // No clipping
            { (input, output, frameCount, timeInfo, statusFlags, userData) -> Int32 in
                // This is the C callback that will be called by PortAudio
                guard let userData = userData else { return paNoError.rawValue }
                let deviceID = userData.assumingMemoryBound(to: Int32.self).pointee
                
                // Get the manager from static reference
                guard let manager = PortAudioManager.currentManager else { return paNoError.rawValue }

                // Process the audio data
                guard let input = input else { return paNoError.rawValue }
                
                // Convert input data to Int16 array (16-bit integer samples)
                let int16Data = input.assumingMemoryBound(to: Int16.self)
                let samples = Array(UnsafeBufferPointer(start: int16Data, count: Int(frameCount)))
                
                // Add to recording buffer if recording (for waveform display)
                if manager.isRecording {
                    let samplesCopy = samples // Create a copy for the async operation
                    // Send audio data to file I/O queue for writing to WAV file
                    manager.fileIOQueue.async {
                        manager.streamAudioData(deviceID: deviceID, samples: samplesCopy)
                    }
                }
                
                // Calculate RMS level (convert to float for calculation)
                let floatSamples = samples.map { Float($0) / 32768.0 } // Convert Int16 to normalized float
                let sumSquares = floatSamples.map { $0 * $0 }.reduce(0, +)
                let rms = sqrt(sumSquares / Float(floatSamples.count))
                
                // Scale up very small values for better visualization, but keep in reasonable range
                let scaledRms = min(1.0, rms * 2.0) // Scale up by 2x but cap at 1.0

                // Update audio level on main thread
                DispatchQueue.main.async {
                    manager.audioLevels[deviceID] = scaledRms
                    manager.updateCounter += 1
                    // Force UI update by triggering objectWillChange
                    manager.objectWillChange.send()
                }
                
                // Update waveform data (downsample for display) with proper scaling
                let downsampledData = stride(from: 0, to: floatSamples.count, by: max(1, floatSamples.count / 100)).map { 
                    // Scale the samples but keep them in the -1.0 to 1.0 range
                    min(1.0, max(-1.0, floatSamples[$0] * 2.0))
                }
                
                DispatchQueue.main.async {
                    // Store the data
                    manager.waveformData[deviceID] = downsampledData
                    
                    // Force UI update by triggering objectWillChange
                    manager.objectWillChange.send()
                    
                    // Also increment update counter to force UI refresh
                    manager.updateCounter += 1
                }
                
                return paNoError.rawValue
            },
            userData
        )
        
        guard result == paNoError.rawValue else {
            print("Failed to open PortAudio stream for device \(deviceID): \(result)")
            return
        }
        
        // Start the stream
        let startResult = Pa_StartStream(stream)
        guard startResult == paNoError.rawValue else {
            print("Failed to start PortAudio stream for device \(deviceID): \(startResult)")
            Pa_CloseStream(stream)
            return
        }
        
        portAudioStreams[deviceID] = stream!
        userDataPointers[deviceID] = userData
    }
    
    // MARK: - Recording Methods
    
    public func startRecording() {
        isRecording = true
        print("Started recording for devices: \(selectedDevices)")
        
        // Get the export directory and ensure we have access
        guard let exportDir = getExportDirectory() else {
            print("❌ No export directory available - cannot start recording")
            isRecording = false
            return
        }
        
        // Initialize streaming WAV files for selected devices
        for deviceID in selectedDevices {
            let customLabel = getDeviceLabel(for: deviceID)
            let filename = customLabel.isEmpty ? 
                "device_\(deviceID)_recording.wav" : 
                "\(customLabel)_recording.wav"
            let fileURL = exportDir.appendingPathComponent(filename)
            
            fileIOQueue.sync {
                do {
                    // Create the file and write initial WAV header
                    let initialHeader = createInitialWavHeader()
                    try initialHeader.write(to: fileURL)
                    
                    // Open file handle for streaming writes
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    wavFileHandles[deviceID] = fileHandle
                    
                    print("Initialized streaming WAV file for device \(deviceID): \(fileURL.path)")
                } catch {
                    print("Failed to initialize WAV file for device \(deviceID): \(error)")
                }
            }
        }
    }
    
    public func stopRecording() {
        isRecording = false
        print("Stopping recording and finalizing WAV files...")
        
        // Wait for any pending file I/O operations to complete
        fileIOQueue.sync {
            // Finalize WAV files for all recording devices
            for deviceID in selectedDevices {
                if let fileHandle = wavFileHandles[deviceID] {
                    do {
                        // Close the file handle
                        try fileHandle.close()
                        
                        // Update the WAV header with final file size and data size
                        finalizeWavFile(deviceID: deviceID)
                        
                        print("Finalized WAV file for device \(deviceID)")
                    } catch {
                        print("Failed to close WAV file for device \(deviceID): \(error)")
                    }
                }
            }
            
            // Clean up
            wavFileHandles.removeAll()
        }
        
        // Stop accessing security scoped resources
        if let exportDir = BookmarkStore.resolveBookmark() {
            exportDir.stopAccessingSecurityScopedResource()
        }
        
        print("Stopped recording and finalized WAV files")
    }
    
    // MARK: - WAV File Streaming Methods
    
    private func createWavHeader(fileSize: UInt32, dataSize: UInt32) -> Data {
        var header = Data()
        
        let sampleRate: UInt32 = 44100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        
        // RIFF chunk
        header.append(contentsOf: "RIFF".utf8) // 4 bytes
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) }) // 4 bytes
        
        // WAVE identifier
        header.append(contentsOf: "WAVE".utf8) // 4 bytes
        
        // fmt chunk
        header.append(contentsOf: "fmt ".utf8) // 4 bytes
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // fmt chunk size (4 bytes)
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // audio format - PCM (2 bytes)
        header.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) }) // channels (2 bytes)
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) }) // sample rate (4 bytes)
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) }) // byte rate (4 bytes)
        header.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) }) // block align (2 bytes)
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) }) // bits per sample (2 bytes)
        
        // data chunk
        header.append(contentsOf: "data".utf8) // 4 bytes
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) }) // 4 bytes
        
        return header
    }
    
    private func createInitialWavHeader() -> Data {
        return createWavHeader(fileSize: 0xFFFFFFFF, dataSize: 0xFFFFFFFF)
    }
    
    private func streamAudioData(deviceID: Int32, samples: [Int16]) {
        // This method is now called on the file I/O queue
        // Check if we're still recording and have a valid file handle
        guard isRecording, let fileHandle = wavFileHandles[deviceID] else { return }
        
        // Samples are already in Int16 format, no conversion needed
        // Convert to Data and write to file directly
        let pcmDataBytes = samples.withUnsafeBufferPointer { Data(buffer: $0) }
        
        do {
            try fileHandle.write(contentsOf: pcmDataBytes)
        } catch {
            print("Failed to stream audio data for device \(deviceID): \(error)")
        }
    }
    
    private func finalizeWavFile(deviceID: Int32) {
        guard let exportDir = getExportDirectory() else { return }
        
        let customLabel = getDeviceLabel(for: deviceID)
        let filename = customLabel.isEmpty ? 
            "device_\(deviceID)_recording.wav" : 
            "\(customLabel)_recording.wav"
        let fileURL = exportDir.appendingPathComponent(filename)
        
        do {
            // Read the current file to get the data size
            let fileData = try Data(contentsOf: fileURL)
            let headerSize = 44 // Standard WAV header size
            let dataSize = UInt32(fileData.count - headerSize)
            let fileSize = UInt32(fileData.count - 8) // Total file size minus 8 bytes for RIFF header
            
            // Create updated header with correct sizes using shared utility
            let updatedHeader = createWavHeader(fileSize: fileSize, dataSize: dataSize)
            
            // Read the audio data (everything after the header)
            let audioData = fileData.suffix(from: headerSize)
            
            // Write the complete file with correct header
            var finalWavData = updatedHeader
            finalWavData.append(audioData)
            
            try finalWavData.write(to: fileURL)
            
            print("Finalized WAV file for device \(deviceID) with data size: \(dataSize) bytes")
        } catch {
            print("Failed to finalize WAV file for device \(deviceID): \(error)")
        }
    }
    

}


