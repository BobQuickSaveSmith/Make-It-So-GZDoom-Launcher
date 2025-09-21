//  Make It So – single file app
//  Drop-in replacement for ContentView.swift (INI persistence)

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Models

struct ModEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var enabled: Bool = true
}

struct Profile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = "New Profile"

    // Paths
    var gzdoomPath: String = "/Applications/GZDoom.app/Contents/MacOS/gzdoom"
    var iwadFullPath: String = (NSHomeDirectory() as NSString)
        .appendingPathComponent("Library/Application Support/gzdoom/DOOM2.WAD")

    // Save game folder name (under ~/Documents/GZDoom/<modFolder>)
    var modFolder: String = "base"

    // Mods & args
    var mods: [ModEntry] = []
    var extraArgs: String = ""

    // CLI preview (editable)
    var editedCLI: String = ""

    // Backups
    var backupDestPath: String = ""
    var backupGZIni: Bool = true
    var backupMakeItSo: Bool = true
    var backupAutoExec: Bool = true
    var backupModSaves: Bool = true
    var backupAfterRun: Bool = false
    var backupKeepCount: Int = 10
    var backupZip: Bool = true

    // UI state (per-profile)
    var uiShowFilenamesOnly: Bool = false
    var uiAllowPrivacyCLIEdit: Bool = false
    // Dock menu pin
    var showInDockMenu: Bool = false

    // Lock
    var locked: Bool = false}

// MARK: - Store

@MainActor
final class AppStore: ObservableObject {
    @Published var profiles: [Profile] = [Profile()]
    @Published var selectedProfileID: UUID? = nil
    @Published var message: String = ""
    // multi-selection (sidebar List)
    @Published var selection: Set<UUID> = []

    // rename sheet token
    @Published var renamingProfileID: UUID? = nil

    // undo delete storage
    private var lastDeleted: Profile?

    init() {
        load()
        if selectedProfileID == nil { selectedProfileID = profiles.first?.id }
    }
    // keep single-selection detail view in sync with multi-select
    func syncDetailSelectionFromMulti() {
        selectedProfileID = selection.first ?? profiles.first?.id
    }

    // MARK: Derived locations

    var supportDir: String {
        let p = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Application Support/gzdoom")
        ensureDir(p); return p
    }
    var docsSaveRoot: String {
        let p = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Documents/GZDoom")
        ensureDir(p); return p
    }
    var logsFilePath: String {
        let d = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Logs/MakeItSo")
        ensureDir(d)
        return (d as NSString).appendingPathComponent("session.log")
    }
    var makeItSoINI: String {
        let d = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Preferences")
        ensureDir(d)
        return (d as NSString).appendingPathComponent("makeitso.ini")
    }
    var gzdoomINI: String {
        (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Preferences/gzdoom.ini")
    }
    var autoexecCFG: String {
        let d = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Documents/GZDoom")
        ensureDir(d)
        return (d as NSString).appendingPathComponent("autoexec.cfg")
    }
    var defaultBackupRoot: String {
        let p = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/MakeItSo-Backups")
        ensureDir(p); return p
    }
    var scriptsRoot: String {
        let p = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Scripts/MakeItSo")
        ensureDir(p); return p
    }

    // MARK: Selection helpers

    var selectedIndex: Int? {
        guard let id = selectedProfileID else { return nil }
        return profiles.firstIndex { $0.id == id }
    }
    var current: Profile {
        profiles.first(where: { $0.id == selectedProfileID }) ?? profiles.first ?? Profile()
    }

    // MARK: Persistence (INI)

    private struct LegacyPersist: Codable { var profiles: [Profile]; var selected: UUID? } // for JSON migration

    func save() {
        do {
            let ini = serializeToINI()
            try ini.write(to: URL(fileURLWithPath: makeItSoINI), atomically: true, encoding: .utf8)
        } catch {
            message = "Save error: \(error.localizedDescription)"
        }
    }

    func load() {
        let url = URL(fileURLWithPath: makeItSoINI)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        guard let raw = try? String(contentsOf: url) else { return }

        // Migration: if old JSON, decode it, then rewrite as INI
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).first == "{" {
            if let data = raw.data(using: .utf8),
               let legacy = try? JSONDecoder().decode(LegacyPersist.self, from: data) {
                self.profiles = legacy.profiles.isEmpty ? [Profile()] : legacy.profiles
                self.selectedProfileID = legacy.selected ?? self.profiles.first?.id
                save() // write back as INI
                return
            }
        }

        // Parse INI
        let ini = INIParser.parse(raw)
        // Order
        let order = ini["Profiles"]?["order"]?
            .split(separator: ",").map { UUID(uuidString: String($0.trimmingCharacters(in: .whitespaces))) }
            .compactMap { $0 } ?? []
        let selectedUUID = ini["MakeItSo"]?["selected"].flatMap(UUID.init(uuidString:))

        var loaded: [Profile] = []
        let ids: [UUID]
        if order.isEmpty {
            // Fallback: discover sections
            ids = ini.sections
                .filter { $0.key.hasPrefix("Profile.") && !$0.key.hasSuffix(".Mods") }
                .compactMap { UUID(uuidString: String($0.key.dropFirst("Profile.".count))) }
        } else {
            ids = order
        }

        for id in ids {
            let baseKey = "Profile.\(id.uuidString)"
            guard let base = ini[baseKey] else { continue }
            var p = Profile()
            p.id = id
            p.name = base["name"] ?? p.name
            p.gzdoomPath = base["gzdoomPath"] ?? p.gzdoomPath
            p.iwadFullPath = base["iwadFullPath"] ?? p.iwadFullPath
            p.modFolder = base["modFolder"] ?? p.modFolder
            p.extraArgs = base["extraArgs"]?.replacingOccurrences(of: "\\n", with: "\n") ?? p.extraArgs
            p.editedCLI = base["editedCLI"]?.replacingOccurrences(of: "\\n", with: "\n") ?? p.editedCLI
            p.backupDestPath = base["backupDestPath"] ?? p.backupDestPath
            p.backupGZIni = INIParser.bool(base["backupGZIni"], default: p.backupGZIni)
            p.backupMakeItSo = INIParser.bool(base["backupMakeItSo"], default: p.backupMakeItSo)
            p.backupAutoExec = INIParser.bool(base["backupAutoExec"], default: p.backupAutoExec)
            p.backupModSaves = INIParser.bool(base["backupModSaves"], default: p.backupModSaves)
            p.backupAfterRun = INIParser.bool(base["backupAfterRun"], default: p.backupAfterRun)
            p.backupKeepCount = Int(base["backupKeepCount"] ?? "") ?? p.backupKeepCount
            p.backupZip = INIParser.bool(base["backupZip"], default: p.backupZip)
            p.uiShowFilenamesOnly = INIParser.bool(base["uiShowFilenamesOnly"], default: p.uiShowFilenamesOnly)
            p.uiAllowPrivacyCLIEdit = INIParser.bool(base["uiAllowPrivacyCLIEdit"], default: p.uiAllowPrivacyCLIEdit)
            p.showInDockMenu = INIParser.bool(base["showInDockMenu"], default: p.showInDockMenu)
            p.locked = INIParser.bool(base["locked"], default: p.locked)
            // Mods
            let modsKey = baseKey + ".Mods"
            if let m = ini[modsKey], let count = Int(m["count"] ?? "0"), count > 0 {
                var list: [ModEntry] = []
                for i in 0..<count {
                    let path = m["mod\(i).path"] ?? ""
                    if path.isEmpty { continue }
                    let en = INIParser.bool(m["mod\(i).enabled"], default: true)
                    list.append(ModEntry(name: path, enabled: en))
                }
                p.mods = list
            }

            loaded.append(p)
        }

        if loaded.isEmpty {
            self.profiles = [Profile()]
            self.selectedProfileID = self.profiles.first?.id
        } else {
            self.profiles = loaded
            self.selectedProfileID = selectedUUID ?? loaded.first?.id
        }
    }

    private func serializeToINI() -> String {
        var out: [String] = []
        out.append("; Make It So configuration (INI style, compatible look with gzdoom.ini)")
        out.append("; Do not edit while the app is running.")
        out.append("")

        // [MakeItSo]
        out.append("[MakeItSo]")
        if let sel = selectedProfileID?.uuidString { out.append("selected=\(sel)") }
        out.append("")

        // [Profiles]
        out.append("[Profiles]")
        let order = profiles.map { $0.id.uuidString }.joined(separator: ",")
        out.append("order=\(order)")
        out.append("")

        // Each profile + mods
        for p in profiles {
            let baseKey = "Profile.\(p.id.uuidString)"
            out.append("[\(baseKey)]")
            out.append("name=\(escapeINI(p.name))")
            out.append("gzdoomPath=\(escapeINI(p.gzdoomPath))")
            out.append("iwadFullPath=\(escapeINI(p.iwadFullPath))")
            out.append("modFolder=\(escapeINI(p.modFolder))")
            out.append("extraArgs=\(escapeINI(p.extraArgs.replacingOccurrences(of: "\n", with: "\\n")))")
            out.append("editedCLI=\(escapeINI(p.editedCLI.replacingOccurrences(of: "\n", with: "\\n")))")
            out.append("backupDestPath=\(escapeINI(p.backupDestPath))")
            out.append("backupGZIni=\(p.backupGZIni ? "true" : "false")")
            out.append("backupMakeItSo=\(p.backupMakeItSo ? "true" : "false")")
            out.append("backupAutoExec=\(p.backupAutoExec ? "true" : "false")")
            out.append("backupModSaves=\(p.backupModSaves ? "true" : "false")")
            out.append("backupAfterRun=\(p.backupAfterRun ? "true" : "false")")
            out.append("backupKeepCount=\(p.backupKeepCount)")
                      out.append("backupZip=\(p.backupZip ? "true" : "false")")
                      out.append("uiShowFilenamesOnly=\(p.uiShowFilenamesOnly ? "true" : "false")")
            out.append("uiAllowPrivacyCLIEdit=\(p.uiAllowPrivacyCLIEdit ? "true" : "false")")
            out.append("showInDockMenu=\(p.showInDockMenu ? "true" : "false")")
            out.append("locked=\(p.locked ? "true" : "false")")
            out.append("")

            out.append("[\(baseKey).Mods]")
            out.append("count=\(p.mods.count)")
            for (i, m) in p.mods.enumerated() {
                out.append("mod\(i).path=\(escapeINI(m.name))")
                out.append("mod\(i).enabled=\(m.enabled ? "true" : "false")")
            }
            out.append("")
        }

        return out.joined(separator: "\n")
    }

    private func escapeINI(_ s: String) -> String {
        // gzdoom.ini typically stores raw strings; we escape only newlines and leading/trailing spaces.
        var v = s.replacingOccurrences(of: "\n", with: "\\n")
        if v.contains(";") || v.hasPrefix(" ") || v.hasSuffix(" ") {
            // mildly protect against comment starts / accidental trimming by wrapping in quotes
            v = "\"\(v.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return v
    }
    // MARK: - Import / Export (JSON)

    struct ExportBundle: Codable { var profiles: [Profile] }
    
    // --- Export helper (tilde‑ize paths for portability + scrub CLI preview)
    private func tildeProfileForExport(_ p: Profile) -> Profile {
        var q = p
        q.gzdoomPath     = pathAbbrev(p.gzdoomPath)
        q.iwadFullPath   = pathAbbrev(p.iwadFullPath)
        q.backupDestPath = pathAbbrev(p.backupDestPath)
        q.mods = p.mods.map { ModEntry(id: $0.id, name: pathAbbrev($0.name), enabled: $0.enabled) }
        // Scrub any absolute HOME paths + any /Users/<name> occurrences (privacy-safe, still functional).
        q.editedCLI = scrubCLIForExport(p.editedCLI)
        return q
    }
    // --- Import helpers (expand "~" and localize foreign /Users/<name>/… to current HOME)
    private func expandAndLocalizeHome(_ s: String) -> String {
        var v = pathExpand(s) // expand "~"
        let homePrefix = HOME + "/"
        if v.hasPrefix("/Users/") && !v.hasPrefix(homePrefix) {
            let comps = (v as NSString).pathComponents
            if comps.count >= 3 && comps[1] == "Users" {
                let tail = comps.dropFirst(3).joined(separator: "/")
                v = (HOME as NSString).appendingPathComponent(tail)
            }
        }
        return v
    }

    private func fixedProfileAfterImport(_ p: Profile) -> (Profile, adjusted: Bool) {
        var q = p
        var changed = false

        // Expand/localize main paths
        let oldGZ   = q.gzdoomPath
        let oldIWAD = q.iwadFullPath
        let oldBkp  = q.backupDestPath

        q.gzdoomPath     = expandAndLocalizeHome(q.gzdoomPath)
        q.iwadFullPath   = expandAndLocalizeHome(q.iwadFullPath)
        q.backupDestPath = expandAndLocalizeHome(q.backupDestPath)

        if q.gzdoomPath != oldGZ || q.iwadFullPath != oldIWAD || q.backupDestPath != oldBkp {
            changed = true
        }

        // Mods: expand/localize each path (do not drop anything)
        q.mods = q.mods.map { m in
            let newName = expandAndLocalizeHome(m.name)
            if newName != m.name { changed = true }
            return ModEntry(id: m.id, name: newName, enabled: m.enabled)
        }

        // Fallbacks if targets don't exist (non-blocking)
        func exists(_ path: String) -> Bool {
            FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)
        }

        // GZDoom binary fallback
        if !q.gzdoomPath.isEmpty && !exists(q.gzdoomPath) {
            let fallback = "/Applications/GZDoom.app/Contents/MacOS/gzdoom"
            if q.gzdoomPath != fallback {
                q.gzdoomPath = fallback
                changed = true
            }
        }

        // IWAD fallback: keep filename, place under standard gzdoom support dir
        if !q.iwadFullPath.isEmpty && !exists(q.iwadFullPath) {
            let fname = (q.iwadFullPath as NSString).lastPathComponent
            if !fname.isEmpty {
                let candidate = (NSHomeDirectory() as NSString)
                    .appendingPathComponent("Library/Application Support/gzdoom/\(fname)")
                if q.iwadFullPath != candidate {
                    q.iwadFullPath = candidate
                    changed = true
                }
            }
        }

        return (q, changed)
    }

