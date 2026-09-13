import SwiftUI
import AppKit

/// Modal sheet for manually submitting scrobbles to Last.fm.
/// Supports backdated timestamps, custom album tags, and instant validation.
struct ManualScrobbleSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var trackTitle: String
    @State private var artistName: String
    @State private var albumName: String
    @State private var timestamp: Date = Date()
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var success = false

    init(track: String = "", artist: String = "", album: String = "") {
        _trackTitle = State(initialValue: track)
        _artistName = State(initialValue: artist)
        _albumName = State(initialValue: album)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(appState.accentColor)
                    Text("Manual Scrobble")
                        .font(DS.Fonts.heading(16))
                        .foregroundStyle(DS.Colors.textPrimary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }

            Text("Add an un-tracked play or vinyl/offline listening session directly to your Last.fm profile.")
                .font(DS.Fonts.caption(12))
                .foregroundStyle(DS.Colors.textSecondary)

            // Form Fields
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Track
                VStack(alignment: .leading, spacing: 4) {
                    Text("Track Title *")
                        .font(DS.Fonts.caption(11).weight(.semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                    TextField("e.g. Paranoid Android", text: $trackTitle)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }

                // Artist
                VStack(alignment: .leading, spacing: 4) {
                    Text("Artist Name *")
                        .font(DS.Fonts.caption(11).weight(.semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                    TextField("e.g. Radiohead", text: $artistName)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }

                // Album
                VStack(alignment: .leading, spacing: 4) {
                    Text("Album (Optional)")
                        .font(DS.Fonts.caption(11).weight(.semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                    TextField("e.g. OK Computer", text: $albumName)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }

                // Date / Timestamp
                VStack(alignment: .leading, spacing: 4) {
                    Text("Played At")
                        .font(DS.Fonts.caption(11).weight(.semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                    DatePicker("", selection: $timestamp, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            }

            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.error)
                    Text(error)
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.error)
                }
            }

            if success {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.success)
                    Text("Scrobble submitted successfully!")
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.success)
                }
            }

            Spacer(minLength: 0)

            // Bottom Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.textSecondary)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    submitScrobble()
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isSubmitting ? "Submitting…" : "Scrobble Track")
                            .font(DS.Fonts.bodyMedium(13))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        canSubmit ? appState.accentColor : Color.gray.opacity(0.3),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || isSubmitting)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440, height: 450)
        .background(DS.Colors.cardBackground)
    }

    private var canSubmit: Bool {
        !trackTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !artistName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitScrobble() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await appState.scrobbleMonitor.manualScrobble(
                    track: trackTitle.trimmingCharacters(in: .whitespaces),
                    artist: artistName.trimmingCharacters(in: .whitespaces),
                    album: albumName.trimmingCharacters(in: .whitespaces),
                    timestamp: timestamp
                )
                await MainActor.run {
                    self.isSubmitting = false
                    self.success = true
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
