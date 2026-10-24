import Foundation
import EventKit
import Combine

struct AgendaEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let calendar: String

    var timeLabel: String {
        if allDay { return "All day".tr }
        return start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale))
    }
}

@MainActor protocol HomePadAgendaClient: AnyObject {
    var authorization: EKAuthorizationStatus { get }
    func requestAuthorization() async throws -> Bool
    func events(from start: Date, to end: Date) -> [AgendaEvent]
    func observeChanges(_ update: @escaping () -> Void)
    func stopObservingChanges()
}

/// EventKit exposes full access for reading on iPadOS 17+. HomePad only reads;
/// it never creates, edits or deletes an event, and never requests Reminders.
@MainActor final class NativeHomePadAgendaClient: HomePadAgendaClient {
    private var eventStore: EKEventStore?
    private var observation: NSObjectProtocol?
    var authorization: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .event) }
    private var store: EKEventStore {
        if let eventStore { return eventStore }
        let value = EKEventStore(); eventStore = value; return value
    }
    func requestAuthorization() async throws -> Bool { try await store.requestFullAccessToEvents() }
    func events(from start: Date, to end: Date) -> [AgendaEvent] {
        guard authorization == .fullAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { $0.status != .canceled && $0.endDate > start }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return ($0.title ?? "") < ($1.title ?? "")
            }
            .prefix(30)
            .map { event in
                AgendaEvent(id: "\(event.eventIdentifier ?? event.calendarItemIdentifier)-\(event.startDate.timeIntervalSinceReferenceDate)",
                            title: event.title ?? "Untitled event".tr, start: event.startDate, end: event.endDate,
                            allDay: event.isAllDay, calendar: event.calendar.title)
            }
    }
    func observeChanges(_ update: @escaping () -> Void) {
        stopObservingChanges()
        observation = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            Task { @MainActor in update() }
        }
    }
    func stopObservingChanges() {
        if let observation { NotificationCenter.default.removeObserver(observation) }
        observation = nil
    }
    deinit { if let observation { NotificationCenter.default.removeObserver(observation) } }
}

@MainActor final class AgendaStore: ObservableObject {
    enum State: Equatable { case disconnected, connecting, ready, denied, restricted, unavailable }
    @Published private(set) var state: State = .disconnected
    @Published private(set) var events: [AgendaEvent] = []
    @Published private(set) var error: String?
    private let client: HomePadAgendaClient
    private let now: () -> Date
    private var enabled = false
    private var active = true
    private var demo = false
    private var generation = UUID()
    private var task: Task<Void, Never>?

    init(client: HomePadAgendaClient? = nil, now: @escaping () -> Date = Date.init) {
        self.client = client ?? NativeHomePadAgendaClient(); self.now = now
    }
    var eventLines: [String] { events.prefix(5).map { "\($0.timeLabel) · \($0.title)" } }
    var statusTitle: String {
        switch state {
        case .disconnected: "Not connected".tr
        case .connecting: "Connecting…".tr
        case .ready: events.isEmpty ? "Nothing in the next 7 days".tr : "Next 7 days".tr
        case .denied: "Calendar access is off".tr
        case .restricted: "Calendar access is restricted".tr
        case .unavailable: "Unable to load calendar".tr
        }
    }
    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        enabled = value
        if value { refresh() } else { clear() }
    }
    func setDemo(_ value: Bool) {
        guard demo != value else { return }
        demo = value
        clear()
        if !value { refresh() }
    }
    func setActive(_ value: Bool) {
        guard active != value else { return }
        active = value
        if value { refresh() } else { clear() }
    }
    /// The view sets its shared-screen intent and calls connect from an explicit
    /// user tap. Passive refreshes never trigger a system permission prompt.
    func connect() {
        guard active, !demo, state != .connecting else { return }
        enabled = true
        generation = UUID(); task?.cancel(); client.stopObservingChanges()
        let token = generation
        state = .connecting; events = []; error = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let granted = try await client.requestAuthorization()
                guard valid(token) else {
                    if granted, active, !demo, enabled, client.authorization == .fullAccess, state != .connecting {
                        // Run outside the cancelled permission task so its
                        // cancellation flag cannot suppress a passive refresh.
                        Task { [weak self] in self?.refresh() }
                    }
                    return
                }
                guard granted, client.authorization == .fullAccess else { applyAuthorization(); return }
                readEvents(token: token)
            } catch {
                guard valid(token) else { return }
                if client.authorization == .denied || client.authorization == .restricted || client.authorization == .writeOnly {
                    applyAuthorization(); return
                }
                events = []; state = .unavailable; self.error = error.localizedDescription
            }
        }
    }
    func refresh() {
        guard active, !demo, enabled, state != .connecting else { return }
        guard client.authorization == .fullAccess else { applyAuthorization(); return }
        let token = generation
        readEvents(token: token)
    }
    func disconnect() { enabled = false; clear() }
    private func readEvents(token: UUID) {
        guard valid(token), client.authorization == .fullAccess else { return }
        let start = now()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86400)
        let result = client.events(from: start, to: end)
        guard valid(token), client.authorization == .fullAccess else { applyAuthorization(); return }
        events = result; state = .ready; error = nil
        client.observeChanges { [weak self] in
            guard let self, self.valid(token) else { return }
            self.refresh()
        }
    }
    private func applyAuthorization() {
        clear()
        switch client.authorization {
        case .denied, .writeOnly: state = .denied
        case .restricted: state = .restricted
        default: state = .disconnected
        }
    }
    private func valid(_ token: UUID) -> Bool { token == generation && enabled && active && !demo && !Task.isCancelled }
    private func clear() {
        generation = UUID(); task?.cancel(); task = nil; client.stopObservingChanges()
        events = []; error = nil; state = .disconnected
    }
}
