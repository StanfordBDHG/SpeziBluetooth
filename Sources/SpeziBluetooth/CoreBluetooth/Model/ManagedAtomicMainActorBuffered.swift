//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Atomics
import Foundation


final class ManagedAtomicMainActorBuffered<Value: AtomicValue & Sendable>: Sendable where Value.AtomicRepresentation.Value == Value {
    private let managedValue: ManagedAtomic<Value>
    @MainActor private var mainActorValue: Value?

    init(_ value: Value) {
        self.managedValue = ManagedAtomic(value)
        self.mainActorValue = value
    }

    @_semantics("atomics.requires_constant_orderings")
    @inlinable
    func load(ordering: AtomicLoadOrdering = .relaxed) -> Value {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                mainActorValue
            } ?? managedValue.load(ordering: ordering)
        } else {
            managedValue.load(ordering: ordering)
        }
    }

    @_semantics("atomics.requires_constant_orderings")
    private func mutateMainActorBuffer(
        _ newValue: Value,
        mutation: sending @MainActor @escaping (@MainActor () -> Void) -> Void
    ) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                let valueMutation = { @MainActor in
                    self.mainActorValue = newValue
                }
                mutation(valueMutation)
            }
        } else {
            Task { @MainActor in
                let valueMutation = { @MainActor in
                    self.mainActorValue = newValue
                }

                mutation(valueMutation)
            }
        }
    }

    @_semantics("atomics.requires_constant_orderings")
    @inlinable
    func store(
        _ newValue: Value,
        ordering: AtomicStoreOrdering = .relaxed,
        mutation: sending @MainActor @escaping (@MainActor () -> Void) -> Void
    ) {
        managedValue.store(newValue, ordering: ordering)
        mutateMainActorBuffer(newValue, mutation: mutation)
    }
}


extension ManagedAtomicMainActorBuffered where Value: Equatable {
    @_semantics("atomics.requires_constant_orderings")
    @inlinable
    func storeAndCompare(
        _ newValue: Value,
        ordering: AtomicUpdateOrdering = .relaxed,
        mutation: sending @MainActor @escaping (@MainActor () -> Void) -> Void
    ) -> Bool {
        let previousValue = managedValue.exchange(newValue, ordering: ordering)
        mutateMainActorBuffer(newValue, mutation: mutation)

        return previousValue != newValue
    }
}
