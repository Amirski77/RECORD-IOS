//
//  AudioPlayer.swift
//  RECORD
//
//  Created by Amir Rashidov on 05.07.2026.
//

import Foundation
import AVFoundation
import Combine

// A self-contained audio player. Each screen that needs preview
// playback owns its own instance (feed and confirm screen never
// appear together, so they don't need to share one).
// ObservableObject = it can broadcast changes to any view watching it.
@MainActor
class AudioPlayer: ObservableObject {
    // The actual iOS audio player (Apple's AVFoundation).
    private var player: AVPlayer?
    // keeps the "played to end" so we can remove it later.
    private var endObserver: NSObjectProtocol?
    // @Published = "when this changes, tell every view watching."
    @Published var currentlyPlayingURL: String?
    
    // set up the audio session when the player is created.
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    // Tap a song's play button → this runs.
    func toggle(urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }

        // Tapped the one already playing? → stop it.
        if currentlyPlayingURL == urlString {
            stop()
            return
        }

        // Otherwise: stop whatever was playing, start this one.
        stop()   // clean up any existing player + observer first
        player = AVPlayer(url: url)
        // when the preview reaches its end, reset the button
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
        }
        
        player?.play()
        currentlyPlayingURL = urlString
    }

    func stop() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        currentlyPlayingURL = nil
    }
}
