import Foundation
import Combine
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var tasks: [Task] = []
    @Published private(set) var currentTaskID: UUID?
    @Published var draftName: String = ""
    @Published private(set) var elapsedDisplay: String = "00:00"
    @Published private(set) var historyMRU: [String] = []

    private var timer: Timer?
    private var saveWorkItem: DispatchWorkItem?

    init() {
        let store = Persistence.load()
        self.tasks = store.tasks
        rebuildHistoryMRU()
        if let runningIdx = store.tasks.firstIndex(where: { $0.isRunning }) {
            self.currentTaskID = store.tasks[runningIdx].id
            startTimer()
        }
        recomputeElapsed()
    }

    // MARK: - Derived state

    var currentTask: Task? {
        guard let id = currentTaskID else { return nil }
        return tasks.first(where: { $0.id == id })
    }

    var isRunning: Bool { currentTask?.isRunning == true }
    var isPaused: Bool { currentTask != nil && currentTask?.isRunning == false }

    // MARK: - Mutations

    /// Defense-in-depth: cap the task name and strip control characters before
    /// it lands in persistence, the menu bar, or CSV exports.
    private static let maxNameLength = 200
    private static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = String(trimmed.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
        if cleaned.count <= maxNameLength { return cleaned }
        return String(cleaned.prefix(maxNameLength))
    }

    func startTask(name rawName: String) {
        let name = Self.sanitize(rawName)
        guard !name.isEmpty else { return }
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)

        // Same name as the current task AND that task has activity today → resume in place.
        // (Catches paused-and-resumed-same-day, including intervals that crossed midnight.)
        if let id = currentTaskID, let idx = tasks.firstIndex(where: { $0.id == id }),
           tasks[idx].name.caseInsensitiveCompare(name) == .orderedSame,
           tasks[idx].intervals.contains(where: { ($0.end ?? now) >= todayStart }) {
            if !tasks[idx].isRunning {
                tasks[idx].intervals.append(Interval(start: now))
                tasks[idx].lastUsed = now
                startTimer()
            }
            draftName = ""
            recomputeElapsed()
            scheduleSave()
            return
        }

        // Different task — end the current one cleanly, then start fresh.
        endCurrentTask()

        let interval = Interval(start: now)

        // Resume a same-name task only if it already has activity today.
        // Otherwise create a new instance for today so each day's totals stay separate.
        if let idx = tasks.firstIndex(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame &&
            $0.intervals.contains(where: { ($0.end ?? now) >= todayStart })
        }) {
            tasks[idx].intervals.append(interval)
            tasks[idx].lastUsed = now
            currentTaskID = tasks[idx].id
        } else {
            let task = Task(name: name, intervals: [interval], lastUsed: now)
            tasks.append(task)
            currentTaskID = task.id
        }
        rebuildHistoryMRU()
        draftName = ""
        startTimer()
        recomputeElapsed()
        scheduleSave()
    }

    func pauseResume() {
        guard let id = currentTaskID, let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        if tasks[idx].isRunning {
            closeOpenInterval()
            stopTimer()
        } else {
            tasks[idx].intervals.append(Interval(start: Date()))
            tasks[idx].lastUsed = Date()
            startTimer()
        }
        recomputeElapsed()
        scheduleSave()
    }

    func endCurrentTask() {
        closeOpenInterval()
        currentTaskID = nil
        stopTimer()
        recomputeElapsed()
        scheduleSave()
    }

    /// Insert a closed historical interval without disturbing the currently-running task.
    /// If a task with this name already exists it gets a new interval appended; otherwise
    /// a new task is created.
    func addManualEntry(name rawName: String, start: Date, end: Date) {
        let name = Self.sanitize(rawName)
        guard !name.isEmpty, end > start else { return }
        let interval = Interval(start: start, end: end)
        let entryDayStart = Calendar.current.startOfDay(for: start)
        let entryDayEnd = Calendar.current.date(byAdding: .day, value: 1, to: entryDayStart) ?? entryDayStart

        // Match a same-name task only if it already has activity on the entry's day; otherwise
        // create a fresh per-day instance so day totals stay isolated.
        if let idx = tasks.firstIndex(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame &&
            $0.intervals.contains(where: { $0.start >= entryDayStart && $0.start < entryDayEnd })
        }) {
            tasks[idx].intervals.append(interval)
            tasks[idx].lastUsed = max(tasks[idx].lastUsed, end)
        } else {
            let task = Task(name: name, intervals: [interval], lastUsed: end)
            tasks.append(task)
        }
        rebuildHistoryMRU()
        scheduleSave()
    }

    // MARK: - Per-interval edits (from breakdown context menu)

    struct IntervalRef: Identifiable, Hashable {
        let taskID: UUID
        let interval: Interval
        var id: UUID { interval.id }
        var start: Date { interval.start }
        var end: Date? { interval.end }
    }

    /// All intervals contributing to a breakdown row (case-insensitive name match,
    /// intersecting the visible range), ordered by start time.
    func intervalRefs(forBreakdownNamed name: String, range: ChartRange, now: Date = Date()) -> [IntervalRef] {
        let windowStart = Aggregator.windowStart(for: range, now: now)
        var refs: [IntervalRef] = []
        for t in tasks where t.name.caseInsensitiveCompare(name) == .orderedSame {
            for iv in t.intervals {
                let end = iv.end ?? now
                if end > windowStart {
                    refs.append(IntervalRef(taskID: t.id, interval: iv))
                }
            }
        }
        return refs.sorted { $0.interval.start < $1.interval.start }
    }

    /// Edit the start/end of a closed interval. Preserves the interval's UUID.
    func updateInterval(taskID: UUID, intervalID: UUID, start: Date, end: Date) {
        guard end > start,
              let ti = tasks.firstIndex(where: { $0.id == taskID }),
              let ii = tasks[ti].intervals.firstIndex(where: { $0.id == intervalID })
        else { return }
        // Don't let the user blow up the live interval — that's owned by the timer.
        if tasks[ti].intervals[ii].isOpen { return }
        tasks[ti].intervals[ii] = Interval(id: intervalID, start: start, end: end)
        tasks[ti].lastUsed = max(tasks[ti].lastUsed, end)
        recomputeElapsed()
        scheduleSave()
    }

    /// Remove a single interval. If it was the task's last interval, the task is dropped.
    func deleteInterval(taskID: UUID, intervalID: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskID }),
              let ii = tasks[ti].intervals.firstIndex(where: { $0.id == intervalID })
        else { return }
        if tasks[ti].intervals[ii].isOpen { return } // protect the running interval
        tasks[ti].intervals.remove(at: ii)
        if tasks[ti].intervals.isEmpty {
            tasks.remove(at: ti)
        }
        rebuildHistoryMRU()
        recomputeElapsed()
        scheduleSave()
    }

    func clearAllData() {
        stopTimer()
        currentTaskID = nil
        tasks = []
        draftName = ""
        historyMRU = []
        recomputeElapsed()
        Persistence.deleteStore()
        saveWorkItem?.cancel()
    }

    // MARK: - Private helpers

    private func closeOpenInterval() {
        guard let id = currentTaskID, let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        if let last = tasks[idx].intervals.indices.last, tasks[idx].intervals[last].isOpen {
            tasks[idx].intervals[last].end = Date()
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.recomputeElapsed() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func recomputeElapsed() {
        guard let task = currentTask else {
            if elapsedDisplay != "00:00" { elapsedDisplay = "00:00" }
            return
        }
        let secs = Int(task.totalSeconds)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        let next = h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
        if elapsedDisplay != next { elapsedDisplay = next }
    }

    private func rebuildHistoryMRU() {
        var seen = Set<String>()
        var out: [String] = []
        for t in tasks.sorted(by: { $0.lastUsed > $1.lastUsed }) {
            let key = t.name.lowercased()
            if seen.insert(key).inserted {
                out.append(t.name)
            }
        }
        historyMRU = out
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = Store(schemaVersion: Persistence.currentSchema, tasks: tasks)
        let work = DispatchWorkItem { Persistence.save(snapshot) }
        saveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        Persistence.save(Store(schemaVersion: Persistence.currentSchema, tasks: tasks))
    }
}