    private func normalizeImportedProfiles(_ incoming: [Profile]) -> (profiles: [Profile], adjusted: Bool) {
        var out: [Profile] = []
        var anyAdjusted = false
        for p in incoming {
            let (fp, adj) = fixedProfileAfterImport(p)
            out.append(fp)
            if adj { anyAdjusted = true }
        }
        return (out, anyAdjusted)
    }

    private func nextUniqueParenName(_ base: String) -> String {
        // Prefers: "Name (1)", "Name (2)", ...
        if !profiles.contains(where: { $0.name == base }) { return base }
        var n = 1
        while profiles.contains(where: { $0.name == "\(base) (\(n))" }) { n += 1 }
        return "\(base) (\(n))"
    }

    private func rewriteForImport(_ incoming: [Profile]) -> [Profile] {
            // New UUIDs + name de‑dup while preserving incoming order.
            var result: [Profile] = []
            for var p in incoming {
                p.id = UUID()
                p.name = nextUniqueParenName(p.name)
                result.append(p)
            }
            return result
        }
    func exportProfiles() {
        // Multi-select aware export
        let selectedIDs = Array(selection)
        let exporting: [Profile]
        if !selectedIDs.isEmpty {
            let a = NSAlert()
            a.messageText = "Export Profiles"
            a.informativeText = "Export only the selected profile(s) or all profiles?"
            a.addButton(withTitle: "Selected")
            a.addButton(withTitle: "All")
            a.addButton(withTitle: "Cancel")
            switch a.runModal() {
            case .alertFirstButtonReturn:
                exporting = profiles.filter { selection.contains($0.id) }
            case .alertSecondButtonReturn:
                exporting = profiles
            default:
                return
            }
        } else {
            // original behavior (Selected vs All based on single selection)
            var exportAll = true
            if selectedProfileID != nil {
                let a = NSAlert()
                a.messageText = "Export Profiles"
                a.informativeText = "Export only the selected profile or all profiles?"
                a.addButton(withTitle: "Selected")
                a.addButton(withTitle: "All")
                a.addButton(withTitle: "Cancel")
                switch a.runModal() {
                case .alertFirstButtonReturn: exportAll = false
                case .alertSecondButtonReturn: exportAll = true
                default: return
                }
            }
            exporting = exportAll ? profiles : [current]
        }

        // Make paths portable
        let portable = exporting.map { tildeProfileForExport($0) }

        let save = NSSavePanel()
        save.allowedContentTypes = [UTType.json]
        if !selection.isEmpty {
            save.nameFieldStringValue = "MakeItSo-Profiles-Selected.json"
        } else {
            save.nameFieldStringValue = (exporting.count == profiles.count)
                ? "MakeItSo-Profiles-All.json"
                : "MakeItSo-Profile-\(current.name).json"
        }
        guard save.runModal() == .OK, let url = save.url else { return }

        do {
            let bundle = ExportBundle(profiles: portable)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(bundle).write(to: url)
            info("Export complete", "Saved to:\n\(url.path)")
        } catch {
            info("Export failed", error.localizedDescription)
        }
    }
       
    func importProfiles() {
        let open = NSOpenPanel()
        open.allowedContentTypes = [UTType.json]
        open.allowsMultipleSelection = false
        open.canChooseFiles = true
        open.canChooseDirectories = false
        guard open.runModal() == .OK, let url = open.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let dec = JSONDecoder()

            var imported: [Profile] = []
            if let bundle = try? dec.decode(ExportBundle.self, from: data) {
                imported = bundle.profiles
            } else if let array = try? dec.decode([Profile].self, from: data) {
                imported = array
            } else {
                info("Import failed", "File is not a valid Make It So export.")
                return
            }

            if imported.isEmpty {
                info("Nothing to import", "No profiles found in file.")
                return
            }

            // Expand "~", localize foreign /Users/<name>/…, and apply gentle fallbacks.
            let (normalized, adjusted) = normalizeImportedProfiles(imported)

            // New UUIDs + de-duped names, preserve order
            let rewritten = rewriteForImport(normalized)
            profiles.append(contentsOf: rewritten) // preserve order, never overwrite
            save()

            if adjusted {
                info("Import complete",
                     "Imported \(rewritten.count) profile(s).\n\nSome paths were adjusted for this Mac’s home folder or common defaults.")
            } else {
                info("Import complete", "Imported \(rewritten.count) profile(s).")
            }
        } catch {
            info("Import failed", error.localizedDescription)
        }
    }    // MARK: Profile ops

    func uniqueName(basename: String) -> String {
        var n = 1
        var candidate = basename
        while profiles.contains(where: { $0.name == candidate }) {
            n += 1
            candidate = "\(basename) \(n)"
        }
        return candidate
    }

func addProfile() {
    var p = Profile(name: uniqueName(basename: "Profile"))
    p.backupDestPath = defaultBackupRoot
    profiles.append(p)
    selectedProfileID = p.id
    selection = [p.id]
    regenerateCLI()
}

func duplicateProfile() {
    guard var clone = profiles.first(where: { $0.id == selectedProfileID }) else { return }
    clone.id = UUID()
    clone.locked = false
    clone.name = uniqueName(basename: "\(clone.name) Copy")
    profiles.append(clone)
    selectedProfileID = clone.id
    selection = [clone.id]
    save()
}

func deleteSelectedProfile() {
    // Backward-compatible single-delete if no multi selection
    if selection.isEmpty {
        guard let i = selectedIndex else { return }
        if profiles[i].locked {
            info("Profile is locked", "Unlock it before deleting.")
            return
        }
        lastDeleted = profiles[i]
        profiles.remove(at: i)
        selectedProfileID = profiles.first?.id
        selection.removeAll()
        save()
        return
    }

    // Bulk delete (skip locked, inform user)
    let ids = selection
    var deletedCount = 0
    var lockedNames: [String] = []
    // Remove from end to keep indices stable
    for idx in profiles.indices.reversed() {
        let p = profiles[idx]
        guard ids.contains(p.id) else { continue }
        if p.locked {
            lockedNames.append(p.name)
            continue
        }
        lastDeleted = p
        profiles.remove(at: idx)
        deletedCount += 1
    }
    selection.removeAll()
    selectedProfileID = profiles.first?.id
    save()

    if !lockedNames.isEmpty {
        info("Some profiles were locked",
             "Skipped locked profile(s):\n• " + lockedNames.joined(separator: "\n• "))
    } else if deletedCount == 0 {
        info("Nothing deleted")
    }
}

    func undoDelete() {
        guard let p = lastDeleted else { return }
        profiles.append(p)
        selectedProfileID = p.id
        lastDeleted = nil
        save()
    }

    func moveProfileUp() {
        guard let i = selectedIndex, i > 0 else { return }
        profiles.swapAt(i, i - 1)
        save()
    }

    func moveProfileDown() {
        guard let i = selectedIndex, i < profiles.count - 1 else { return }
        profiles.swapAt(i, i + 1)
        save()
    }

    func toggleLockSelected() {
        guard let i = selectedIndex else { return }
        profiles[i].locked.toggle()
        save()
    }
