import Foundation
import Testing
@testable import StudyAbroad

struct AutoAddRuleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func allIncludesEverythingEvenUndated() {
        let rule = AutoAddRule(mode: .all)

        #expect(rule.includes(date(2027, 1, 5), calendar: calendar))
        #expect(rule.includes(nil, calendar: calendar))
    }

    @Test func offIncludesNothing() {
        let rule = AutoAddRule(mode: .off)

        #expect(!rule.includes(date(2027, 1, 5), calendar: calendar))
        #expect(!rule.includes(nil, calendar: calendar))
    }

    @Test func fromIncludesTheWholeStartDay() {
        // Chosen at 6 pm, but a photo from 8 am the same day still counts.
        let rule = AutoAddRule(mode: .from, start: date(2027, 1, 3, 18))

        #expect(rule.includes(date(2027, 1, 3, 8), calendar: calendar))
        #expect(rule.includes(date(2027, 6, 1), calendar: calendar))
        #expect(!rule.includes(date(2027, 1, 2, 23), calendar: calendar))
        #expect(!rule.includes(nil, calendar: calendar))
    }

    @Test func betweenIncludesBothEndDaysCompletely() {
        let rule = AutoAddRule(mode: .between, start: date(2027, 1, 3), end: date(2027, 1, 10))

        #expect(rule.includes(date(2027, 1, 3, 0), calendar: calendar))
        #expect(rule.includes(date(2027, 1, 10, 23), calendar: calendar))
        #expect(!rule.includes(date(2027, 1, 2, 23), calendar: calendar))
        #expect(!rule.includes(date(2027, 1, 11, 0), calendar: calendar))
        #expect(!rule.includes(nil, calendar: calendar))
    }

    @Test func betweenWorksWhenDatesAreTheWrongWayRound() {
        let rule = AutoAddRule(mode: .between, start: date(2027, 1, 10), end: date(2027, 1, 3))

        #expect(rule.includes(date(2027, 1, 5), calendar: calendar))
    }

    @Test func savesAndLoadsTheSetting() throws {
        let defaults = try #require(UserDefaults(suiteName: "AutoAddRuleTests-\(UUID().uuidString)"))
        let rule = AutoAddRule(mode: .between, start: date(2027, 1, 3), end: date(2027, 2, 1))

        rule.save(to: defaults)

        #expect(AutoAddRule.load(from: defaults) == rule)
    }

    @Test func defaultsToAllPhotosSoNothingDisappearsAfterUpdating() throws {
        let defaults = try #require(UserDefaults(suiteName: "AutoAddRuleTests-\(UUID().uuidString)"))

        #expect(AutoAddRule.load(from: defaults).mode == .all)
    }
}
