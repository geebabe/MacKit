// Tests/WindowFeatureTests/WindowRestoreStoreTests.swift
// Tests for saving, retrieving, and popping previous window frames.

import Testing
import CoreGraphics
@testable import WindowFeature

@Suite("WindowRestoreStore")
@MainActor
struct WindowRestoreStoreTests {

    let store = WindowRestoreStore()

    @Test("Saved frame can be retrieved")
    func saveAndGet() {
        let identity = WindowIdentity(processIdentifier: 1234, windowTitle: "Terminal")
        let frame = CGRect(x: 100, y: 150, width: 800, height: 600)

        store.saveFrame(frame, for: identity)
        let retrieved = store.getFrame(for: identity)

        #expect(retrieved == frame)
    }

    @Test("Popping a frame returns it and removes it from the store")
    func popFrame() {
        let identity = WindowIdentity(processIdentifier: 5678, windowTitle: "Safari")
        let frame = CGRect(x: 50, y: 50, width: 1000, height: 700)

        store.saveFrame(frame, for: identity)

        let popped = store.popFrame(for: identity)
        #expect(popped == frame)

        let subsequent = store.getFrame(for: identity)
        #expect(subsequent == nil)
    }

    @Test("Different windows maintain independent restore frames")
    func independentWindows() {
        let id1 = WindowIdentity(processIdentifier: 100, windowTitle: "Editor")
        let id2 = WindowIdentity(processIdentifier: 100, windowTitle: "Terminal")
        let id3 = WindowIdentity(processIdentifier: 200, windowTitle: "Editor")

        let frame1 = CGRect(x: 0, y: 0, width: 400, height: 400)
        let frame2 = CGRect(x: 50, y: 50, width: 500, height: 500)
        let frame3 = CGRect(x: 100, y: 100, width: 600, height: 600)

        store.saveFrame(frame1, for: id1)
        store.saveFrame(frame2, for: id2)
        store.saveFrame(frame3, for: id3)

        #expect(store.getFrame(for: id1) == frame1)
        #expect(store.getFrame(for: id2) == frame2)
        #expect(store.getFrame(for: id3) == frame3)
    }

    @Test("Clear removes all stored frames")
    func clearAll() {
        let id = WindowIdentity(processIdentifier: 999, windowTitle: "Notes")
        store.saveFrame(CGRect(x: 0, y: 0, width: 300, height: 300), for: id)

        store.clearAll()
        #expect(store.getFrame(for: id) == nil)
    }
}

