import SwiftUI

/// Lets any screen ask the app to show "You've been here" for a visit, so there is only ever one
/// rating sheet (two sheets at once would make SwiftUI drop one).
struct ReviewVisitAction {
    let open: (Visit) -> Void

    func callAsFunction(_ visit: Visit) { open(visit) }
}

private struct ReviewVisitKey: EnvironmentKey {
    static let defaultValue = ReviewVisitAction { _ in }
}

extension EnvironmentValues {
    var reviewVisit: ReviewVisitAction {
        get { self[ReviewVisitKey.self] }
        set { self[ReviewVisitKey.self] = newValue }
    }
}
