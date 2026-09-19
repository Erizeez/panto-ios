import Foundation

/// ProfileItem 代表一份立即可用的配置档案元数据。
public struct ProfileItem: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public var name: String
    public let fileName: String
    public let sourceURL: String?
    public var updatedAt: Date
    public var nodeCount: Int
    public var groupCount: Int
    public var ruleCount: Int
    public var byteSize: Int

    public init(
        id: String = UUID().uuidString,
        name: String,
        fileName: String,
        sourceURL: String? = nil,
        updatedAt: Date = Date(),
        nodeCount: Int = 0,
        groupCount: Int = 0,
        ruleCount: Int = 0,
        byteSize: Int = 0
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.sourceURL = sourceURL
        self.updatedAt = updatedAt
        self.nodeCount = nodeCount
        self.groupCount = groupCount
        self.ruleCount = ruleCount
        self.byteSize = byteSize
    }
}

/// ProfileManifest 管理所有配置档案的清单与当前激活状态。
public struct ProfileManifest: Codable, Sendable {
    public var activeProfileId: String?
    public var profiles: [ProfileItem]

    public init(activeProfileId: String? = nil, profiles: [ProfileItem] = []) {
        self.activeProfileId = activeProfileId
        self.profiles = profiles
    }
}

/// ProfileManager 负责在主应用与系统扩展之间管理多套配置档案的持久化、推荐命名与无缝热切换。
public final class ProfileManager: @unchecked Sendable {
    public static let shared = ProfileManager()

    private let lock = NSLock()
    private let manifestFileName = "profiles.json"
    private let profilesDirName = "profiles"

    private init() {
        ensureDirectoriesExist()
    }

    private var baseDir: URL {
        return AppGroupConstants.containerBaseURL ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private var profilesDir: URL {
        return baseDir.appendingPathComponent(profilesDirName, isDirectory: true)
    }

    private var manifestURL: URL {
        return baseDir.appendingPathComponent(manifestFileName)
    }

    private func ensureDirectoriesExist() {
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)
    }

    // MARK: - 清单加载与保存

    public func loadManifest() -> ProfileManifest {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(ProfileManifest.self, from: data) else {
            // 如果尚无 manifest，但本地已有旧版单文件 config.yaml，自动迁移为首套档案
            if let activeConfig = AppGroupConstants.loadConfig(), !activeConfig.isEmpty {
                let initialProfile = createInitialProfileFromLegacy(content: activeConfig)
                let newManifest = ProfileManifest(activeProfileId: initialProfile.id, profiles: [initialProfile])
                saveManifestInternal(newManifest)
                return newManifest
            }
            return ProfileManifest(activeProfileId: nil, profiles: [])
        }
        return manifest
    }

