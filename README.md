# Multitrack Audio Recorder

A professional multitrack audio recording application for macOS built with SwiftUI and PortAudio. Record from multiple audio input devices simultaneously with real-time waveform visualization and individual device control.

## Features

### 🎙️ Multi-Device Recording
- **Simultaneous Recording**: Record from multiple audio input devices at the same time
- **Device Management**: Easy device selection with checkboxes for each available input
- **Real-time Monitoring**: Live audio level meters and waveform visualization for each device
- **Device Refresh**: Dynamically refresh the input device list without restarting the app

### 🎵 Audio Features
- **High-Quality Recording**: 44.1kHz sample rate with 32-bit float precision
- **WAV File Output**: Industry-standard WAV format with proper headers
- **Streaming Recording**: Real-time audio streaming to disk for efficient memory usage
- **Individual Device Control**: Start/stop recording for each device independently

### 🎨 User Interface
- **Modern SwiftUI Interface**: Clean, intuitive macOS-native interface
- **Real-time Waveforms**: Visual representation of audio input for each device
- **Audio Level Meters**: Live monitoring of input levels with scaling for better visibility
- **Device Labeling**: Add custom labels to identify your audio devices
- **Responsive Design**: Adaptive layout that works with different window sizes

### 🔧 Technical Features
- **Thread-Safe Audio Processing**: Robust audio callback handling with proper thread management
- **File System Integration**: User-selected output directory with persistent access via security bookmarks
- **Sandbox Compliance**: Full macOS sandbox compatibility with proper entitlements
- **Memory Efficient**: Streaming audio data directly to disk without excessive memory usage

## Requirements

- **macOS**: 14.0 or later
- **Xcode**: 15.0 or later (for building from source)
- **Audio Devices**: Any Core Audio compatible input device (microphones, audio interfaces, etc.)

## Installation

### Option 1: Build from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/multitrack-recorder.git
   cd multitrack-recorder
   ```

2. **Install PortAudio** (if not already installed):
   ```bash
   brew install portaudio
   ```

3. **Open in Xcode**:
   ```bash
   open MultitrackRecorder.xcodeproj
   ```

4. **Build and Run**:
   - Select your target device/simulator
   - Press `Cmd+R` to build and run

### Option 2: Download Pre-built App

Download the latest release from the [Releases](https://github.com/yourusername/multitrack-recorder/releases) page.

## Usage

### Getting Started

1. **Launch the Application**: Open MultitrackRecorder from your Applications folder
2. **Select Output Directory**: Choose where you want to save your recordings
3. **Enable Devices**: Check the boxes next to the audio devices you want to record from
4. **Start Recording**: Click "Start Recording" to begin capturing audio from all selected devices
5. **Monitor Audio**: Watch the real-time waveforms and level meters for each device
6. **Stop Recording**: Click "Stop Recording" to finalize your WAV files

### Device Management

- **Refresh Devices**: Click "Refresh" to update the list of available audio devices
- **Add Labels**: Click in the label field next to each device to add custom names
- **Individual Control**: Each device can be enabled/disabled independently
- **Real-time Monitoring**: Audio levels and waveforms update in real-time

### Recording Features

- **Simultaneous Recording**: All selected devices record simultaneously
- **Individual Files**: Each device creates its own WAV file
- **File Naming**: Files are automatically named with device information and timestamps
- **Streaming**: Audio is written to disk in real-time for efficient memory usage

## File Structure

```
MultitrackRecorder/
├── App.swift                          # Main SwiftUI app entry point
├── PortAudioContentView.swift         # Primary UI components and layout
├── PortAudioManager.swift             # Core audio management and PortAudio integration
├── PortAudio-Bridging-Header.h        # C bridging header for PortAudio
├── MultitrackRecorder.entitlements    # macOS sandbox entitlements
└── Assets.xcassets/                   # App icons and visual assets
```

## Technical Details

### Architecture

- **SwiftUI**: Modern declarative UI framework for macOS
- **PortAudio**: Cross-platform audio I/O library for low-latency audio processing
- **ObservableObject**: Reactive data binding for real-time UI updates
- **DispatchQueue**: Background processing for file I/O operations

### Audio Processing

- **Sample Rate**: 44.1kHz
- **Bit Depth**: 32-bit float
- **Buffer Size**: 256 frames (configurable)
- **Latency**: ~5.8ms (256 frames at 44.1kHz)

### Thread Safety

- **Audio Callbacks**: Run on high-priority audio threads
- **UI Updates**: Dispatched to main thread for thread safety
- **File I/O**: Background queue processing to prevent audio dropouts
- **Dictionary Access**: Thread-safe access patterns for shared data

### File Format

- **Output Format**: WAV (RIFF)
- **Encoding**: PCM 16-bit signed integer
- **Headers**: Properly formatted WAV headers with correct byte order
- **Streaming**: Real-time writing with proper file finalization

## Permissions

The app requires the following macOS permissions:

- **Microphone Access**: To record from audio input devices
- **File System Access**: To save recordings to user-selected directories
- **Sandbox Compliance**: Runs in macOS sandbox for security

## Troubleshooting

### Common Issues

**No Audio Devices Found**:
- Ensure your audio devices are connected and recognized by macOS
- Check System Preferences > Sound to verify device availability
- Try clicking "Refresh" to update the device list

**Recording Not Working**:
- Grant microphone permissions when prompted
- Ensure you've selected an output directory
- Check that at least one device is enabled (checkbox checked)

**Poor Audio Quality**:
- Verify your audio interface settings in Audio MIDI Setup
- Check for sample rate mismatches between devices
- Ensure adequate disk space for recording

**App Crashes**:
- Check Console.app for crash logs
- Ensure PortAudio is properly installed
- Try restarting the application

### Performance Tips

- **Close Unnecessary Apps**: Free up system resources for audio processing
- **Use SSD Storage**: Faster disk I/O for better recording performance
- **Monitor CPU Usage**: High CPU usage can cause audio dropouts
- **Check Audio Buffer Settings**: Adjust buffer size if experiencing latency issues

## Development

### Building from Source

1. **Prerequisites**:
   - Xcode 15.0+
   - macOS 14.0+
   - PortAudio library

2. **Dependencies**:
   - PortAudio (via Homebrew or manual installation)
   - SwiftUI framework (included with Xcode)

3. **Build Configuration**:
   - Debug: Full logging and debugging symbols
   - Release: Optimized performance and smaller binary size

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex audio processing logic
- Maintain thread safety in all audio-related code

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **PortAudio**: Cross-platform audio I/O library
- **SwiftUI**: Apple's modern UI framework
- **macOS Audio System**: Core Audio framework

## Support

- **Issues**: Report bugs and request features on [GitHub Issues](https://github.com/yourusername/multitrack-recorder/issues)
- **Discussions**: Join the conversation on [GitHub Discussions](https://github.com/yourusername/multitrack-recorder/discussions)
- **Documentation**: Check the [Wiki](https://github.com/yourusername/multitrack-recorder/wiki) for detailed guides

## Changelog

### Version 1.0.0
- Initial release
- Multi-device recording support
- Real-time waveform visualization
- WAV file output
- Device labeling
- macOS sandbox compliance
- Thread-safe audio processing

---

**Made with ❤️ for the audio community**