// Bulk lock/unlock (if multi-selected, toggle all to the same state)
func setLockForSelection(_ locked: Bool) {
    if selection.isEmpty {
        if let i = selectedIndex { profiles[i].locked = locked; save() }
        return
    }
    for i in profiles.indices {
        if selection.contains(profiles[i].id) { profiles[i].locked = locked }
    }
    save()
}

    // MARK: Run (direct)

    private var runTask: Process?
    private var runPipe: Pipe?

    func runNow() {
        let p = current
        let bin = resolveGZDOOMBinary(from: p.gzdoomPath)
        let saveDir = (docsSaveRoot as NSString).appendingPathComponent(p.modFolder)
        ensureDir(saveDir)

        // Build argv (not a single shell string)
        var args: [String] = ["-savedir", saveDir]

        // -file … (expand ~ just like before)
        let fileArgs: [String] = p.mods
            .filter { $0.enabled }
            .map { ($0.name as NSString).expandingTildeInPath }
        if !fileArgs.isEmpty {
            args.append("-file")
            args.append(contentsOf: fileArgs)
        }

        // -iwad …
        if !p.iwadFullPath.isEmpty {
            args.append(contentsOf: ["-iwad", (p.iwadFullPath as NSString).expandingTildeInPath])
        }

        // Extra args (already tokenized)
        args.append(contentsOf: splitCLI(p.extraArgs))

        // Keep the *preview string* for the UI exactly as before
        let previewParts = [bin] + args
        let preview = previewParts.map { needsQuoting($0) ? "\"\($0)\"" : $0 }.joined(separator: " ")
        writePreview(preview)

        // Launch GZDoom directly (no bash)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: bin)
        task.arguments = args

        do {
            // Logging unchanged
            ensureFile(logsFilePath)
            let logURL = URL(fileURLWithPath: logsFilePath)
            let fh = try FileHandle(forWritingTo: logURL)
            try fh.seekToEnd()

            let pipe = Pipe()
            runPipe = pipe
            task.standardOutput = pipe
            task.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { h in
                let data = h.availableData
                if !data.isEmpty { try? fh.write(contentsOf: data) }
            }

            let backupAfterRun = p.backupAfterRun
            task.terminationHandler = { [weak self] _ in
                fh.closeFile()
                // Use the local pipe captured by the closure (not the main-actor property)
                pipe.fileHandleForReading.readabilityHandler = nil

                if backupAfterRun {
                    // Hop to the main actor for UI/state work
                    Task { @MainActor in
                        self?.backupNow()
                    }
                }
            }

            runTask = task
            try task.run()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
    func writePreview(_ s: String) {
        if let i = selectedIndex { profiles[i].editedCLI = s }
        objectWillChange.send()
    }

    // MARK: CLI regen

    func regenerateCLI() {
        let p = current
        let bin = resolveGZDOOMBinary(from: p.gzdoomPath)
        let saveDir = (docsSaveRoot as NSString).appendingPathComponent(p.modFolder)

        var parts: [String] = [bin, "-savedir", saveDir]
        let files = p.mods.filter { $0.enabled }.map { ( $0.name as NSString).expandingTildeInPath }
        if !files.isEmpty { parts += ["-file"] + files }
        if !p.iwadFullPath.isEmpty {
            parts += ["-iwad", (p.iwadFullPath as NSString).expandingTildeInPath]
        }
        parts += splitCLI(p.extraArgs)

        writePreview(parts.map { needsQuoting($0) ? "\"\($0)\"" : $0 }.joined(separator: " "))
    }

    // MARK: Backups

    func backupDestination(for profile: Profile) -> String {
        let trimmed = profile.backupDestPath.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return defaultBackupRoot }
        ensureDir(trimmed); return trimmed
    }

    func backupNow() {
        guard let i = selectedIndex else { return }
        var p = profiles[i]

        let destRoot = backupDestination(for: p)
        let stamp = ts()
        let safeMod = p.modFolder.replacingOccurrences(of: "[^A-Za-z0-9._-]",
                                                       with: "_", options: .regularExpression)
        let dest = (destRoot as NSString).appendingPathComponent("\(safeMod)_Backup_\(stamp)")
        ensureDir(dest)

        if p.backupMakeItSo, FileManager.default.fileExists(atPath: makeItSoINI) {
            _ = runSync(["/usr/bin/rsync", "-a", makeItSoINI, dest + "/"])
        }
        if p.backupGZIni, FileManager.default.fileExists(atPath: gzdoomINI) {
            _ = runSync(["/usr/bin/rsync", "-a", gzdoomINI, dest + "/"])
        }
        if p.backupAutoExec, FileManager.default.fileExists(atPath: autoexecCFG) {
            _ = runSync(["/usr/bin/rsync", "-a", autoexecCFG, dest + "/"])
        }
        if p.backupModSaves {
            let saveDir = (docsSaveRoot as NSString).appendingPathComponent(p.modFolder)
            if FileManager.default.fileExists(atPath: saveDir) {
                let target = (dest as NSString).appendingPathComponent("Savedir_\(safeMod)")
                ensureDir(target)
                _ = runSync(["/usr/bin/rsync", "-a", saveDir + "/", target + "/"])
            }
        }

        if p.backupZip {
            let parent = destRoot
            let zipName = "\(safeMod)_Backup_\(stamp).zip"
            let result = runSync(["/usr/bin/zip", "-r", "-q", zipName,
                                  (dest as NSString).lastPathComponent], cwd: parent)
            if result.exitCode == 0 {
                try? FileManager.default.removeItem(atPath: dest)
            }
        }

        pruneByCount(root: destRoot, keep: max(1, min(30, p.backupKeepCount)))
        profiles[i] = p
        save()
        revealInFinder(destRoot)
    }

    private func pruneByCount(root: String, keep: Int) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: root) else { return }
        let full = items.map { (root as NSString).appendingPathComponent($0) }
        let candidates = full.filter { ( ($0 as NSString).lastPathComponent.contains("_Backup_") ) }
        let sorted = candidates.sorted { a, b in
            (modDate(a) ?? .distantPast) > (modDate(b) ?? .distantPast)
        }
        if sorted.count > keep {
            for old in sorted.dropFirst(keep) { try? fm.removeItem(atPath: old) }
        }
    }

    private func modDate(_ path: String) -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
        return attrs[.modificationDate] as? Date
    }

    // MARK: Chooser memory

    enum StartKey: String { case gzdoom, iwad, saves, addfiles, backup, build }

    func startURL(for key: StartKey, fallback: String) -> URL {
        if let s = UserDefaults.standard.string(forKey: "start.\(key.rawValue)"),
           !s.isEmpty {
            return URL(fileURLWithPath: s)
        }
        return URL(fileURLWithPath: fallback)
    }

    func rememberStart(for key: StartKey, with chosen: URL) {
        let dir = chosen.hasDirectoryPath ? chosen.path : chosen.deletingLastPathComponent().path
        UserDefaults.standard.set(dir, forKey: "start.\(key.rawValue)")
    }

    // MARK: Build script + app, Engage launcher

    func engage() {
        let (appPath, shPath) = builtPaths(for: current) // default location
        let fm = FileManager.default
        if fm.fileExists(atPath: appPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
            return
        }
        if fm.fileExists(atPath: shPath) {
            _ = runSync(["/usr/bin/env", "bash", shPath])
            return
        }
        runNow()
    }

    func builtPaths(for profile: Profile) -> (app: String, sh: String) {
        builtPaths(for: profile, in: scriptsRoot)
    }

    func builtPaths(for profile: Profile, in root: String) -> (app: String, sh: String) {
        let safe = sanitize(profile.name)
        let sh = (root as NSString).appendingPathComponent("\(safe).sh")
        let app = (root as NSString).appendingPathComponent("\(safe).app")
        return (app, sh)
    }

    func buildArtifacts() {
        let p = current

        // Ask user where to build
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose a folder where the app and script will be generated."
        panel.directoryURL = startURL(for: .build, fallback: scriptsRoot)

        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        rememberStart(for: .build, with: chosen)
        let targetRoot = chosen.path

        let (appPath, shPath) = builtPaths(for: p, in: targetRoot)

        // Clean old artifacts so overwrite is deterministic
        let fm = FileManager.default
        if fm.fileExists(atPath: shPath) { try? fm.removeItem(atPath: shPath) }
        if fm.fileExists(atPath: appPath) { try? fm.removeItem(atPath: appPath) }

        // 1) write .sh script
        let scriptText = generateShellScript(from: p)
        do {
            try scriptText.write(to: URL(fileURLWithPath: shPath), atomically: true, encoding: .utf8)
            _ = runSync(["/bin/chmod", "+x", shPath])
        } catch {
            info("Failed to write script", error.localizedDescription)
            return
        }

        // 2) create minimal .app that launches the .sh
        let contents = (appPath as NSString).appendingPathComponent("Contents")
        let macOSDir = (contents as NSString).appendingPathComponent("MacOS")
        let infoPlist = (contents as NSString).appendingPathComponent("Info.plist")
        let runner = (macOSDir as NSString).appendingPathComponent("MakeItSoRunner")

        ensureDir(contents)
        ensureDir(macOSDir)

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleName</key><string>\(p.name)</string>
            <key>CFBundleIdentifier</key><string>com.makeitso.\(sanitize(p.name))</string>
            <key>CFBundleVersion</key><string>1.0</string>
            <key>CFBundleShortVersionString</key><string>1.0</string>
            <key>CFBundlePackageType</key><string>APPL</string>
            <key>CFBundleExecutable</key><string>MakeItSoRunner</string>
            <key>LSMinimumSystemVersion</key><string>10.13</string>
        </dict>
        </plist>
        """
        let runnerScript = """
        #!/bin/bash
        /usr/bin/env bash "\(shPath)"
        """

        do {
            try plist.write(to: URL(fileURLWithPath: infoPlist), atomically: true, encoding: .utf8)
            try runnerScript.write(to: URL(fileURLWithPath: runner), atomically: true, encoding: .utf8)
            _ = runSync(["/bin/chmod", "+x", runner])
        } catch {
            info("Failed to build app bundle", error.localizedDescription)
            return
        }

        info("Build complete",
             "Created:\n• \(shPath)\n• \(appPath)\n\nYou can move the .app anywhere; keep the .sh where you built it.")
        NSWorkspace.shared.open(chosen)
    }

    private func sanitize(_ s: String) -> String {
        let pattern = try! NSRegularExpression(pattern: "[^A-Za-z0-9._-]+")
        let range = NSRange(location: 0, length: (s as NSString).length)
        return pattern.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "_")
    }

    private func generateShellScript(from p: Profile) -> String {
        let bin = resolveGZDOOMBinary(from: p.gzdoomPath)
        let modName = p.modFolder

        // Robust IWAD path handling:
        // - If the profile points to an absolute path or "~" path, keep it.
        // - Otherwise, fall back to "$HOME/Library/Application Support/gzdoom/<filename>".
        let iwadRaw = p.iwadFullPath
        let iwadIsAbsOrTilde = iwadRaw.hasPrefix("/") || iwadRaw.hasPrefix("~")
        let iwadForScript: String = {
            if iwadIsAbsOrTilde { return iwadRaw }
            let fname = (iwadRaw as NSString).lastPathComponent
            return "$HOME/Library/Application Support/gzdoom/\(fname)"
        }()

        let backupRoot = backupDestination(for: p)
        let backupMode = "count" // matches current UI (keep N newest)
        let keepCount = max(1, min(30, p.backupKeepCount))
        let zipOn = p.backupZip ? "on" : "off"
        let zipDeleteRaw = p.backupZip ? "on" : "off"

        // flags mirrored from profile for the built script
        let backupMakeItSo = p.backupMakeItSo ? "on" : "off"
        let backupGZIni = p.backupGZIni ? "on" : "off"
        let backupAutoExec = p.backupAutoExec ? "on" : "off"
        let backupSaves = p.backupModSaves ? "on" : "off"

        // Build MOD_FILES lines (preserve absolute paths; else leave as-is)
        let enabledMods = p.mods.filter { $0.enabled }.map { $0.name }
        let modLines: String = enabledMods.map { path in
            "\"\(path.replacingOccurrences(of: "\"", with: "\\\""))\""
        }.joined(separator: "\n  ")

        // Extra args array
        let extraArgsParts = splitCLI(p.extraArgs).map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }
        let extraArgsBlock = extraArgsParts.joined(separator: " ")

        // Script body
        return """
        #!/bin/bash

        # ==============================================================
        # GZDoom Advanced macOS Launcher Script (generated by Make It So)
        # ==============================================================

        set -u

        # =======================
        # USER SETTINGS (from profile)
        # =======================

        MOD="\(modName)"
        IWAD_PATH="\(iwadForScript.replacingOccurrences(of: "\"", with: "\\\""))"
        # Base folder for relative mod entries
        MOD_BASE="$HOME/Library/Application Support/gzdoom/$MOD"

        # Ordered list of mods to load.
        # - Full path entries (starting with '/' or '~') are used as-is.
        # - Others are resolved under MOD_BASE.
        MOD_FILES=(
          \(modLines)
        )

        # Optional extra GZDoom CLI arguments
        EXTRA_ARGS=( \(extraArgsBlock) )

        # Backup destination
        BACKUP_BASE="\(backupRoot)"

        # Pruning mode & params
        BACKUP_MODE="\(backupMode)"
        PRUNE_DAYS=30
        MAX_BACKUPS=\(keepCount)

        # ZIP options
        ZIP_BACKUPS="\(zipOn)"
        ZIP_DELETE_RAW="\(zipDeleteRaw)"

        # Backup toggles (mirrored from app UI)
        BACKUP_MAKEITSO="\(backupMakeItSo)"
        BACKUP_GZDOOM_INI="\(backupGZIni)"
        BACKUP_AUTOEXEC="\(backupAutoExec)"
        BACKUP_SAVEDIR="\(backupSaves)"

        # =======================
        # DERIVED PATHS
        # =======================

        SAVE_DIR="$HOME/Documents/GZDoom/$MOD"
        # IWAD_PATH is set above (absolute or '~' handled by Swift)

        SRC_DOCS="$SAVE_DIR"
        SRC_INI="$HOME/Library/Preferences/gzdoom.ini"
        SRC_MAKEITSO="$HOME/Library/Preferences/makeitso.ini"
        SRC_AUTOEXEC="$HOME/Documents/GZDoom/autoexec.cfg"

        mkdir -p "$BACKUP_BASE"

        # =======================
        # BUILD MOD FILE ARGUMENTS
        # =======================
        FILE_ARGS=()
        if [ "${#MOD_FILES[@]:-0}" -gt 0 ]; then
          for f in "${MOD_FILES[@]}"; do
            [ -n "$f" ] || continue
            if [[ "$f" == /* || "$f" == ~* ]]; then
              FILE_ARGS+=("${f/#\\~/$HOME}")
            else
              FILE_ARGS+=("$MOD_BASE/$f")
            fi
          done
        fi

        # =======================
        # LAUNCH GZDOOM
        # =======================
        CMD=("\(bin)" -savedir "$SAVE_DIR")

        if [ "${#FILE_ARGS[@]}" -gt 0 ]; then
          CMD+=(-file "${FILE_ARGS[@]}")
        fi

        if [ -n "$IWAD_PATH" ]; then
          CMD+=(-iwad "${IWAD_PATH/#\\~/$HOME}")
        fi
        
        if [ "${#EXTRA_ARGS[@]:-0}" -gt 0 ]; then
          CMD+=("${EXTRA_ARGS[@]}")
        fi

        "${CMD[@]}"

        # =======================
        # BACKUP (save dir + ini files)
        # =======================
        STAMP=$(date +"%Y-%m-%d_%H-%M-%S")
        SAFE_MOD="$(echo "$MOD" | sed 's/[^A-Za-z0-9._-]/_/g')"
        DEST="$BACKUP_BASE/${SAFE_MOD}_Backup_$STAMP"
        mkdir -p "$DEST"

        # Save dir
        if [ "$BACKUP_SAVEDIR" = "on" ] && [ -d "$SRC_DOCS" ]; then
          rsync -av "$SRC_DOCS/" "$DEST/Savedir_${SAFE_MOD}/"
        fi

        # gzdoom.ini
        if [ "$BACKUP_GZDOOM_INI" = "on" ] && [ -f "$SRC_INI" ]; then
          rsync -av "$SRC_INI" "$DEST/"
        fi

        # makeitso.ini
        if [ "$BACKUP_MAKEITSO" = "on" ] && [ -f "$SRC_MAKEITSO" ]; then
          rsync -av "$SRC_MAKEITSO" "$DEST/"
        fi

        # autoexec.cfg
        if [ "$BACKUP_AUTOEXEC" = "on" ] && [ -f "$SRC_AUTOEXEC" ]; then
          rsync -av "$SRC_AUTOEXEC" "$DEST/"
        fi

        if [ "$ZIP_BACKUPS" = "on" ]; then
          (
            cd "$BACKUP_BASE" && /usr/bin/zip -r -q "${SAFE_MOD}_Backup_${STAMP}.zip" "${SAFE_MOD}_Backup_${STAMP}"
          )
          if [ $? -eq 0 ] && [ "$ZIP_DELETE_RAW" = "on" ]; then
            rm -rf "$DEST"
          fi
        fi

        case "$BACKUP_MODE" in
          age)
            find "$BACKUP_BASE" -maxdepth 1 \\( -type d \\( -name 'Backup_*' -o -name '*_Backup_*' \\) -o -type f \\( -name 'Backup_*.zip' -o -name '*_Backup_*.zip' \\) \\) -mtime +30 -exec rm -rf {} +
            ;;
          count)
            IFS=$'\\n' read -r -d '' -a BACKUPS < <(ls -1dt "$BACKUP_BASE"/Backup_* "$BACKUP_BASE"/*_Backup_* 2>/dev/null && printf '\\0')
            COUNT=0
            for item in "${BACKUPS[@]}"; do
              [ -e "$item" ] || continue
              COUNT=$((COUNT+1))
              if [ $COUNT -gt \(keepCount) ]; then
                rm -rf "$item"
              fi
            done
            unset IFS
            ;;
          off|none|disable) ;;
          *) ;;
        esac

        exit 0
        """
    }
}

// MARK: - INI Parser

fileprivate struct INIParser {
    var sections: [String: [String: String]] = [:]
    subscript(_ section: String) -> [String: String]? { sections[section] }

    static func parse(_ text: String) -> INIParser {
        var parser = INIParser()
        var current = ""
        func set(_ key: String, _ value: String) {
            if parser.sections[current] == nil { parser.sections[current] = [:] }
            parser.sections[current]![key] = unquote(value.trimmingCharacters(in: .whitespaces))
        }
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix(";") || line.hasPrefix("#") || line.hasPrefix("//") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let name = String(line.dropFirst().dropLast())
                current = name
                if parser.sections[current] == nil { parser.sections[current] = [:] }
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eq)...])
            set(key, value)
        }
        return parser
    }

    static func unquote(_ s: String) -> String {
        var v = s
        if v.hasPrefix("\""), v.hasSuffix("\""), v.count >= 2 {
            v = String(v.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
        }
        return v.replacingOccurrences(of: "\\n", with: "\n")
    }

    static func bool(_ s: String?, default def: Bool) -> Bool {
        guard let s else { return def }
        let t = s.lowercased()
        if ["true","1","yes","on"].contains(t) { return true }
        if ["false","0","no","off"].contains(t) { return false }
        return def
    }
}

// MARK: - View

struct ContentView: View {
    @StateObject private var store = AppStore()
    @State private var showEngageHelp = false
    @State private var privacyMode = false
    private let compactMode: Bool = true
    
    // token used by the rename sheet
    private struct RenameToken: Identifiable { let id: UUID }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 1000, minHeight: 720)
        .onAppear { store.regenerateCLI() }
        .onAppear {
            dockStore = store   // make the store available to the Dock menu delegate
        }
        .onChange(of: store.selection) { _ in
            store.syncDetailSelectionFromMulti()
            store.save()
        }
        .sheet(item: Binding(
            get: { store.renamingProfileID.map { RenameToken(id: $0) } },
            set: { store.renamingProfileID = $0?.id }
        )) { token in
            let currentName = store.profiles.first(where: { $0.id == token.id })?.name ?? ""
            RenameSheet(currentName: currentName) { newName in
                if let idx = store.profiles.firstIndex(where: { $0.id == token.id }) {
                    store.profiles[idx].name = newName
                    store.save()
                }
            }
        }
    }

    // Sidebar with Engage + Build + profiles list and context menu
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top controls (tighter spacing so more fits)
            ViewThatFits(in: .horizontal) {
                // 1) Preferred layout: single-row HStack (your original controls, unchanged)
                HStack(spacing: 6) {
                    // Engage
                    Button(action: { store.engage() }) {
                        Label("Engage", systemImage: "play.circle.fill")
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.borderedProminent)
                    .fixedSize()
                    // Export / Import
                    Button(action: { store.exportProfiles() }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.bordered)
                    .fixedSize()
                    .help("Export the selected profile or all profiles to a JSON file")

                    Button(action: { store.importProfiles() }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.bordered)
                    .fixedSize()
                    .help("Import profiles from a previously exported JSON file")

                    // Build
                    Button(action: { store.buildArtifacts() }) {
                        Label("Build", systemImage: "hammer")
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.bordered)
                    .fixedSize()
                    .help("Create a runnable script (.sh) and a mini app (.app) for the selected profile")

                    Toggle("Privacy", isOn: $privacyMode)
                        .toggleStyle(.switch)
                        .help("""
                        Privacy
                        • Hides your home path as “~” in fields and the CLI preview
                        • Real values are still saved as full paths
                        • CLI stays read‑only in Privacy unless you enable “Allow editing while Privacy is ON”
                        """)
                        .fixedSize()

                    Button { showEngageHelp.toggle() } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Help")
                    .accessibilityHint("Open quick help and links to the guide and manual.")
                    .popover(isPresented: $showEngageHelp) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Quick Help").font(.headline)
                            Text("""
                            • ▶️ Engage runs the game with the selected profile
                            • 🛠️ Build creates a runnable script + mini app
                            • 🛡️ Privacy hides your home path (“~”) and makes the CLI read‑only
                            • 🔒 Lock prevents accidental edits
                            • 📌 Pin lets you launch profiles from the Dock icon menu
                            • 📤 Import/Export helps share profiles with others
                            """)
                            .lineSpacing(6)
                            .frame(maxWidth: 420, alignment: .leading)

                            Divider().padding(.vertical, 4)

                            HStack {
                                Button {
                                    showEngageHelp = false
                                    showHelpGuide(anchor: .quickStart)
                                } label: {
                                    Label("Quick Start Guide", systemImage: "bolt.horizontal")
                                }

                                Button {
                                    showEngageHelp = false
                                    showHelpGuide(anchor: .manual)
                                } label: {
                                    Label("Manual", systemImage: "book")
                                }

                                Button {
                                    showEngageHelp = false
                                    showLicense()
                                } label: {
                                    Label("License", systemImage: "doc.text")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(16)
                        .frame(width: 440)
                    }
                    .labelStyle(.titleAndIcon)
                    .fixedSize()
                    Button {
                        if store.selection.isEmpty {
                            // Toggle current profile pin
                            if let i = store.selectedIndex {
                                store.profiles[i].showInDockMenu.toggle()
                                store.save()
                            }
                        } else {
                            // Bulk pin/unpin: if any selected is unpinned, pin all; else unpin all
                            let anyUnpinned = store.profiles.contains { store.selection.contains($0.id) && !$0.showInDockMenu }
                            for idx in store.profiles.indices {
                                if store.selection.contains(store.profiles[idx].id) {
                                    store.profiles[idx].showInDockMenu = anyUnpinned
                                }
                            }
                            store.save()
                        }
                    } label: {
                        Image(systemName:
                              store.selection.isEmpty
                              ? (store.current.showInDockMenu ? "pin.slash" : "pin.fill")
                              : (
                                  store.profiles.contains { store.selection.contains($0.id) && !$0.showInDockMenu }
                                  ? "pin.fill"    // will pin all
                                  : "pin.slash"   // will unpin all
                                )
                        )
                    }
                    .help("Pin or unpin in Dock Menu")
                    .accessibilityLabel("Pin or unpin selected in Dock Menu")
                    Spacer(minLength: 8)
                    Button {
                        if store.selection.isEmpty {
                            store.toggleLockSelected()
                        } else {
                            // If any selected is unlocked, lock all; otherwise unlock all
                            let anyUnlocked = store.profiles.contains { store.selection.contains($0.id) && !$0.locked }
                            store.setLockForSelection(anyUnlocked) // lock all if any unlocked; else unlock all
                        }
                    } label: {
                        Image(systemName:
                              store.selection.isEmpty
                              ? (store.current.locked ? "lock.fill" : "lock.open")
                              : (
                                  store.profiles.contains { store.selection.contains($0.id) && !$0.locked }
                                  ? "lock.fill"   // will lock all
                                  : "lock.open"   // will unlock all
                                )
                        )
                    }
                    .help("Lock or unlock the selected profile(s).")
                    .accessibilityLabel("Lock or unlock selected")
                    .accessibilityHint("Toggles lock for all selected profiles.")
                    Button(action: store.addProfile) { Image(systemName: "plus") }
                        .accessibilityLabel("Add profile")
                    Button(action: store.duplicateProfile) {
                        Image(systemName: "doc.on.doc") }
                    .accessibilityLabel("Duplicate profile")
                    .accessibilityHint("Creates a copy of the selected profile.")
                    Button(action: store.deleteSelectedProfile) { Image(systemName: "trash") }
                        .disabled(
                            // disable if any selected profile is locked
                            !store.selection.isEmpty
                            ? store.profiles.contains { store.selection.contains($0.id) && $0.locked }
                            : store.current.locked
                        )
                        .help("Removes the selected profile(s). Locked profiles are skipped.")
                        .accessibilityLabel("Delete profile(s)")
                        .accessibilityHint("Removes the selected profile(s). Locked profiles are skipped.")
                    Button(action: store.undoDelete) { Image(systemName: "arrow.uturn.backward.circle") }
                        .accessibilityLabel("Undo last delete")
                        .help("Undo last delete")
                }

                // 2) Fallback layout: compact two-row VStack (same controls, split across rows)
                VStack(alignment: .leading, spacing: 6) {
                    // Row 1: primary actions
                    HStack(spacing: 6) {
                        Button(action: { store.engage() }) {
                            Label("Engage", systemImage: "play.circle.fill")
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.borderedProminent)
                        .fixedSize()

                        Button(action: { store.exportProfiles() }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.bordered)
                        .fixedSize()
                        .help("Export the selected profile or all profiles to a JSON file")

                        Button(action: { store.importProfiles() }) {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.bordered)
                        .fixedSize()
                        .help("Import profiles from a previously exported JSON file")

                        Button(action: { store.buildArtifacts() }) {
                            Label("Build", systemImage: "hammer")
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.bordered)
                        .fixedSize()
                        .help("Create a runnable script (.sh) and a mini app (.app) for the selected profile")

                        Toggle("Privacy", isOn: $privacyMode)
                            .toggleStyle(.switch)
                            .help("""
                            Privacy
                            • Hides your home path as “~” in fields and the CLI preview
                            • Real values are still saved as full paths
                            • CLI stays read‑only in Privacy unless you enable “Allow editing while Privacy is ON”
                            """)
                            .fixedSize()

                        /* Help button moved to Row 2 in compact layout */
                        /* Pin button moved to Row 2 in compact layout */                    }

                    // Row 2: management & ordering
                    HStack(spacing: 6) {
                        Button {
                            if store.selection.isEmpty {
                                store.toggleLockSelected()
                            } else {
                                let anyUnlocked = store.profiles.contains { store.selection.contains($0.id) && !$0.locked }
                                store.setLockForSelection(anyUnlocked)
                            }
                        } label: {
                            Image(systemName:
                                  store.selection.isEmpty
                                  ? (store.current.locked ? "lock.fill" : "lock.open")
                                  : (
                                      store.profiles.contains { store.selection.contains($0.id) && !$0.locked }
                                      ? "lock.fill"
                                      : "lock.open"
                                    )
                            )
                        }
                        .help("Lock or unlock the selected profile(s).")
                        .accessibilityLabel("Lock or unlock selected")
                        .accessibilityHint("Toggles lock for all selected profiles.")
                        // Pin (moved here for compact two‑row layout)
                        Button {
                            if store.selection.isEmpty {
                                if let i = store.selectedIndex {
                                    store.profiles[i].showInDockMenu.toggle()
                                    store.save()
                                }
                            } else {
                                let anyUnpinned = store.profiles.contains { store.selection.contains($0.id) && !$0.showInDockMenu }
                                for idx in store.profiles.indices {
                                    if store.selection.contains(store.profiles[idx].id) {
                                        store.profiles[idx].showInDockMenu = anyUnpinned
                                    }
                                }
                                store.save()
                            }
                        } label: {
                            Image(systemName:
                                  store.selection.isEmpty
                                  ? (store.current.showInDockMenu ? "pin.slash" : "pin.fill")
                                  : (
                                      store.profiles.contains { store.selection.contains($0.id) && !$0.showInDockMenu }
                                      ? "pin.fill"
                                      : "pin.slash"
                                    )
                            )
                        }
                        .help("Pin or unpin in Dock Menu")
                        .accessibilityLabel("Pin or unpin selected in Dock Menu")
                        // Help (moved here so it can drop to second row)
                        Button { showEngageHelp.toggle() } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel("Help")
                        .accessibilityHint("Open quick help and links to the guide and manual.")
                        .popover(isPresented: $showEngageHelp) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Quick Help").font(.headline)
                                Text("""
                                • ▶️ Engage runs the game with the selected profile
                                • 🛠️ Build creates a runnable script + mini app
                                • 🛡️ Privacy hides your home path (“~”) and makes the CLI read‑only
                                • 🔒 Lock prevents accidental edits
                                • 📌 Pin lets you launch profiles from the Dock icon menu
                                • 📤 Import/Export helps share profiles with others
                                """)
                                .lineSpacing(6)
                                .frame(maxWidth: 420, alignment: .leading)

                                Divider().padding(.vertical, 4)

                                HStack {
                                    Button {
                                        showEngageHelp = false
                                        showHelpGuide(anchor: .quickStart)
                                    } label: { Label("Quick Start Guide", systemImage: "bolt.horizontal")
 }

                                    Button {
                                        showEngageHelp = false
                                        showHelpGuide(anchor: .manual)
                                    } label: { Label("Manual", systemImage: "book")
 }

                                    Button {
                                        showEngageHelp = false
                                        showLicense()
                                    } label: { Label("License", systemImage: "doc.text")
 }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(16)
                            .frame(width: 440)
                        }
                        .labelStyle(.titleAndIcon)
                        .fixedSize()

                        Button(action: store.addProfile) { Image(systemName: "plus") }
                            .accessibilityLabel("Add profile")

                        Button(action: store.duplicateProfile) { Image(systemName: "doc.on.doc") }
                            .accessibilityLabel("Duplicate profile")
                            .accessibilityHint("Creates a copy of the selected profile.")

                        Button(action: store.deleteSelectedProfile) { Image(systemName: "trash") }
                            .disabled(
                                !store.selection.isEmpty
                                ? store.profiles.contains { store.selection.contains($0.id) && $0.locked }
                                : store.current.locked
                            )
                            .help("Removes the selected profile(s). Locked profiles are skipped.")
                            .accessibilityLabel("Delete profile(s)")
                            .accessibilityHint("Removes the selected profile(s). Locked profiles are skipped.")

                        Button(action: store.undoDelete) { Image(systemName: "arrow.uturn.backward.circle") }
                            .accessibilityLabel("Undo last delete")
                            .help("Undo last delete")

                        // Move profile up
                        Button {
                            // Move selected profile UP
                            let idx: Int? = {
                                if !store.selection.isEmpty, let id = store.selection.first,
                                   let i = store.profiles.firstIndex(where: { $0.id == id }) { return i }
                                return store.selectedIndex
                            }()
                            guard let i = idx, i > 0, !store.profiles[i].locked else { return }
                            let item = store.profiles.remove(at: i)
                            store.profiles.insert(item, at: i - 1)
                            store.selectedProfileID = store.profiles[i - 1].id
                            store.save()
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .help("Move selected profile up")
                        .disabled({
                            if !store.selection.isEmpty, let id = store.selection.first,
                               let i = store.profiles.firstIndex(where: { store.selection.contains($0.id) }) {
                                return store.profiles[i].locked || i == 0
                            }
                            if let i = store.selectedIndex { return store.profiles[i].locked || i == 0 }
                            return true
                        }())
                        .accessibilityLabel("Move profile up")

                        // Move profile down
                        Button {
                            // Move selected profile DOWN
                            let idx: Int? = {
                                if !store.selection.isEmpty, let id = store.selection.first,
                                   let i = store.profiles.firstIndex(where: { $0.id == id }) { return i }
                                return store.selectedIndex
                            }()
                            guard let i = idx, i < store.profiles.count - 1, !store.profiles[i].locked else { return }
                            let item = store.profiles.remove(at: i)
                            store.profiles.insert(item, at: i + 1)
                            store.selectedProfileID = store.profiles[i + 1].id
                            store.save()
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .help("Move selected profile down")
                        .disabled({
                            if !store.selection.isEmpty, let id = store.selection.first,
                               let i = store.profiles.firstIndex(where: { store.selection.contains($0.id) }) {
                                return store.profiles[i].locked || i >= store.profiles.count - 1
                            }
                            if let i = store.selectedIndex { return store.profiles[i].locked || i >= store.profiles.count - 1 }
                            return true
                        }())
                        .accessibilityLabel("Move profile down")

                        Spacer(minLength: 8)
                    }
                }
            }
            .controlSize(.small)
            .padding(.horizontal)
            // Profiles list  — numbered badge + drag-to-reorder
            List(selection: $store.selection) {
                ForEach($store.profiles) { $p in
                    HStack(spacing: 8) {
                        // Leading index badge (1, 2, 3, …) – also serves as an obvious drag handle
                        Text("\(((store.profiles.firstIndex(where: { $0.id == p.id }) ?? 0) + 1))")
                            .font(.caption2)
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)         // 3‑digit comfortable
                            .padding(.vertical, 1).padding(.horizontal, 4)  // slimmer to match sidebar
                            .background(Capsule().fill(.quaternary))
                            .overlay(Capsule().stroke(.separator.opacity(0.6), lineWidth: 1))
                            .help("Drag to reorder")

                        HStack(spacing: 4) {
                            Button {
                                p.locked.toggle(); store.save()
                            } label: {
                                Image(systemName: p.locked ? "lock.fill" : "lock.open")
                            }
                            .buttonStyle(.plain)
                            .help(
                                p.locked
                                ? "Click to unlock and allow editing"
                                : "Click to lock and prevent changes"
                            )
                            .accessibilityLabel(p.locked ? "Unlock profile" : "Lock profile")
                            .accessibilityHint(p.locked ? "Allows editing this profile." : "Prevents editing this profile.")
                            .accessibilityValue(p.locked ? "Locked" : "Unlocked")

                            Button {
                                p.showInDockMenu.toggle(); store.save()
                            } label: {
                                Image(systemName: p.showInDockMenu ? "pin.fill" : "pin")
                            }
                            .buttonStyle(.plain)
                            .help(p.showInDockMenu ? "Pinned in Dock Menu" : "Pin to Dock Menu")
                            .accessibilityLabel(p.showInDockMenu ? "Unpin from Dock Menu" : "Pin to Dock Menu")
                            .accessibilityHint("Toggles Dock Menu pin for this profile.")
                        }
                        .foregroundStyle(.secondary)
                        TextField("Profile", text: $p.name)
                            .textFieldStyle(.plain)
                            .disabled(p.locked)
                    }
                    .accessibilityElement(children: .combine)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Engage", systemImage: "play.circle") {
                            store.selectedProfileID = p.id
                            store.engage()
                        }
                        Divider()
                        Button(
                            p.showInDockMenu ? "Unpin from Dock Menu" : "Pin to Dock Menu",
                            systemImage: p.showInDockMenu ? "pin.slash" : "pin.fill"
                        ) {
                            p.showInDockMenu.toggle()
                            store.save()
                        }
                        Divider()
                        Button(p.locked ? "Unlock" : "Lock",
                               systemImage: p.locked ? "lock.open" : "lock.fill") {
                            p.locked.toggle(); store.save()
                        }
                        Button("Build", systemImage: "hammer") {
                            store.selectedProfileID = p.id
                            store.buildArtifacts()
                        }
                        Button("Rename", systemImage: "pencil") { store.renamingProfileID = p.id }
                        Button("Duplicate", systemImage: "doc.on.doc") {
                            store.selectedProfileID = p.id; store.duplicateProfile()
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.selection = [p.id]
                            store.selectedProfileID = p.id
                            store.deleteSelectedProfile()
                        }
                        .disabled(p.locked)
                    }
                    .tag(p.id)
                }
                // drag-to-reorder for profiles
                .onMove { indices, newOffset in
                    let moving = indices.map { store.profiles[$0] }
                    guard moving.allSatisfy({ !$0.locked }) else { return }
                    store.profiles.move(fromOffsets: indices, toOffset: newOffset)
                    store.save()
                }
            }
            .listStyle(.inset)
            .environment(\.defaultMinListRowHeight, 22)  // compact list rows
            .help("Tip: drag the numbered badges (or the row) to reorder")
            Spacer()

            // Files & Logs
            Group {
                Text("Use plain text mode when editing files:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                HStack(spacing: 8) {
                    Button {
                        let url = URL(fileURLWithPath: store.makeItSoINI)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        HStack { Image(systemName: "doc.text.magnifyingglass"); Text("makeitso.ini") }
                    }
                    .fixedSize()
                    // Insert ellipsis menu button between makeitso.ini and gzdoom.ini
                    Menu {
                        // Offer installed editors (detected by bundle id). Falls back to plain open if none are found.
                        // 1) Apple TextEdit (always try to show if present)
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
                            Button("TextEdit") {
                                let fileURL = URL(fileURLWithPath: store.makeItSoINI)
                                let cfg = NSWorkspace.OpenConfiguration()
                                NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                            }
                        }

                        // 2) BBEdit
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.barebones.bbedit") {
                            Button("BBEdit") {
                                let fileURL = URL(fileURLWithPath: store.makeItSoINI)
                                let cfg = NSWorkspace.OpenConfiguration()
                                NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                            }
                        }

                        // 3) Visual Studio Code
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
                            Button("Visual Studio Code") {
                                let fileURL = URL(fileURLWithPath: store.makeItSoINI)
                                let cfg = NSWorkspace.OpenConfiguration()
                                NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                            }
                        }

                        // 4) Sublime Text
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sublimetext.4") {
                            Button("Sublime Text") {
                                let fileURL = URL(fileURLWithPath: store.makeItSoINI)
                                let cfg = NSWorkspace.OpenConfiguration()
                                NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                            }
                        }

                        // 5) Nova
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.panic.Nova") {
                            Button("Nova") {
                                let fileURL = URL(fileURLWithPath: store.makeItSoINI)
                                let cfg = NSWorkspace.OpenConfiguration()
                                NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                            }
                        }

                        // 6) CotEditor
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.coteditor.CotEditor") {
                            Button("CotEditor") {
                                let fileURL = URL(fileURLWithPath: store.makeItSoINI)
                                let cfg = NSWorkspace.OpenConfiguration()
                                NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                            }
                        }

                        // Fallback: if none of the above exist, show a plain TextEdit option that uses the default handler
                        if  NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.barebones.bbedit") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sublimetext.4") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.panic.Nova") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.coteditor.CotEditor") == nil {
                            Button("TextEdit") {
                                let fileURL = URL(fileURLWithPath: store.makeItSoINI)
                                NSWorkspace.shared.open(fileURL)
                            }
                        }

                        Divider()

                        Button("Choose Another App…") {
                            let panel = NSOpenPanel()
                            panel.title = "Choose an editor"
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.canChooseFiles = true
                            panel.allowedFileTypes = ["app"]
                            panel.directoryURL = URL(fileURLWithPath: "/Applications")
                            if panel.runModal() == .OK, let appURL = panel.url {
                                let fileURL = URL(fileURLWithPath: store.makeItSoINI)
                                let cfg = NSWorkspace.OpenConfiguration()
                                NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .imageScale(.small)
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .help("Open makeitso.ini in a specific editor.")
                    .fixedSize()
                    Button {
                        let url = URL(fileURLWithPath: store.gzdoomINI)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        HStack { Image(systemName: "doc.text.magnifyingglass"); Text("gzdoom.ini") }
                    }
                    .fixedSize()
                    // Editor picker for gzdoom.ini (ordered to match makeitso.ini / autoexec.cfg)
                    Menu {
                        // 1) Apple TextEdit
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
                            Button("TextEdit") {
                                let path = store.gzdoomINI
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                } else {
                                    info("gzdoom.ini not found. Launch GZDoom once to create it.")
                                }
                            }
                        }

                        // 2) BBEdit
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.barebones.bbedit") {
                            Button("BBEdit") {
                                let path = store.gzdoomINI
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                } else {
                                    info("gzdoom.ini not found. Launch GZDoom once to create it.")
                                }
                            }
                        }

                        // 3) Visual Studio Code
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
                            Button("Visual Studio Code") {
                                let path = store.gzdoomINI
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                } else {
                                    info("gzdoom.ini not found. Launch GZDoom once to create it.")
                                }
                            }
                        }

                        // 4) Sublime Text
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sublimetext.4") {
                            Button("Sublime Text") {
                                let path = store.gzdoomINI
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                } else {
                                    info("gzdoom.ini not found. Launch GZDoom once to create it.")
                                }
                            }
                        }

                        // 5) Nova
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.panic.Nova") {
                            Button("Nova") {
                                let path = store.gzdoomINI
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                } else {
                                    info("gzdoom.ini not found. Launch GZDoom once to create it.")
                                }
                            }
                        }

                        // 6) CotEditor
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.coteditor.CotEditor") {
                            Button("CotEditor") {
                                let path = store.gzdoomINI
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                } else {
                                    info("gzdoom.ini not found. Launch GZDoom once to create it.")
                                }
                            }
                        }

                        // Fallback: if none of the above editors are found, show a plain TextEdit using default handler
                        if  NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.barebones.bbedit") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sublimetext.4") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.panic.Nova") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.coteditor.CotEditor") == nil {
                            Button("TextEdit") {
                                let path = store.gzdoomINI
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    NSWorkspace.shared.open(fileURL)
                                } else {
                                    info("gzdoom.ini not found. Launch GZDoom once to create it.")
                                }
                            }
                        }

                        Divider()

                        Button("Choose Another App…") {
                            let path = store.gzdoomINI
                            if FileManager.default.fileExists(atPath: path) {
                                let panel = NSOpenPanel()
                                panel.title = "Choose an editor"
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                panel.canChooseFiles = true
                                panel.allowedFileTypes = ["app"]
                                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                                if panel.runModal() == .OK, let appURL = panel.url {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                }
                            } else {
                                info("gzdoom.ini not found. Launch GZDoom once to create it.")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .imageScale(.small)
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .help("Open gzdoom.ini in a specific editor.")
                    .fixedSize()
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        let path = store.autoexecCFG
                        if FileManager.default.fileExists(atPath: path) {
                            revealInFinder(path)
                        } else {
                            let alert = NSAlert()
                            alert.messageText = "File not found"
                            alert.informativeText = "The file ~/Documents/GZDoom/autoexec.cfg does not exist."
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    } label: {
                        HStack { Image(systemName: "doc.text.magnifyingglass"); Text("autoexec.cfg") }
                    }
                    // Compact editor picker for autoexec.cfg (ordered to match makeitso.ini)
                    Menu {
                        // 1) Apple TextEdit
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
                            Button("TextEdit") {
                                let path = store.autoexecCFG
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                } else {
                                    // mirror the create flow used by the button
                                    let alert = NSAlert()
                                    alert.messageText = "Create autoexec.cfg?"
                                    alert.informativeText = "Create ~/Documents/GZDoom/autoexec.cfg and open in TextEdit?"
                                    alert.addButton(withTitle: "Create")
                                    alert.addButton(withTitle: "Cancel")
                                    if alert.runModal() == .alertFirstButtonReturn {
                                        ensureFile(path)
                                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                                    }
                                }
                            }
                        }
                        // 2) BBEdit
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.barebones.bbedit") {
                            Button("BBEdit") {
                                let path = store.autoexecCFG
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                }
                            }
                        }
                        // 3) Visual Studio Code
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
                            Button("Visual Studio Code") {
                                let path = store.autoexecCFG
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                }
                            }
                        }
                        // 4) Sublime Text
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sublimetext.4") {
                            Button("Sublime Text") {
                                let path = store.autoexecCFG
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                }
                            }
                        }
                        // 5) Nova
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.panic.Nova") {
                            Button("Nova") {
                                let path = store.autoexecCFG
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                }
                            }
                        }
                        // 6) CotEditor
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.coteditor.CotEditor") {
                            Button("CotEditor") {
                                let path = store.autoexecCFG
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                }
                            }
                        }
                        // Fallback: if none of the above exist, show a plain TextEdit option that uses the default handler
                        if  NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.barebones.bbedit") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sublimetext.4") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.panic.Nova") == nil
                            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.coteditor.CotEditor") == nil {
                            Button("TextEdit") {
                                let path = store.autoexecCFG
                                if FileManager.default.fileExists(atPath: path) {
                                    let fileURL = URL(fileURLWithPath: path)
                                    NSWorkspace.shared.open(fileURL)
                                } else {
                                    let alert = NSAlert()
                                    alert.messageText = "Create autoexec.cfg?"
                                    alert.informativeText = "Create ~/Documents/GZDoom/autoexec.cfg and open in TextEdit?"
                                    alert.addButton(withTitle: "Create")
                                    alert.addButton(withTitle: "Cancel")
                                    if alert.runModal() == .alertFirstButtonReturn {
                                        ensureFile(path)
                                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                                    }
                                }
                            }
                        }
                        Divider()
                        Button("Choose Another App…") {
                            let path = store.autoexecCFG
                            if FileManager.default.fileExists(atPath: path) {
                                let panel = NSOpenPanel()
                                panel.title = "Choose an editor"
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                panel.canChooseFiles = true
                                panel.allowedFileTypes = ["app"]
                                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                                if panel.runModal() == .OK, let appURL = panel.url {
                                    let fileURL = URL(fileURLWithPath: path)
                                    let cfg = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
                                }
                            } else {
                                let alert = NSAlert()
                                alert.messageText = "Create autoexec.cfg?"
                                alert.informativeText = "Create ~/Documents/GZDoom/autoexec.cfg first?"
                                alert.addButton(withTitle: "Create")
                                alert.addButton(withTitle: "Cancel")
                                if alert.runModal() == .alertFirstButtonReturn {
                                    ensureFile(path)
                                    // After creating, let the user pick an editor again
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .imageScale(.small)
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .help("Open autoexec.cfg in a specific editor.")
                    .fixedSize()
                    Button {
                        let root = store.docsSaveRoot
                        if FileManager.default.fileExists(atPath: root) {
                            NSWorkspace.shared.open(URL(fileURLWithPath: root))
                        } else {
                            info("Save games folder not found", "GZDoom must run and create a save at least once.")
                        }
                    } label: {
                        HStack { Image(systemName: "externaldrive"); Text("Save games") }
                    }
                }
                .buttonStyle(.bordered)
                .padding([.horizontal, .bottom])
            }
        }
    }

    // Detail editor
    private var detail: some View {
        guard let i = store.selectedIndex else {
            return AnyView(Text("No profile selected")
                .foregroundStyle(.secondary).padding())
        }
        return AnyView(ProfileDetail(profile: $store.profiles[i], store: store, privacyMode: privacyMode, compactMode: compactMode))    }

    // MARK: - Subviews
    // (no-op anchor)
    private struct ProfileDetail: View {
        @Binding var profile: Profile
        @ObservedObject var store: AppStore
        let privacyMode: Bool
        let compactMode: Bool
        // Collapsible CLI area (default collapsed to prioritize file list space)
        @State private var showCLI: Bool = false
        @State private var selectedModID: UUID? = nil

        var keepChoices: [Int] = Array(1...30)
        var body: some View {
            ScrollView([.vertical, .horizontal]) {              VStack(alignment: .leading, spacing: 8) {

                    GroupBox("🧭 Paths") {
                        gridRow("GZDoom (.app or binary)") {
                            HStack {
                                TextField("",
                                          text: Binding(
                                            get: { privacyMode ? pathAbbrev(profile.gzdoomPath) : profile.gzdoomPath },
                                            set: { v in profile.gzdoomPath = privacyMode ? pathExpand(v) : v }
                                          )
                                )
                                .textFieldStyle(.roundedBorder)
                                .disabled(profile.locked)
                                .help(privacyMode ? profile.gzdoomPath : "")

                                Button("Choose…") { chooseGZDoom() }
                                    .disabled(profile.locked)
                            }
                        }
                        gridRow("IWAD file (.wad)") {
                            HStack {
                                TextField("",
                                          text: Binding(
                                            get: { privacyMode ? pathAbbrev(profile.iwadFullPath) : profile.iwadFullPath },
                                            set: { v in profile.iwadFullPath = privacyMode ? pathExpand(v) : v }
                                          )
                                )
                                .textFieldStyle(.roundedBorder)
                                .disabled(profile.locked)
                                .help(privacyMode ? profile.iwadFullPath : "")

                                Button("Choose…") { chooseIWAD() }
                                    .disabled(profile.locked)
                            }
                        }
                        gridRow("🛣 Save game folder (for creating save files in, e.g., ~/Documents/GZDoom/mycampaign)") {
                            HStack {
                                TextField("folder name", text: $profile.modFolder)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: profile.modFolder) { _ in store.regenerateCLI() }
                                    .disabled(profile.locked)
                                Menu {
                                    Button("Create…") { createSaveFolder() }
                                    Button("Choose…") { chooseSaveFolder() }
                                } label: {
                                    Label("Choose…", systemImage: "folder.badge.plus")
                                }
                                .disabled(profile.locked)
                            }
                        }
                    }

                    GroupBox("🗂 Mod files and ordering (.pk3 / .wad)") {
                        ScrollViewReader { proxy in
                            VStack(spacing: 8) {
                            // Numbered badge + drag-to-reorder
                            List {
                                ForEach($profile.mods) { $m in
                                    HStack(spacing: 6) {
                                        // Leading index badge (1, 2, 3, …)
                                        Text("\(((profile.mods.firstIndex(where: { $0.id == m.id }) ?? 0) + 1))")
                                            .font(.caption2)
                                            .monospacedDigit()
                                            .frame(width: 30, alignment: .trailing)          // fixed width = consistent alignment
                                            .padding(.vertical, 1).padding(.horizontal, 4)    // slightly slimmer pill
                                            .background(Capsule().fill(.quaternary))
                                            .overlay(Capsule().stroke(.separator.opacity(0.6), lineWidth: 1))
                                            .help("Drag to reorder")

                                        // Enable/disable toggle
                                        Toggle("", isOn: Binding(
                                            get: { m.enabled },
                                            set: { v in m.enabled = v; store.regenerateCLI() }
                                        ))
                                        .labelsHidden()
                                        .disabled(profile.locked)
                                        .accessibilityLabel("Enable \( (m.name as NSString).lastPathComponent )")
                                        .accessibilityHint("Include this mod in the load order.")

                                        // Path label — AppKit-backed horizontal scroller so the bar is always visible
                                        HorizontalScrollLabel(
                                            string: profile.uiShowFilenamesOnly
                                                ? ((m.name as NSString).lastPathComponent)
                                                : (privacyMode ? pathAbbrev(m.name) : m.name)
                                        )
                                        .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedModID = m.id }
                                    .id(m.id)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.accentColor.opacity(0.12))
                                            .opacity(selectedModID == m.id ? 1 : 0)
                                    )
                                }
                                // drag-to-reorder for mods
                                .onMove { indices, newOffset in
                                    profile.mods.move(fromOffsets: indices, toOffset: newOffset)
                                    store.regenerateCLI()
                                }
                                .onChange(of: profile.mods) { _ in
                                    if let id = selectedModID, !profile.mods.contains(where: { $0.id == id }) {
                                        selectedModID = nil
                                    }
                                }
                            }
                            .frame(minHeight: 200,
                                   maxHeight: 360) // prioritize screen real estate for mods
                            .environment(\.defaultMinListRowHeight, 22) // denser rows to fit more
                            HStack {
                                Button("Add Files…") { addFiles() }
                                    .disabled(profile.locked)
                                    .accessibilityHint("Choose PK3 or WAD files to add to this profile.")

                                // Move selected mod Up/Down — placed next to Add Files…
                                Button {
                                    if let id = selectedModID { moveUp(id) }
                                } label: { Image(systemName: "arrow.up") }
                                .help("Move selected mod up")
                                .disabled({
                                    guard let id = selectedModID, !profile.locked,
                                          let i = profile.mods.firstIndex(where: { $0.id == id }) else { return true }
                                    return i == 0
                                }())
                                .accessibilityLabel("Move mod up")

                                Button {
                                    if let id = selectedModID { moveDown(id) }
                                } label: { Image(systemName: "arrow.down") }
                                .help("Move selected mod down")
                                .disabled({
                                    guard let id = selectedModID, !profile.locked,
                                          let i = profile.mods.firstIndex(where: { $0.id == id }) else { return true }
                                    return i >= profile.mods.count - 1
                                }())
                                .accessibilityLabel("Move mod down")

                                // Scroll (not reorder) — distinct chevrons
                                Button {
                                    // Scroll up to previous item (or first), and select it
                                    let items = profile.mods
                                    guard !items.isEmpty else { return }
                                    if let id = selectedModID, let i = items.firstIndex(where: { $0.id == id }) {
                                        let j = max(0, i - 1)
                                        selectedModID = items[j].id
                                        withAnimation { proxy.scrollTo(items[j].id, anchor: .center) }
                                    } else {
                                        selectedModID = items.first!.id
                                        withAnimation { proxy.scrollTo(items.first!.id, anchor: .top) }
                                    }
                                } label: { Image(systemName: "chevron.up") }
                                .help("Scroll to previous mod (selects it)")
                                .disabled(profile.mods.isEmpty)
                                .accessibilityLabel("Scroll up in mods")

                                Button {
                                    // Scroll down to next item (or last), and select it
                                    let items = profile.mods
                                    guard !items.isEmpty else { return }
                                    if let id = selectedModID, let i = items.firstIndex(where: { $0.id == id }) {
                                        let j = min(items.count - 1, i + 1)
                                        selectedModID = items[j].id
                                        withAnimation { proxy.scrollTo(items[j].id, anchor: .center) }
                                    } else {
                                        selectedModID = items.last!.id
                                        withAnimation { proxy.scrollTo(items.last!.id, anchor: .bottom) }
                                    }
                                } label: { Image(systemName: "chevron.down") }
                                .help("Scroll to next mod (selects it)")
                                .disabled(profile.mods.isEmpty)
                                .accessibilityLabel("Scroll down in mods")

                                Spacer()

                                Button(profile.uiShowFilenamesOnly ? "Show Full Paths" : "Show Filenames") {
                                    profile.uiShowFilenamesOnly.toggle()
                                    store.save()
                                }

                                Button("Copy List") {
                                    copyModList(enabledOnly: true, abbreviateHome: privacyMode, filenamesOnly: profile.uiShowFilenamesOnly)
                                }

                                Button("Remove Unchecked") {
                                    profile.mods.removeAll { !$0.enabled }; store.regenerateCLI()
                                }.disabled(profile.locked)

                                Button("Clear") { profile.mods.removeAll(); store.regenerateCLI() }.disabled(profile.locked)
                            }
                            }
                        }
                    }
                GroupBox("🧩 Extra GZDoom arguments (space‑separated; quotes supported)") {
                    TextField("Example: +set vid_fps 1 -width 1920 -height 1080",
                              text: $profile.extraArgs)
                        .textFieldStyle(.roundedBorder)
                        .font(.footnote)
                        .onChange(of: profile.extraArgs) { _ in store.regenerateCLI() }
                        .disabled(profile.locked)
                }

                    GroupBox {
                        DisclosureGroup("🧮 Full Command Line (you can edit or copy)", isExpanded: $showCLI) {
                            VStack(alignment: .leading, spacing: 8) {

                                // Binding that SHOWS "~" when Privacy is ON, but SAVES expanded paths.
                                let editorBinding = Binding<String>(
                                    get: { privacyMode ? abbrevDeep(profile.editedCLI) : profile.editedCLI },
                                    set: { v in
                                        if privacyMode {
                                            var expanded = v.replacingOccurrences(of: "~/", with: HOME + "/")
                                            if expanded == "~" { expanded = HOME }
                                            else { expanded = expanded.replacingOccurrences(of: "~", with: HOME) }
                                            profile.editedCLI = expanded
                                        } else {
                                            profile.editedCLI = v
                                        }
                                    }
                                )

                                // Editor: read-only when Privacy ON and editing not allowed; otherwise editable.
                                ZStack {
                                    TextEditor(
                                        text: (privacyMode && !profile.uiAllowPrivacyCLIEdit)
                                            ? .constant(abbrevDeep(profile.editedCLI))
                                            : editorBinding
                                    )
                                    .accessibilityLabel("Full Command Line, you can edit or copy")
                                    .allowsHitTesting(!(privacyMode && !profile.uiAllowPrivacyCLIEdit))
                                    .font(.system(.footnote, design: .monospaced))
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.quaternary.opacity(privacyMode && !profile.uiAllowPrivacyCLIEdit ? 0.20 : 0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.separator.opacity(0.6), lineWidth: 1)
                                    )
                                    .opacity(privacyMode && !profile.uiAllowPrivacyCLIEdit ? 0.75 : 1.0)
                                    .help(privacyMode && !profile.uiAllowPrivacyCLIEdit
                                          ? "Privacy mode hides your home path as \"~\". Enable the switch below to edit."
                                          : "")

                                    // Subtle lock badge when read-only
                                    if privacyMode && !profile.uiAllowPrivacyCLIEdit {
                                        HStack(spacing: 6) {
                                            Image(systemName: "lock.fill")
                                            Text("Read‑only in Privacy")
                                        }
                                        .accessibilityHidden(true)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.regularMaterial)
                                        .clipShape(Capsule())
                                        .padding(10)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    }
                                }

                                if privacyMode && profile.uiAllowPrivacyCLIEdit {
                                    Text("Privacy is ON and editing is enabled. Edits may include or save full paths.")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }

                                // Always show the toggle (only relevant when Privacy is ON).
                                Toggle("Allow editing while Privacy is ON (⚠︎ may reveal real paths)", isOn: $profile.uiAllowPrivacyCLIEdit)
                                    .onChange(of: profile.uiAllowPrivacyCLIEdit) { _ in store.save() }
                                    .toggleStyle(.switch)
                                    .tint(.orange)
                                    .font(.caption)
                                    .disabled(!privacyMode)
                                    .opacity(privacyMode ? 1 : 0.35)
                                    .help("""
                                    Lets you edit the CLI while Privacy is ON
                                    • Your edits may include or save full paths
                                    • Turn off if you want the CLI to stay read‑only in Privacy
                                    """)

                                HStack {
                                    Button("Regenerate from fields") { store.regenerateCLI() }
                                        .disabled(profile.locked)
                                    Spacer()
                                    // Removed redundant Copy List button
                                }
                            }
                        }
                    }
                /* duplicate onChange(privacyMode) removed */                .onChange(of: privacyMode) { isOn in
                        // Safety: if Privacy is turned OFF, drop the special editing mode.
                        if !isOn {
                            profile.uiAllowPrivacyCLIEdit = false
                            store.save()
                        }
                    }
                    GroupBox("🧳 Backup ini files & save games") {                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Toggle("makeitso.ini", isOn: $profile.backupMakeItSo).disabled(profile.locked)
                                Toggle("gzdoom.ini", isOn: $profile.backupGZIni).disabled(profile.locked)
                                Toggle("autoexec.cfg", isOn: $profile.backupAutoExec).disabled(profile.locked)
                            }
                            Toggle("Selected mod or base save games", isOn: $profile.backupModSaves).disabled(profile.locked)

                            gridRow("Backup destination (defaults to iCloud Drive if not changed)") {
                                HStack {
                                    TextField(
                                        store.defaultBackupRoot,
                                        text: Binding(
                                            get: {
                                                let raw = profile.backupDestPath.isEmpty ? store.defaultBackupRoot : profile.backupDestPath
                                                return privacyMode ? pathAbbrev(raw) : raw
                                            },
                                            set: { v in
                                                let expanded = privacyMode ? pathExpand(v) : v
                                                profile.backupDestPath = (expanded == store.defaultBackupRoot) ? "" : expanded
                                            }
                                        )
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .help(privacyMode ? (profile.backupDestPath.isEmpty ? store.defaultBackupRoot : profile.backupDestPath) : "")
                                    .disabled(profile.locked)

                                    Button("Choose…") {
                                        let p = NSOpenPanel()
                                        p.canChooseFiles = false
                                        p.canChooseDirectories = true
                                        p.allowsMultipleSelection = false
                                        p.directoryURL = store.startURL(for: .backup,
                                                                        fallback: store.defaultBackupRoot)
                                        if p.runModal() == .OK, let url = p.url {
                                            profile.backupDestPath = url.path
                                            store.rememberStart(for: .backup, with: url)
                                        }
                                    }
                                    .disabled(profile.locked)
                                    Button("Show Backups") {
                                        revealInFinder(store.backupDestination(for: profile))
                                    }
                                    .help("Open the backup folder in Finder")
                                }
                            }

                            HStack(spacing: 16) {
                                Toggle("Backup After Run", isOn: $profile.backupAfterRun)
                                    .disabled(profile.locked)

                                HStack(spacing: 6) {
                                    Text("Keep")
                                    Picker("", selection: $profile.backupKeepCount) {
                                        ForEach(keepChoices, id: \.self) { Text("\($0)").tag($0) }
                                    }
                                    .frame(width: 60)
                                    .pickerStyle(.menu)
                                    .disabled(profile.locked)
                                    Text("backups")
                                }

                                HStack(spacing: 6) {                                    Text("Compress")
                                    Picker("", selection: $profile.backupZip) {
                                        Text("Yes").tag(true); Text("No").tag(false)
                                    }
                                    .frame(width: 70)
                                    .pickerStyle(.menu)
                                    .disabled(profile.locked)
                                }

                                Spacer()
                                Button("Back Up Now") { store.backupNow() }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
            }
            .padding(10)
            .environment(\.controlSize, .small)
        }
        .scrollIndicators(.visible)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: profile) { _ in store.save() }
        }
        // Copies the current mod list (checked items, in order) to the clipboard.
        // Paths under your home folder are abbreviated to "~" for sharing.
        private func copyModList(enabledOnly: Bool = true, abbreviateHome: Bool = true, filenamesOnly: Bool = false) {
            let home = NSHomeDirectory()
            let items = profile.mods
                .filter { !enabledOnly || $0.enabled }
                .map { filenamesOnly ? (($0.name as NSString).lastPathComponent) : $0.name }
                .map { p -> String in
                    guard abbreviateHome, !filenamesOnly, p.hasPrefix(home + "/") else { return p }
                    return "~" + p.dropFirst(home.count)
                }

            let text = items.joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        private func remove(_ id: UUID) {
            profile.mods.removeAll { $0.id == id }; store.regenerateCLI()
        }
        private func moveUp(_ id: UUID) {
            guard let i = profile.mods.firstIndex(where: { $0.id == id }), i > 0 else { return }
            profile.mods.swapAt(i, i - 1); store.regenerateCLI()
        }
        private func moveDown(_ id: UUID) {
            guard let i = profile.mods.firstIndex(where: { $0.id == id }), i < profile.mods.count - 1 else { return }
            profile.mods.swapAt(i, i + 1); store.regenerateCLI()
        }

        private func addFiles() {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.directoryURL = store.startURL(for: .addfiles, fallback: store.supportDir)
            panel.allowedContentTypes = [
                UTType(filenameExtension: "pk3")!,
                UTType(filenameExtension: "wad")!
            ]
            if panel.runModal() == .OK {
                for url in panel.urls {
                    let path = url.path
                    if !profile.mods.contains(where: { $0.name == path }) {
                        profile.mods.append(ModEntry(name: path, enabled: true))
                    }
                    store.rememberStart(for: .addfiles, with: url)
                }
                store.regenerateCLI()
            }
        }

        private func chooseGZDoom() {
            // Start in Applications (or last-remembered)
            let start = store.startURL(for: .gzdoom, fallback: "/Applications")

            let panel = NSOpenPanel()
            panel.directoryURL = start
            panel.allowsMultipleSelection = false
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.treatsFilePackagesAsDirectories = true
            panel.allowedContentTypes = [UTType.application, UTType.item]

            if panel.runModal() == .OK, let url = panel.url {
                profile.gzdoomPath = url.path
                store.rememberStart(for: .gzdoom, with: url)
                store.regenerateCLI()
            }
        }

        private func chooseIWAD() {
            ensureGZSupportExistsPrompting()
            let start = store.startURL(for: .iwad,
                                       fallback: (NSHomeDirectory() as NSString)
                                        .appendingPathComponent("Library/Application Support/gzdoom"))
            let panel = NSOpenPanel()
            panel.directoryURL = start
            panel.allowsMultipleSelection = false
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [UTType(filenameExtension: "wad")!]
            if panel.runModal() == .OK, let url = panel.url {
                profile.iwadFullPath = url.path
                store.rememberStart(for: .iwad, with: url)
                store.regenerateCLI()
            }
        }

        private func createSaveFolder() {
            let root = store.docsSaveRoot
            let path = (root as NSString).appendingPathComponent(profile.modFolder)
            if FileManager.default.fileExists(atPath: path) {
                info("Folder already exists", path)
            } else {
                ensureDir(path); info("Created", path)
            }
        }

        private func chooseSaveFolder() {
            let start = store.startURL(for: .saves, fallback: store.docsSaveRoot)
            let p = NSOpenPanel()
            p.canChooseFiles = false
            p.canChooseDirectories = true
            p.allowsMultipleSelection = false
            p.directoryURL = start
            if p.runModal() == .OK, let url = p.url {
                profile.modFolder = url.lastPathComponent
                store.rememberStart(for: .saves, with: url)
                store.regenerateCLI()
            }
        }

        private func ensureGZSupportExistsPrompting() {
            let dir = store.supportDir
            if !FileManager.default.fileExists(atPath: dir) {
                let alert = NSAlert()
                alert.messageText = "Create gzdoom support folder?"
                alert.informativeText = "Create: \(dir)"
                alert.addButton(withTitle: "Create")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn { ensureDir(dir) }
            }
        }

        @ViewBuilder
        private func gridRow(_ title: String, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                content()
            }
        }
    }
}

