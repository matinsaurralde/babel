import XCTest
@testable import Babel

final class HotkeyBindingTests: XCTestCase {

    private let key = HotkeyBinding.userDefaultsKey

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testDefaultIsRightOption() {
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(HotkeyBinding.current, .rightOption)
    }

    func testReadsUserPreference() {
        UserDefaults.standard.set(HotkeyBinding.f13.rawValue, forKey: key)
        XCTAssertEqual(HotkeyBinding.current, .f13)
    }

    func testUnknownRawValueFallsBackToDefault() {
        UserDefaults.standard.set("not-a-binding", forKey: key)
        XCTAssertEqual(HotkeyBinding.current, .default)
    }

    func testModifierBindingsHaveDeviceMasks() {
        for binding in HotkeyBinding.modifierBindings {
            XCTAssertNotNil(binding.deviceMask, "\(binding) is in modifierBindings but has no deviceMask")
            XCTAssertTrue(binding.isModifier, "\(binding) should be flagged isModifier")
        }
    }

    func testFunctionKeysAreNotModifiers() {
        for binding in HotkeyBinding.functionKeyBindings {
            XCTAssertNil(binding.deviceMask)
            XCTAssertFalse(binding.isModifier)
        }
    }

    func testKeycodesAreUnique() {
        let keycodes = HotkeyBinding.allCases.map(\.keycode)
        XCTAssertEqual(Set(keycodes).count, keycodes.count, "Keycodes should be unique across bindings")
    }

    func testRawValueRoundTrip() {
        for binding in HotkeyBinding.allCases {
            XCTAssertEqual(HotkeyBinding(rawValue: binding.rawValue), binding)
        }
    }
}
