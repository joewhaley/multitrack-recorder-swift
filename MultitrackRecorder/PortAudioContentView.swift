import SwiftUI

struct PortAudioContentView: View {
    @StateObject private var portAudioManager = PortAudioManager()
    @State private var selectedDevices: Set<Int32> = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Multitrack Audio Recorder")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            DeviceSelectionView(
                portAudioManager: portAudioManager,
                selectedDevices: $selectedDevices
            )
            
            RecordingControlsView(
                portAudioManager: portAudioManager,
                selectedDevices: selectedDevices
            )
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 500)
    }
}

struct DeviceSelectionView: View {
    @ObservedObject var portAudioManager: PortAudioManager
    @Binding var selectedDevices: Set<Int32>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Input Devices")
                    .font(.headline)
                
                Spacer()
                
                Button("Refresh") {
                    portAudioManager.refreshInputDevices()
                    // Clear the UI's selected devices when refreshing
                    selectedDevices.removeAll()
                }
                .buttonStyle(.bordered)
                .disabled(portAudioManager.isRecording)
            }
            
            let deviceCount = portAudioManager.availableDevices.count
            Text("Available devices: \(deviceCount)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if deviceCount == 0 {
                Text("No input devices found")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ForEach(portAudioManager.availableDevices, id: \.id) { device in
                    DeviceRowView(
                        device: device,
                        isSelected: selectedDevices.contains(device.id),
                        portAudioManager: portAudioManager,
                        onToggle: { isSelected in
                            if isSelected {
                                selectedDevices.insert(device.id)
                                portAudioManager.startRecordingDevice(deviceID: device.id)
                            } else {
                                selectedDevices.remove(device.id)
                                portAudioManager.stopRecordingDevice(deviceID: device.id)
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            print("🎨 DeviceSelectionView appeared, available devices: \(portAudioManager.availableDevices.count)")
        }
    }
}

struct DeviceRowView: View {
    let device: PortAudioDevice
    let isSelected: Bool
    let portAudioManager: PortAudioManager
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Device checkbox
            HStack {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { onToggle($0) }
                ))
                .toggleStyle(CheckboxToggleStyle())
                .disabled(portAudioManager.isRecording)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.system(.body, design: .monospaced))
                    Text("Channels: \(device.maxInputChannels)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Editable device label
                    HStack(spacing: 4) {
                        TextField("Add label...", text: Binding(
                            get: { portAudioManager.getDeviceLabel(for: device.id) },
                            set: { portAudioManager.setDeviceLabel($0, for: device.id) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(width: 120)
                        .disabled(portAudioManager.isRecording)

                        if !portAudioManager.getDeviceLabel(for: device.id).isEmpty {
                            Button(action: {
                                portAudioManager.clearDeviceLabel(for: device.id)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .disabled(portAudioManager.isRecording)
                        }
                    }

                    // Gain control
                    HStack(spacing: 8) {
                        Text("Gain:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Slider(
                            value: Binding(
                                get: { portAudioManager.getDeviceGain(for: device.id) },
                                set: { portAudioManager.setDeviceGain($0, for: device.id) }
                            ),
                            in: -24...24,
                            step: 1
                        )
                        .frame(width: 80)

                        Text(String(format: "%+.0f dB", portAudioManager.getDeviceGain(for: device.id)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()

                        Button("Auto") {
                            portAudioManager.calculateAutoGain(for: device.id)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        .help("Automatically adjust gain based on peak levels")
                    }
                }
            }
            .frame(width: 280, alignment: .leading)
            
            // Live waveform (always present to prevent layout shifts)
            PortAudioWaveformView(deviceIndex: device.id, isSelected: isSelected, manager: portAudioManager)
                .frame(width: 200, height: 60)
                .clipped()
            
            Spacer()
        }
    }
    
    private func levelColor(for level: Float) -> Color {
        if level > 0.7 { return .red }
        if level > 0.3 { return .yellow }
        return .green
    }
}

struct RecordingControlsView: View {
    @ObservedObject var portAudioManager: PortAudioManager
    let selectedDevices: Set<Int32>
    
    var body: some View {
        VStack(spacing: 15) {
            // Export Directory Selection
            HStack(spacing: 15) {
                Button("Choose Export Folder") {
                    portAudioManager.chooseExportDirectory()
                }
                .buttonStyle(.bordered)
                
                if let exportDir = portAudioManager.getExportDirectory() {
                    Text("Export to: \(exportDir.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No export folder selected")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Recording Controls
            HStack(spacing: 20) {
                Button(action: {
                    if portAudioManager.isRecording {
                        portAudioManager.stopRecording()
                    } else {
                        portAudioManager.startRecording()
                    }
                }) {
                    Text(portAudioManager.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(minWidth: 150)
                        .background(portAudioManager.isRecording ? Color.red : Color.blue)
                        .cornerRadius(8)
                }
                .disabled(selectedDevices.isEmpty)
                
                if portAudioManager.isRecording {
                    Text("Recording...")
                        .foregroundColor(.red)
                        .font(.headline)
                }
            }
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .font(.system(size: 16, weight: .medium, design: .default))
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            configuration.label
        }
    }
}

struct PortAudioWaveformView: View {
    let deviceIndex: Int32
    let isSelected: Bool
    @ObservedObject var manager: PortAudioManager
    
    var body: some View {
        ZStack {
            // Always render the same Canvas structure to prevent layout shifts
            Canvas { context, size in
                
                if isSelected {
                    // Waveform visualization
                    if let waveformSamples = manager.waveformData[deviceIndex], !waveformSamples.isEmpty {
                        // Draw waveform scaled to fit the available width and height
                        var path = Path()
                        let height = size.height
                        let width = size.width
                        let midY = height / 2
                        
                        // Scale the waveform to fit the available width
                        let samplesCount = waveformSamples.count
                        let step = max(1, samplesCount / Int(width))
                        
                        for i in stride(from: 0, to: samplesCount, by: step) {
                            let sampleIndex = min(i, samplesCount - 1)
                            let amplitude = waveformSamples[sampleIndex]
                            let normalizedAmplitude = min(1.0, max(-1.0, amplitude))
                            
                            let x = CGFloat(i) / CGFloat(samplesCount) * width
                            // Use a much smaller amplitude scaling to keep within bounds
                            let y = midY + (CGFloat(normalizedAmplitude) * height * 0.15)
                            
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        
                        context.stroke(path, with: .color(.green), lineWidth: 1.5)
                    } else {
                        // Draw flat line if no data
                        var path = Path()
                        let height = size.height
                        let width = size.width
                        let midY = height / 2
                        
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: width, y: midY))
                        context.stroke(path, with: .color(.red), lineWidth: 2)
                    }
                } else {
                    // Placeholder for unselected devices - draw a flat gray line
                    var path = Path()
                    let height = size.height
                    let width = size.width
                    let midY = height / 2
                    
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: width, y: midY))
                    context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 2)
                }
            }
            
            // Level meter
            if let currentLevel = manager.audioLevels[deviceIndex] {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(levelColor(for: currentLevel))
                            .frame(width: 15, height: max(2, CGFloat(currentLevel) * 60 * 0.8))
                            .cornerRadius(2)
                    }
                    .padding(.trailing, 4)
                }
            }
        }
        .frame(height: 60)
        .background(Color.black.opacity(0.8))
        .cornerRadius(4)
    }
    
    private func levelColor(for level: Float) -> Color {
        if level > 0.7 { return .red }
        if level > 0.3 { return .yellow }
        return .green
    }
}

#Preview {
    PortAudioContentView()
}