// MARK: - Rename sheet

private struct RenameSheet: View {
    let currentName: String
    let onCommit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(currentName: String, onCommit: @escaping (String) -> Void) {
        self.currentName = currentName
        self.onCommit = onCommit
        _name = State(initialValue: currentName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename Profile").font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { commit() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func commit() { onCommit(name.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() }
}

// MARK: - App
/// App delegate to supply a dynamic Dock (right‑click) menu
final class DockAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let store = dockStore else { return nil }
        let menu = NSMenu()

        // Curated list: only profiles with showInDockMenu == true
        let pins = store.profiles.filter { $0.showInDockMenu }
        if pins.isEmpty {
            let item = NSMenuItem(title: "No profiles pinned to Dock Menu", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }

        for p in pins {
            let item = NSMenuItem(title: p.name, action: #selector(launchProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = p.id
            menu.addItem(item)
        }
        return menu
    }

    @MainActor @objc private func launchProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let store = dockStore else { return }
        store.selectedProfileID = id
        store.engage()
    }
}
@main
struct Make_It_SoApp: App {
    @NSApplicationDelegateAdaptor(DockAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
            .commands {
                // Help menu
                CommandGroup(replacing: .help) {
                    Button("Quick Start Guide") { showHelpGuide(anchor: .quickStart) }
                    Button("Manual…") { showHelpGuide(anchor: .manual) }
                    Divider()
                    Button("License (MIT)…") { showLicense() }
                }
                // App menu (About)
                CommandGroup(replacing: .appInfo) {
                    Button("About Make It So") { showAbout() }
                }
            }
    }
}

// MARK: - Helpers
// MARK: - AppKit-backed horizontal scroller for single-line text
struct HorizontalScrollLabel: NSViewRepresentable {
    let string: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = false         // show the bar, not just on scroll
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.verticalScrollElasticity = .none
        scroll.horizontalScrollElasticity = .automatic

