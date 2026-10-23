import Foundation

public struct AudioEqualizerPreset: Identifiable, Codable, Equatable, Hashable {
    public var id: String { name }
    public let name: String
    public let preamp: Float
    public let bands: [Float] // 10 bands: 32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
    
    public init(name: String, preamp: Float = 0.0, bands: [Float]) {
        self.name = name
        self.preamp = preamp
        if bands.count == 10 {
            self.bands = bands
        } else {
            self.bands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        }
    }
    
    public static let bandFrequencies: [String] = [
        "32 Hz", "64 Hz", "125 Hz", "250 Hz", "500 Hz",
        "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"
    ]
    
    public static let standardPresets: [AudioEqualizerPreset] = [
        AudioEqualizerPreset(name: "Flat", preamp: 0.0, bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        AudioEqualizerPreset(name: "Rock", preamp: 0.0, bands: [4.8, 3.6, 1.2, -1.8, -3.0, -1.2, 1.8, 3.6, 4.8, 5.4]),
        AudioEqualizerPreset(name: "Pop", preamp: 0.0, bands: [-1.2, 1.2, 3.6, 4.8, 3.6, 0.0, -1.2, -1.8, -1.2, -1.2]),
        AudioEqualizerPreset(name: "Jazz", preamp: 0.0, bands: [3.6, 2.4, 1.2, 1.8, -1.2, -1.2, 0.0, 1.2, 2.4, 3.6]),
        AudioEqualizerPreset(name: "Classical", preamp: 0.0, bands: [4.8, 3.6, 2.4, 1.8, -1.2, -1.2, 0.0, 1.8, 3.0, 3.6]),
        AudioEqualizerPreset(name: "Dance", preamp: 0.0, bands: [6.0, 5.4, 2.4, 0.0, 1.8, 3.6, 4.8, 3.6, 2.4, 0.0]),
        AudioEqualizerPreset(name: "Techno", preamp: 0.0, bands: [5.4, 4.2, 0.0, -3.6, -3.0, 0.0, 4.8, 6.0, 6.0, 5.4]),
        AudioEqualizerPreset(name: "Full Bass", preamp: 0.0, bands: [8.0, 7.2, 6.0, 3.6, 1.2, 0.0, -1.2, -2.4, -3.6, -4.8]),
        AudioEqualizerPreset(name: "Vocal Boost", preamp: 0.0, bands: [-2.4, -3.6, -2.4, 1.2, 4.8, 5.4, 4.2, 1.8, 0.0, -1.2]),
        AudioEqualizerPreset(name: "Electronic", preamp: 0.0, bands: [4.2, 3.6, 1.2, 0.0, -1.8, 2.4, 1.2, 2.4, 4.2, 4.8])
    ]
}
