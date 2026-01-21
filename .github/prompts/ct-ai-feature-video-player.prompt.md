---
agent: Create a SwiftUI View with integrated video player
always: Use LMS design system components, implement fallback URLs, proper memory management
description: "Template for implementing video player views with play/pause controls, loading states, error handling, and fallback URL support following report_lms iOS architecture standards"
---

# Video Player View Implementation Prompt

## Task
Create a SwiftUI View with integrated video player functionality including play/pause controls, loading states, error handling, and fallback URL support.

## Requirements
- Must follow MVVM + Clean Architecture patterns
- Use SwiftUI for all UI components
- Use LMS design system components only
- Include proper memory management and cleanup
- Support fallback URLs for reliability
- Implement loading and error states
- Follow report_lms iOS coding standards

## Implementation Instructions

### Step 1: Import Required Dependencies
Include all necessary imports at the top of your file:

```swift
import SwiftUI
import AVFoundation
import AVKit
```

### Step 2: Define Core Properties
Add these properties to your view:
```swift
// Video Player Properties
@State private var player: AVPlayer?
@State private var isPlaying = false
@State private var isLoading = false
@State private var hasError = false

// Video URLs
let videoURLs: [String]
let title: String?
```

### Step 3: Implement View Structure
Implement the main view body:

#### Required: View body
```swift
var body: some View {
    ZStack {
        VideoPlayer(player: player)
            .onAppear {
                loadVideo()
            }
            .onDisappear {
                cleanupVideoPlayer()
            }
        
        if isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
        
        if !isPlaying {
            Button(action: playButtonTapped) {
                Image(systemName: "play.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
                    .opacity(0.9)
            }
        }
        
        if hasError {
            ErrorView()
        }
    }
    .aspectRatio(16/9, contentMode: .fit)
    .cornerRadius(8)
}
```

### Step 4: Setup Video Player Components
Implement these setup methods:

#### Main setup method
```swift
private func loadVideo() {
    isLoading = true
    hasError = false
    loadVideoFromURLs(videoURLs, currentIndex: 0)
}
```

### Step 5: Implement Video Loading with Fallback Support
Add these methods to handle video loading with multiple URL fallbacks:

#### Main video loading method
```swift
private func loadVideoFromURLs(_ urls: [String], currentIndex: Int) {
    guard currentIndex < urls.count else {
        print("All video URLs failed to load")
        isLoading = false
        hasError = true
        return
    }
    
    guard let url = URL(string: urls[currentIndex]) else {
        print("Invalid video URL: \(urls[currentIndex])")
        loadVideoFromURLs(urls, currentIndex: currentIndex + 1)
        return
    }
    
    print("Attempting to load video from: \(url)")
    
    let playerItem = AVPlayerItem(url: url)
    player = AVPlayer(playerItem: playerItem)
    
    // Observe player status
    NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: playerItem,
        queue: .main
    ) { [weak self] _ in
        self?.playerDidFinishPlaying()
    }
    
    // Check if ready to play
    Task {
        await checkPlayerStatus(playerItem, urls: urls, currentIndex: currentIndex)
    }
}

private func checkPlayerStatus(_ item: AVPlayerItem, urls: [String], currentIndex: Int) async {
    // Wait a moment for status to update
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    
    if item.status == .readyToPlay {
        await MainActor.run {
            isLoading = false
            hasError = false
        }
    } else if item.status == .failed {
        print("Video failed to load: \(item.error?.localizedDescription ?? "Unknown error")")
        await MainActor.run {
            loadVideoFromURLs(urls, currentIndex: currentIndex + 1)
        }
    }
}
```

### Step 6: Add Player Control Actions
Implement these action methods for user interaction:

#### Play/pause button tap handler
```swift
private func playButtonTapped() {
    guard let player = player else { return }
    
    if isPlaying {
        player.pause()
        isPlaying = false
    } else {
        player.play()
        isPlaying = true
    }
}

#### Video completion handler
private func playerDidFinishPlaying() {
    isPlaying = false
    player?.seek(to: .zero)
}
### Step 7: Add Cleanup Methods
Implement proper resource cleanup to prevent memory leaks:

#### Main cleanup method
```swift
private func cleanupVideoPlayer() {
    player?.pause()
    NotificationCenter.default.removeObserver(self)
    player = nil
    isPlaying = false
    isLoading = false
}
```
```

## Critical Implementation Notes

### SwiftUI VideoPlayer Configuration
**MUST DO**: Configure your video player properly:
- Use native `VideoPlayer` from SwiftUI when possible
- Set appropriate aspect ratio: `.aspectRatio(16/9, contentMode: .fit)`
- Enable corner radius: `.cornerRadius(8)`

### Memory Management Requirements
**MUST DO**: Always implement proper cleanup:
- Clean up in `.onDisappear` modifier
- Remove NotificationCenter observers
- Set player to nil after cleanup

### Error Handling Strategy
**MUST DO**: Implement robust error handling:
- Use fallback URLs for improved reliability
- Log errors using print() or custom logger
- Handle network issues gracefully without crashes
- Show user-friendly error states

### UI/UX Guidelines
**MUST DO**: Follow these UX patterns:
- Show loading indicator while video loads
- Only show play button when video is ready or paused
- Auto-hide play button during playback
- Use LMS design system components exclusively

### Performance Optimization
**MUST DO**: Optimize for performance:
- Pause video when view disappears
- Consider implementing visibility-based playback
- Use appropriate video gravity settings
- Use async/await for loading operations

## Complete Example Implementation

```swift
struct VideoPlayerView: View {
    let videoURLs: [String]
    let title: String?
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isLoading = false
    @State private var hasError = false
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            }
            
            if isLoading {
                ProgressView()
            }
            
            if !isPlaying && !isLoading {
                Button(action: playButtonTapped) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.white)
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .cornerRadius(8)
        .onAppear { loadVideo() }
        .onDisappear { cleanupVideoPlayer() }
    }
    
    // Add loading and control methods from steps above
}
```

## Available Customization Options

1. **Video Display**: Use native SwiftUI VideoPlayer or AVPlayerLayer
2. **Play Button**: Customize size, color, or icon style with SF Symbols
3. **Loading Indicator**: Modify ProgressView style
4. **Auto Play**: Add automatic playback when ready
5. **Loop Playback**: Enable continuous video looping
6. **Volume Control**: Add volume management if needed

## Expected Outcome
You should have a fully functional video player view that:
- ✅ Loads videos with fallback URL support
- ✅ Shows loading states and handles errors gracefully  
- ✅ Provides intuitive play/pause controls
- ✅ Manages memory properly with proper cleanup
- ✅ Follows report_lms iOS architecture and design patterns
- ✅ Uses SwiftUI and async/await patterns
- ✅ Implements proper state management