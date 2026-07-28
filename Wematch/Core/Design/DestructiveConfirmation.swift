import SwiftUI

extension View {
    /// Puts a confirmation between the user and an irreversible action.
    ///
    /// Closes audit finding G4: leaving a group, deleting one, removing a member and
    /// leaving a room all used to fire on the first tap, several of them from a swipe
    /// where a mis-swipe is easy. Only two of the destructive paths asked first.
    ///
    /// Uses the native dialog rather than a bespoke glass card, which is what the design
    /// system prescribes — the platform already gets the destructive role, the sheet
    /// placement and the VoiceOver announcement right. This wrapper exists so the pattern
    /// is stated once: title always visible, confirm always `.destructive`, cancel always
    /// present.
    func destructiveConfirmation(
        _ title: String,
        message: String,
        confirmLabel: String,
        isPresented: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button(confirmLabel, role: .destructive, action: action)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    /// Same contract, driven by the item the action would destroy.
    ///
    /// Swipe actions live inside a `ForEach`, so a single boolean cannot say *which* row
    /// was swiped. Binding an optional item keeps the confirmation attached to the list
    /// while still naming its target in the copy.
    func destructiveConfirmation<Item: Identifiable>(
        item: Binding<Item?>,
        title: (Item) -> String,
        message: (Item) -> String,
        confirmLabel: (Item) -> String,
        action: @escaping (Item) -> Void
    ) -> some View {
        confirmationDialog(
            item.wrappedValue.map(title) ?? "",
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: item.wrappedValue
        ) { presented in
            Button(confirmLabel(presented), role: .destructive) { action(presented) }
            Button("Cancel", role: .cancel) {}
        } message: { presented in
            Text(message(presented))
        }
    }
}
