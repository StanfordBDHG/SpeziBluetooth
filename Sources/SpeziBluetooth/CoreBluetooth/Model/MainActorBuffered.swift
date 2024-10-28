//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


final class MainActorBuffered<Value: Sendable>: Sendable {
    private nonisolated(unsafe) var unsafeValue: Value
    @MainActor private(set) var mainActorValue: Value?

    init(_ value: Value) {
        self.unsafeValue = value
        self.mainActorValue = value
    }

    func loadUnsafe() -> Value {
        loadIfMainActor() ?? unsafeValue
    }

    func load(using lock: NSLock) -> Value {
        loadIfMainActor() ?? lock.withLock {
            unsafeValue
        }
    }

    func load(using lock: RWLock) -> Value {
        loadIfMainActor() ?? lock.withReadLock {
            unsafeValue
        }
    }

    private func loadIfMainActor() -> Value? {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                mainActorValue
            }
        } else {
            nil
        }
    }

    private func _store(_ newValue: Value, mutation: sending @MainActor @escaping (@MainActor () -> Void) -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                let valueMutation = { @MainActor in
                    self.mainActorValue = newValue
                }
                mutation(valueMutation)
            }
        } else {
            let valueMutation = { @MainActor in
                self.mainActorValue = newValue
            }
            Task { @MainActor in
                mutation(valueMutation)
            }
        }
    }

    func store(_ newValue: Value, using lock: NSLock, mutation: sending @MainActor @escaping (@MainActor () -> Void) -> Void) {
        lock.withLock {
            unsafeValue = newValue
        }
        _store(newValue, mutation: mutation)
    }

    func store(_ newValue: Value, using lock: RWLock, mutation: sending @MainActor @escaping (@MainActor () -> Void) -> Void) {
        lock.withWriteLock {
            unsafeValue = newValue
        }
        _store(newValue, mutation: mutation)
    }
}


extension MainActorBuffered where Value: Equatable {
    func storeAndCompare(_ newValue: Value, using lock: RWLock, mutation: sending @MainActor @escaping (@MainActor () -> Void) -> Void) -> Bool {
        let didChange = lock.withWriteLock {
            let didChange = unsafeValue != newValue
            unsafeValue = newValue
            return didChange
        }
        _store(newValue, mutation: mutation)

        return didChange
    }
}