        let label = NSTextField(labelWithString: string)
        label.usesSingleLineMode = true
        label.lineBreakMode = .byClipping
        label.isSelectable = true                 // allow copy/select like before
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = true
        label.sizeToFit()

        scroll.documentView = label
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let label = scroll.documentView as? NSTextField else { return }
        if label.stringValue != string {
            label.stringValue = string
            label.sizeToFit()                     // keep content width correct for scrolling
        }
    }
}


// MARK: - Help Guide and Embedded Manual (with deep‑linking)
private var dockStore: AppStore?
private enum HelpAnchor { case quickStart, manual }

private var helpWindow: NSWindow?

private func showHelpGuide(anchor: HelpAnchor = .quickStart) {
    // Create (once) or reuse the same window, but always refresh its content
    let root = NSHostingView(rootView: HelpGuideView(initialAnchor: anchor))
    root.frame = .init(x: 0, y: 0, width: 520, height: 600)

    if let w = helpWindow {
        w.contentView = root
        w.makeKeyAndOrderFront(nil)
        return
    }

    let w = NSWindow(
        contentRect: .init(x: 0, y: 0, width: 520, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered, defer: false
    )
    w.title = "🌟 Quick Start + 📘 Manual"
    w.center()
    w.isReleasedWhenClosed = false
    w.contentView = root
    w.makeKeyAndOrderFront(nil)
    helpWindow = w
}

private struct HelpGuideView: View {
    let initialAnchor: HelpAnchor
    @State private var currentAnchor: HelpAnchor

    init(initialAnchor: HelpAnchor) {
        self.initialAnchor = initialAnchor
        _currentAnchor = State(initialValue: initialAnchor)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Quick Start
                    Text("🌟 Quick Start Guide")
                        .font(.title2).bold()
                        .id("quickStart")

                    section("🚀 What does **Engage** do?", """
    Launch GZDoom using the current profile’s settings:
    • IWAD
    • Mod list (suggested order):
      – Map (custom map or campaign)
      – Mod (core gameplay changes)
      – Add-ons (visuals, UI, QoL, etc.)
    • Extra arguments
    • Save game folder
    • GZDoom binary path
    """)

                    section("🛠 What does **Build** do?", """
    Creates two files for this profile **in a folder you choose**:
    • A shell script: “ProfileName.sh”
      – Launches GZDoom with the exact settings for this profile
    • A mini macOS app: “ProfileName.app”
      – Double‑click to run the script without Terminal
    Tips:
    • You can move the .app anywhere (Dock, Desktop, etc.)
    • Keep the .sh where you built it, so the .app can find it
    • Re‑run Build to overwrite these files in the same folder
    """)

                    section("🛡️ What does **Privacy** do?", """
    • Hides your home path as “~” in fields and the CLI preview
    • Saves your real paths under the hood (full absolute paths)
    • Makes the CLI read‑only while Privacy is ON — unless you enable
      “Allow editing while Privacy is ON”
    """)

                    section("🔒 What does **Lock** do?", """
                    • Prevents changes to Paths, Mods, Extra Args, and Backup options
                    • You can still **Engage**, **Build**, and **Back Up Now**, and you can click **Show Backups**
                    • Click the lock again to unlock and allow editing
                    """)

                    section("📌 What does **Pin to Dock Menu** do?", """
                    • Adds the profile to the app’s Dock menu (right-click the icon)
                    • Lets you quickly Engage from outside the app
                    • Toggle it on/off per profile or with the sidebar button
                    """)

                    section("📤 How do I **Import / Export Profiles**?", """
                    • Use **Export** to save selected or all profiles as JSON
                    • Use **Import** to load profiles from another system or user
                    • Paths are localized and adjusted automatically when importing
                    """)

                    section("📝 Editing Config Files", """
Use the built‑in Edit buttons next to the config files to open them in your preferred editor:
• **makeitso.ini** — launcher settings
• **gzdoom.ini** — GZDoom preferences
• **autoexec.cfg** — launch-time console commands
• **Save games** — opens the save game locations folder in Finder

Supported editors (detected automatically): **TextEdit**, **BBEdit**, **CotEditor**, **Visual Studio Code**, **Sublime Text**, **Nova**. You can also choose **Another App…**.

> These files are **plain text**. In your editor, use **Plain Text** mode (no rich text).
""")

                    Divider().padding(.top, 4)

                    // Manual
                    Text("📘 Full Manual")
                        .font(.title2).bold()
                        .padding(.top, 4)
                        .id("manual")

                    Text(.init(fullManualText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(20)
            }
            .frame(minWidth: 520, minHeight: 600)
            .onAppear {
                // Scroll to requested section after layout
                DispatchQueue.main.async {
                    let target = (currentAnchor == .manual) ? "manual" : "quickStart"
                    withAnimation { proxy.scrollTo(target, anchor: .top) }
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(.init(title)).font(.headline)
            Text(.init(body))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
        Divider()
    }
}

#warning("manual: update Save games bullet")
private let fullManualText = """
# ✨ Make It So – User Manual

Welcome to **Make It So**, a GZDoom launcher for macOS that focuses on clarity, backups, script generation, and ease of use.

## 🧭 Features

• Per-profile mod loadout and IWAD paths  
• GZDoom `.app` or raw binary support  
• Read-only Privacy mode with toggleable CLI editing  
• Save folder name customization (under `~/Documents/GZDoom/`)  
• Backup system for `gzdoom.ini`, `makeitso.ini`, `autoexec.cfg`, and save games  
• Shell script (`.sh`) + macOS `.app` launcher generation  
• Built-in `Engage` and `Build` support  
• Editable CLI preview for advanced users  
• One-file architecture for easier open-source sharing  
• **Pin profiles to launch from the Dock**  
• **Import/Export profiles via shareable JSON**

## 👤 Profiles

Each profile remembers:

• GZDoom binary path (`.app` or raw)  
• IWAD file (`.wad`)  
• Mod list and order  
• Save game folder name (under `~/Documents/GZDoom/`)  
• Extra command-line args  
• Backup settings  
• Zip preferences and retention count  
• Privacy toggles  
• CLI preview (editable or regenerated)

Use the +, duplicate, delete, and up/down arrow buttons to manage and reorder profiles. Right‑click for quick actions (Engage, Build, Rename, Duplicate, Delete, Pin to Dock Menu).

## 🛡️ Privacy Mode

When Privacy Mode is enabled:

• All home-path fields display `~` instead of your full user folder  
• The CLI preview becomes read-only unless explicitly overridden  
• Paths are still saved with full accuracy behind the scenes  
• Great for screenshots, sharing, or public displays

## 🏗 Build Artifacts

Clicking **Build** generates two files in a folder you choose:

• `ProfileName.sh` — a portable, shareable bash script  
• `ProfileName.app` — a macOS app that runs the script without Terminal  

These artifacts are self-contained and use all profile settings.

## ⚡ Engage vs Build

• **Engage** runs the selected profile immediately within the app  
• **Build** produces files for later use outside the app (ideal for Dock icons)

## 🧳 Backups

Profiles include full control over what to back up:

• `makeitso.ini` — the launcher config file  
• `gzdoom.ini` — GZDoom preferences  
• `autoexec.cfg` — launch-time console config  
• Save games — for selected mod/base folder  
• Compression toggle (ZIP or plain)  
• “Backup After Run” toggle  
• Retention count (1–30) with pruning

Backups are stored under a destination of your choosing. Defaults to iCloud Drive if not changed.

## 📌 Pin to Dock Menu

• Add any profile to the app’s Dock menu  
• Right-click the Dock icon to launch pinned profiles  
• You can pin/unpin via right-click or the sidebar button  

## 📤 Import / Export Profiles

• Export selected or all profiles as JSON  
• Import profiles from another Mac or user  
• The app adjusts file paths and prevents conflicts  
• Exported paths use `~` for privacy  

## 📝 Editing Config Files

Use the built‑in Edit buttons to open or create these plain‑text files:

• **makeitso.ini** — Make It So launcher settings  
• **gzdoom.ini** — GZDoom preferences  
• **autoexec.cfg** — launch-time console commands  
• **Save games** — opens the save game locations folder in Finder  

**Supported editors:** TextEdit, BBEdit, CotEditor, Visual Studio Code, Sublime Text, Nova.  
You can also choose **Another App…** from the menu.  

> These files are **plain text**. In your editor, enable **Plain Text** mode (no rich text).

## 💡 Tips

• Use `Privacy Mode` before screen sharing or posting screenshots  
• Right-click profiles for quick Engage, Build, Rename, etc.  
• Click lock icon to toggle profile editability  
• CLI is read-only in Privacy unless explicitly enabled  
• All scripts generated are bash-compatible and portable  
• Use the `Manual…` and `Quick Start Guide` under Help for reference

## 📬 Support

[Email Support](mailto:makeitsoapp@proton.me?subject=Make%20It%20So)  
GitHub: Please fork and contribute if useful
"""

// MARK: - Embedded License (MIT)

private var licenseWindow: NSWindow?

private func showLicense() {
    let view = NSHostingView(rootView:
        ScrollView {
            Text(embeddedLicenseText)
                .font(.system(.body, design: .monospaced))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 560, minHeight: 520)
    )

    if let w = licenseWindow {
        w.contentView = view
        w.makeKeyAndOrderFront(nil)
        return
    }

    let w = NSWindow(
        contentRect: .init(x: 0, y: 0, width: 560, height: 520),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered, defer: false
    )
    w.title = "License (MIT)"
    w.center()
    w.isReleasedWhenClosed = false
    w.contentView = view
    w.makeKeyAndOrderFront(nil)
    licenseWindow = w
}

private let embeddedLicenseText = """
MIT License

Copyright (c) 2025 BobQuickSaveSmith

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights 
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
"""
private let HOME = NSHomeDirectory()

/// Abbreviate absolute paths under the user's home to "~"
private func pathAbbrev(_ p: String) -> String {
    if p == HOME { return "~" }
    if p.hasPrefix(HOME + "/") { return "~" + p.dropFirst(HOME.count) }
    return p
}

/// Expand "~" back to absolute paths (not used for display, but handy if you allow editing in privacy mode later)
private func pathExpand(_ p: String) -> String {
    if p == "~" { return HOME }
    if p.hasPrefix("~/") { return (HOME as NSString).appendingPathComponent(String(p.dropFirst(2))) }
    return p
}

/// Abbreviate *all* occurrences of the home path inside larger strings (for CLI preview text)
private func abbrevDeep(_ s: String) -> String {
    s
        .replacingOccurrences(of: HOME + "/", with: "~/")
        .replacingOccurrences(of: HOME, with: "~")
}
/// Strong scrub for exports: replace current HOME *and* any /Users/<name> prefix with "~"
private func scrubCLIForExport(_ s: String) -> String {
    var v = s
    // First, do precise HOME substitutions.
    v = v
        .replacingOccurrences(of: HOME + "/", with: "~/")
        .replacingOccurrences(of: HOME, with: "~")

    // Then, catch any other absolute user paths not matching our HOME (e.g., copied profiles).
    // Example: ~/…  →  ~/…
    if let re = try? NSRegularExpression(pattern: #"/Users/[^/]+"#) {
        let ns = v as NSString
        let full = NSRange(location: 0, length: ns.length)
        v = re.stringByReplacingMatches(in: v, options: [], range: full, withTemplate: "~")
    }
    return v
}

private func resolveGZDOOMBinary(from path: String) -> String {
    if path.hasSuffix(".app") {
        return (path as NSString).appendingPathComponent("Contents/MacOS/gzdoom")
    }
    return path
}
private func ensureDir(_ path: String) {
    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
}
private func ensureFile(_ path: String) {
    if !FileManager.default.fileExists(atPath: path) {
        FileManager.default.createFile(atPath: path, contents: Data())
    }
}
private func revealInFinder(_ path: String) {
    let url = URL(fileURLWithPath: path)
    NSWorkspace.shared.activateFileViewerSelecting([url])
}
private func needsQuoting(_ s: String) -> Bool {
    s.contains(" ") || s.contains("\"") || s.contains("'")
}
private func splitCLI(_ s: String) -> [String] {
    var args: [String] = [], cur = ""; var mode: Character? = nil
    for ch in s {
        if mode == nil {
            if ch == "\"" || ch == "'" { mode = ch; continue }
            if ch.isWhitespace { if !cur.isEmpty { args.append(cur); cur.removeAll() }; continue }
            cur.append(ch)
        } else { if ch == mode { mode = nil; continue }; cur.append(ch) }
    }
    if !cur.isEmpty { args.append(cur) }
    return args
}
private func ts() -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm-ss"; return f.string(from: Date()) }
@discardableResult
private func runSync(_ argv: [String], cwd: String? = nil) -> (exitCode: Int32, output: String) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: argv.first!)
    task.arguments = Array(argv.dropFirst())
    if let cwd { task.currentDirectoryURL = URL(fileURLWithPath: cwd) }
    let pipe = Pipe(); task.standardOutput = pipe; task.standardError = pipe
    do { try task.run() } catch { return (1, error.localizedDescription) }
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}
private func info(_ title: String, _ text: String = "") {
    let a = NSAlert(); a.messageText = title; a.informativeText = text; a.addButton(withTitle: "OK"); a.runModal()
}

private func showAbout() {
    let alert = NSAlert()
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    let versionLine = build.isEmpty ? "Version \(appVersion)" : "Version \(appVersion) (\(build))"
    alert.messageText = "Make It So"
    alert.informativeText = """
    \(versionLine)

    Make It So is an unofficial, fan‑made launcher for GZDoom and DOOM‑compatible files.

    DOOM is a registered trademark of id Software LLC, a ZeniMax Media company. 
    GZDoom is a separate, third‑party project owned by its respective developers.
    This app is not affiliated with, endorsed by, or sponsored by id Software, ZeniMax, or the GZDoom developers.

    Provided “AS IS”, without warranty of any kind. Use at your own risk.

    Support: makeitsoapp@proton.me
    """
    alert.addButton(withTitle: "Email Support")
    alert.addButton(withTitle: "Close")
    if alert.runModal() == .alertFirstButtonReturn,
       let url = URL(string: "mailto:makeitsoapp@proton.me?subject=Make%20It%20So") {
        NSWorkspace.shared.open(url)
    }
}