    private func saveManifestInternal(_ manifest: ProfileManifest) {
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    public func listProfiles() -> [ProfileItem] {
        return loadManifest().profiles
    }

    public func activeProfile() -> ProfileItem? {
        let manifest = loadManifest()
        guard let activeId = manifest.activeProfileId else {
            return manifest.profiles.first
        }
        return manifest.profiles.first(where: { $0.id == activeId }) ?? manifest.profiles.first
    }

    // MARK: - 智能推荐命名与冲突规避算法

    /// 根据给定的基础名称或来源，智能计算避免重名的推荐档案名
    public func suggestUniqueName(baseName: String?) -> String {
        let rawBase = baseName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanBase = rawBase.isEmpty ? "配置档案" : rawBase

        let existingNames = Set(listProfiles().map { $0.name.lowercased() })
        if !existingNames.contains(cleanBase.lowercased()) {
            return cleanBase
        }

        // 若已有同名，提取基础前缀并递增序号：例如 "SJTU-Campus (2)"
        var counter = 2
        while true {
            let candidate = "\(cleanBase) (\(counter))"
            if !existingNames.contains(candidate.lowercased()) {
                return candidate
            }
            counter += 1
        }
    }

    // MARK: - 档案创建与激活

    /// 保存新配置档案并支持立即设为当前生效配置
    @discardableResult
    public func saveProfile(
        name: String,
        content: String,
        sourceURL: String? = nil,
        activate: Bool = true
    ) throws -> ProfileItem {
        lock.lock()
        defer { lock.unlock() }

        ensureDirectoriesExist()

        var manifest = loadManifestWithoutLock()
        let parsed = ConfigProfileParser.parse(yaml: content)

        let profileId = UUID().uuidString
        let fileName = "\(profileId).yaml"
        let fileURL = profilesDir.appendingPathComponent(fileName)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let item = ProfileItem(
            id: profileId,
            name: name,
            fileName: fileName,
            sourceURL: sourceURL,
            updatedAt: Date(),
            nodeCount: parsed.endpoints.count,
            groupCount: parsed.groups.count,
            ruleCount: parsed.rules.count,
            byteSize: content.utf8.count
        )

        // 检查同名覆盖或追加
        if let existingIdx = manifest.profiles.firstIndex(where: { $0.name == name }) {
            // 移除旧文件
            let oldFile = profilesDir.appendingPathComponent(manifest.profiles[existingIdx].fileName)
            try? FileManager.default.removeItem(at: oldFile)
            manifest.profiles[existingIdx] = item
        } else {
            manifest.profiles.append(item)
        }

        if activate || manifest.profiles.count == 1 {
            manifest.activeProfileId = item.id
            // 同步覆盖活动的 config.yaml
            try AppGroupConstants.saveConfig(content)
        }

        saveManifestInternal(manifest)
        return item
    }

    /// 切换当前生效的配置档案
    public func activateProfile(id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var manifest = loadManifestWithoutLock()
        guard let item = manifest.profiles.first(where: { $0.id == id }) else {
            throw NSError(domain: "panto.profile", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到指定的配置档案"])
        }

        let fileURL = profilesDir.appendingPathComponent(item.fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw NSError(domain: "panto.profile", code: 404, userInfo: [NSLocalizedDescriptionKey: "配置实体文件丢失"])
        }

        try AppGroupConstants.saveConfig(content)
        manifest.activeProfileId = item.id
        saveManifestInternal(manifest)
    }

    /// 删除指定配置档案
    public func deleteProfile(id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var manifest = loadManifestWithoutLock()
        guard let idx = manifest.profiles.firstIndex(where: { $0.id == id }) else { return }

        let item = manifest.profiles[idx]
        let fileURL = profilesDir.appendingPathComponent(item.fileName)
        try? FileManager.default.removeItem(at: fileURL)

        manifest.profiles.remove(at: idx)

        // 如果删除的是激活档案，自动切到下一个
        if manifest.activeProfileId == id {
            if let next = manifest.profiles.first {
                manifest.activeProfileId = next.id
                let nextFile = profilesDir.appendingPathComponent(next.fileName)
                if let nextContent = try? String(contentsOf: nextFile, encoding: .utf8) {
                    try? AppGroupConstants.saveConfig(nextContent)
                }
            } else {
                manifest.activeProfileId = nil
                if let activeURL = AppGroupConstants.sharedConfigURL {
                    try? FileManager.default.removeItem(at: activeURL)
                }
            }
        }

        saveManifestInternal(manifest)
    }

    /// 重命名配置档案
    public func renameProfile(id: String, newName: String) {
        lock.lock()
        defer { lock.unlock() }

        var manifest = loadManifestWithoutLock()
        if let idx = manifest.profiles.firstIndex(where: { $0.id == id }) {
            manifest.profiles[idx].name = newName
            manifest.profiles[idx].updatedAt = Date()
            saveManifestInternal(manifest)
        }
    }

    /// 读取指定档案的完整 YAML 文本内容
    public func readProfileContent(id: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        let manifest = loadManifestWithoutLock()
        guard let item = manifest.profiles.first(where: { $0.id == id }) else { return nil }
        let fileURL = profilesDir.appendingPathComponent(item.fileName)
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }

    private func loadManifestWithoutLock() -> ProfileManifest {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(ProfileManifest.self, from: data) else {
            return ProfileManifest(activeProfileId: nil, profiles: [])
        }
        return manifest
    }

    private func createInitialProfileFromLegacy(content: String) -> ProfileItem {
        let profileId = UUID().uuidString
        let fileName = "\(profileId).yaml"
        let fileURL = profilesDir.appendingPathComponent(fileName)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)

        let parsed = ConfigProfileParser.parse(yaml: content)
        return ProfileItem(
            id: profileId,
            name: "默认配置",
            fileName: fileName,
            sourceURL: nil,
            updatedAt: Date(),
            nodeCount: parsed.endpoints.count,
            groupCount: parsed.groups.count,
            ruleCount: parsed.rules.count,
            byteSize: content.utf8.count
        )
    }
}
