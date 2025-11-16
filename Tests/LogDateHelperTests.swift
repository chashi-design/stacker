import Foundation

struct TestCase {
    let name: String
    let run: () throws -> Void
}

enum TestError: Error {
    case assertionFailed(String)
}

@discardableResult
func assertEqualDates(_ lhs: Date, _ rhs: Date, accuracy: TimeInterval = 0.001, message: String) throws -> Bool {
    let delta = abs(lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate)
    if delta > accuracy {
        throw TestError.assertionFailed(message + " (delta: \(delta))")
    }
    return true
}

@discardableResult
func assertEqual(_ lhs: String, _ rhs: String, message: String) throws -> Bool {
    if lhs != rhs {
        throw TestError.assertionFailed(message + " (lhs: \(lhs), rhs: \(rhs))")
    }
    return true
}

@main
struct TestRunner {
    static func main() {
        let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo")!
        NSTimeZone.default = tokyoTimeZone
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = tokyoTimeZone

        let tests: [TestCase] = [
            TestCase(name: "normalize removes time components") {
                var components = DateComponents()
                components.year = 2024
                components.month = 5
                components.day = 1
                components.hour = 13
                components.minute = 45
                components.timeZone = tokyoTimeZone
                let date = gregorian.date(from: components)!
                let normalized = LogDateHelper.normalized(date, calendar: gregorian)
                let expected = gregorian.startOfDay(for: date)
                try assertEqualDates(normalized, expected, message: "Expected normalization to return start of day")
            },
            TestCase(name: "normalize respects provided calendar") {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: -5 * 3600)!
                var components = DateComponents()
                components.year = 2024
                components.month = 1
                components.day = 10
                components.hour = 1
                components.minute = 15
                components.timeZone = calendar.timeZone
                let date = calendar.date(from: components)!
                let normalized = LogDateHelper.normalized(date, calendar: calendar)
                let expected = calendar.startOfDay(for: date)
                try assertEqualDates(normalized, expected, message: "Normalization should honor injected calendar time zone")
            },
            TestCase(name: "label outputs japanese date string") {
                var components = DateComponents()
                components.year = 2024
                components.month = 5
                components.day = 1
                components.timeZone = tokyoTimeZone
                let date = gregorian.date(from: components)!
                let label = LogDateHelper.label(for: date)
                try assertEqual(label, "2024年5月1日(水)", message: "Japanese label should match expected format")
            }
        ]

        var failures = 0

        for test in tests {
            do {
                try test.run()
                print("✅ \(test.name)")
            } catch {
                failures += 1
                print("❌ \(test.name): \(error)")
            }
        }

        if failures > 0 {
            exit(1)
        } else {
            print("All LogDateHelper tests passed (\(tests.count))")
        }
    }
}
