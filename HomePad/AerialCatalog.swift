import Foundation

/// Apple-hosted metadata, verified 2026-10-23. No media is bundled.
/// Sources and catalog selection: docs/DYNAMIC-SCREENSAVER-10.md.
struct AerialClip: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let videoURL: URL
    let previewURL: URL

    static let catalog: [AerialClip] = [
        AerialClip(id: "12E0343D-2CD9-48EA-AB57-4D680FB6D0C7", name: "Hawaii",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/comp_H007_C003_PS_v01_SDR_PS_20180925_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/H007_C003@2x.png")!),
        AerialClip(id: "25A6CFB2-3570-4448-B114-244A4E454B7A", name: "Patagonia",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/P006_C002_UHD_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/P006_C002_11106T@2x.png")!),
        AerialClip(id: "8002C4C8-C611-4894-A068-3D3A3C03472A", name: "Grand Canyon",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/G010_C026_UHD_SDR_v02_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/G010_C026_0107KE@2x.png")!),
        AerialClip(id: "8D04D70F-738B-441D-8D43-AF46B2BF8062", name: "Yosemite",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/Y011_C008_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/Y011_C008_030584@2x.png")!),
        AerialClip(id: "B8F204CE-6024-49AB-85F9-7CA2F6DCD226", name: "Greenland",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/comp_GL_G004_C010_PSNK_v04_SDR_PS_FINAL_20180709_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/GL_G004_C010@2x.png")!),
        AerialClip(id: "DDE50C77-B7CB-4488-9EB1-D1B13BF21FFE", name: "Iceland",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/I003_C008_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/I003_C008@2x.png")!),
        AerialClip(id: "00BA71CD-2C54-415A-A68A-8358E677D750", name: "Dubai",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/comp_DB_D002_C003_PSNK_v04_SDR_PS_20180914_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/DB_D002_C003@2x.png")!),
        AerialClip(id: "840FE8E4-D952-4680-B1A7-AC5BACA2C1F8", name: "New York",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/comp_N003_C006_PS_v01_SDR_PS_20180925_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/N003_C006@2x.png")!),
        AerialClip(id: "F604AF56-EA77-4960-AEF7-82533CC1A8B3", name: "London",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/comp_L012_c002_PS_v01_SDR_PS_20180925_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/L012_C002@2x.png")!),
        AerialClip(id: "FE8E1F9D-59BA-4207-B626-28E34D810D0A", name: "Hong Kong",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/comp_HK_H004_C008_PSNK_v19_SDR_PS_20180914_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/HK_H004_C008@2x.png")!),
        AerialClip(id: "4F881F8B-A7D9-4FDB-A917-17BF6AC5A589", name: "Caribbean Day",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/comp_GMT308_139K_142NC_CARIBBEAN_DAY_v09_SDR_FINAL_22062018_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/GMT308_139K_142NC_CARIBBEAN_DAY@2x.png")!),
        AerialClip(id: "2F72BC1E-3D76-456C-81EB-842EBA488C27", name: "Africa and the Middle East",
                   videoURL: URL(string: "https://sylvan.apple.com/Aerials/2x/Videos/comp_A103_C002_0205DG_v12_SDR_FINAL_20180706_SDR_2K_HEVC.mov")!,
                   previewURL: URL(string: "https://sylvan.apple.com/itunes-assets/Aerials126/v4/51/ff/08/51ff0824-8da5-78f0-e218-9e61264965bb/A103_C002_0205DG@2x.png")!),
    ]
}
