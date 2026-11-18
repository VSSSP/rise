import AVFoundation
import AppKit

struct Tune: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
}

// The musical ringtones macOS ships plus songs the owner adds; nothing leaves the system.
enum Tunes {
    static let folder = URL(
        fileURLWithPath: "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/Ringtones")
    static let defaultID = "system:Uplift"
    private static let picks = [
        "Uplift", "Summit", "Playtime", "Daybreak-EncoreInfinitum", "By The Seaside", "Slow Rise", "Constellation",
        "Silk", "Waves", "Radiate", "Milky Way-EncoreInfinitum", "Departure-EncoreInfinitum", "Canopy-EncoreInfinitum",
        "Chalet-EncoreInfinitum", "Seedling-EncoreInfinitum", "Journey-EncoreInfinitum", "Arpeggio-EncoreInfinitum",
        "Night Owl", "Strum", "Twinkle", "Sencha", "Opening", "Reflection",
    ]
    private static let audio = ["mp3", "m4a", "m4r", "aac", "wav", "aif", "aiff", "caf"]

    static var system: [Tune] {
        picks.compactMap { name in
            let url = folder.appendingPathComponent("\(name).m4r")
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return Tune(id: "system:\(name)", title: name.replacingOccurrences(of: "-EncoreInfinitum", with: " (remix)"), url: url)
        }
    }

    static var customFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Rise/Sounds")
    }

    static var custom: [Tune] {
        let files = (try? FileManager.default.contentsOfDirectory(at: customFolder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { audio.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { Tune(id: "file:\($0.lastPathComponent)", title: "♪ \($0.deletingPathExtension().lastPathComponent)", url: $0) }
    }

    // Copies a chosen song into Rise's own folder, so moving the original never silences the reminder.
    static func copyIn(_ source: URL) throws -> URL {
        try FileManager.default.createDirectory(at: customFolder, withIntermediateDirectories: true)
        let target = customFolder.appendingPathComponent(source.lastPathComponent)
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
        try FileManager.default.copyItem(at: source, to: target)
        _ = try AVAudioPlayer(contentsOf: target)
        return target
    }
}

@MainActor
final class MusicPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    private var player: AVAudioPlayer?
    private var limit: Timer?

    // Fades the song in, loops it if asked, and fades it out after `seconds` at most.
    func play(_ url: URL?, volume: Float, seconds: TimeInterval, loop: Bool) {
        stop(fade: false)
        guard let url, let player = try? AVAudioPlayer(contentsOf: url) else {
            NSSound(named: "Glass")?.play()
            return
        }
        player.delegate = self
        player.numberOfLoops = loop ? -1 : 0
        player.volume = 0
        player.prepareToPlay()
        player.play()
        player.setVolume(volume, fadeDuration: 0.6)
        self.player = player
        isPlaying = true
        limit = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop(fade: true) }
        }
    }

    func setVolume(_ volume: Float) {
        player?.volume = volume
    }

    func stop(fade: Bool = true) {
        limit?.invalidate()
        limit = nil
        isPlaying = false
        guard let player else { return }
        self.player = nil
        guard fade, player.isPlaying else { return player.stop() }
        player.setVolume(0, fadeDuration: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { player.stop() }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ finished: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === finished else { return }
            self.player = nil
            self.limit?.invalidate()
            self.isPlaying = false
        }
    }
}
