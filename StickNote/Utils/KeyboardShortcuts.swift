import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcut {
    init?(_ shortcut: KeyboardShortcuts.Shortcut) {
        if let keyEquivalent = shortcut.keyEquivalent {
            self.init(keyEquivalent, modifiers: shortcut.eventModifiers)
        } else {
            return nil
        }
    }
}

extension KeyboardShortcuts.Shortcut {
    func toKeyboardShortcut() -> KeyboardShortcut? {
        return KeyboardShortcut(self)
    }

    var keyEquivalent: KeyEquivalent? {
        switch self.carbonKeyCode {
        // Letters
        case 0x00: return .init("a")
        case 0x01: return .init("s")
        case 0x02: return .init("d")
        case 0x03: return .init("f")
        case 0x04: return .init("h")
        case 0x05: return .init("g")
        case 0x06: return .init("z")
        case 0x07: return .init("x")
        case 0x08: return .init("c")
        case 0x09: return .init("v")
        case 0x0A: return .init("v")
        case 0x0B: return .init("b")
        case 0x0C: return .init("q")
        case 0x0D: return .init("w")
        case 0x0E: return .init("e")
        case 0x0F: return .init("r")
        case 0x10: return .init("y")
        case 0x11: return .init("t")
        case 0x12: return .init("1")
        case 0x13: return .init("2")
        case 0x14: return .init("3")
        case 0x15: return .init("4")
        case 0x16: return .init("6")
        case 0x17: return .init("5")
        case 0x18: return .init("=")
        case 0x19: return .init("9")
        case 0x1A: return .init("7")
        case 0x1B: return .init("-")
        case 0x1C: return .init("8")
        case 0x1D: return .init("0")
        case 0x1E: return .init("]")
        case 0x1F: return .init("o")
        case 0x20: return .init("u")
        case 0x21: return .init("[")
        case 0x22: return .init("i")
        case 0x23: return .init("p")
        case 0x24: return .return
        case 0x25: return .init("l")
        case 0x26: return .init("j")
        case 0x27: return .init("'")
        case 0x28: return .init("k")
        case 0x29: return .init(";")
        case 0x2A: return .init("\\")
        case 0x2B: return .init(",")
        case 0x2C: return .init("/")
        case 0x2D: return .init("n")
        case 0x2E: return .init("m")
        case 0x2F: return .init(".")
        case 0x30: return .tab
        case 0x31: return .space
        case 0x32: return .init("`")  // Backtick/Grave Accent
        case 0x33: return .delete
        case 0x34: return .init("/")  // Numpad /
        case 0x35: return .escape

        // Special keys
        case 0x7B: return .leftArrow
        case 0x7C: return .rightArrow
        case 0x7D: return .downArrow
        case 0x7E: return .upArrow

        // Default: unsupported
        default: return nil
        }
    }

    var eventModifiers: EventModifiers {
        var result: EventModifiers = []
        if self.modifiers.contains(.command) { result.insert(.command) }
        if self.modifiers.contains(.shift) { result.insert(.shift) }
        if self.modifiers.contains(.option) { result.insert(.option) }
        if self.modifiers.contains(.control) { result.insert(.control) }
        return result
    }
}
