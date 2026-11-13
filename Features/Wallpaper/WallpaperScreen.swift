import Domain
import Foundation
import Presentation
import SwiftUI

public struct WallpaperScreen: View {
    private let model: WallpaperModel
    private let addPictures: ((WallpaperID) -> Void)?
    private let addPicture: ((Slot, WallpaperID) -> Void)?
    private let addDroppedFiles: (([URL], WallpaperID) -> Void)?
    private let addDroppedFile: ((URL, Slot, WallpaperID) -> Void)?

    public init(
        model: WallpaperModel,
        addPictures: ((WallpaperID) -> Void)? = nil,
        addPicture: ((Slot, WallpaperID) -> Void)? = nil,
        addDroppedFiles: (([URL], WallpaperID) -> Void)? = nil,
        addDroppedFile: ((URL, Slot, WallpaperID) -> Void)? = nil,
    ) {
        self.model = model
        self.addPictures = addPictures
        self.addPicture = addPicture
        self.addDroppedFiles = addDroppedFiles
        self.addDroppedFile = addDroppedFile
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dropDestination(for: URL.self, isEnabled: canTakeDroppedFiles) { files, _ in
                reportDroppedFiles(files)
            }
            .toolbar {
                ToolbarItem {
                    Button(action: askToAddPictures) {
                        Text(verbatim: WallpaperText.addPictures.inTheAppLanguage)
                    }
                    .disabled(!canAddPictures)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .nothingOpen:
            message(title: .nothingOpenTitle, message: .nothingOpenMessage)
        case .opening:
            ProgressView {
                Text(verbatim: WallpaperText.opening.inTheAppLanguage)
            }
            .padding()
        case .gone:
            message(title: .goneTitle, message: .nothingOpenMessage)
        case .unavailable:
            VStack(spacing: 16) {
                TitledMessage(
                    title: WallpaperText.unavailableTitle.inTheAppLanguage,
                    message: WallpaperText.unavailableMessage.inTheAppLanguage,
                )
                Button {
                    send { await model.reload() }
                } label: {
                    Text(verbatim: WallpaperText.tryAgain.inTheAppLanguage)
                }
            }
            .padding()
        case .open:
            openWallpaper
        }
    }

    private func message(title: WallpaperText, message: WallpaperText) -> some View {
        TitledMessage(title: title.inTheAppLanguage, message: message.inTheAppLanguage)
            .padding()
    }

    private var openWallpaper: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: model.name)
                .font(.title2.bold())
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
                .padding([.horizontal, .top])
            List(model.slots) { state in
                row(of: state)
            }
        }
    }

    private func row(of state: WallpaperModel.SlotState) -> some View {
        let slotName = WallpaperText.name(of: state.slot).inTheAppLanguage
        let caption = caption(of: state)
        let add = addAction(for: state)
        return SlotRow(
            slotName: slotName,
            thumbnail: state.preview.map { SlotRow.Thumbnail.picture($0) } ?? .empty,
            caption: caption,
            addTitle: WallpaperText.addPicture.inTheAppLanguage,
            add: add,
        )
        .accessibilityRepresentation {
            HStack {
                Text(verbatim: slotName)
                    .accessibilityValue(Text(verbatim: caption))
                if let add {
                    Button(action: add) {
                        Text(verbatim: WallpaperText.addPictureToSlot.inTheAppLanguage(filledWith: slotName))
                    }
                }
            }
        }
        .dropDestination(for: URL.self, isEnabled: canTakeADroppedFile(into: state)) { files, _ in
            reportDroppedFiles(files, onto: state)
        }
    }

    private func caption(of state: WallpaperModel.SlotState) -> String {
        if !state.isFilled {
            WallpaperText.emptySlot.inTheAppLanguage
        } else if state.holdsAPictureThatCanBeReplaced {
            WallpaperText.madeWithAI.inTheAppLanguage
        } else {
            WallpaperText.yourPicture.inTheAppLanguage
        }
    }

    private func addAction(for state: WallpaperModel.SlotState) -> (() -> Void)? {
        guard state.canTakeAFile, let addPicture, let wallpaper = openWallpaperID else { return nil }

        return { addPicture(state.slot, wallpaper) }
    }

    private var openWallpaperID: WallpaperID? {
        model.phase == .open ? model.wallpaperID : nil
    }

    private var canAddPictures: Bool {
        addPictures != nil && openWallpaperID != nil && model.hasEmptySlot
    }

    private func askToAddPictures() {
        guard let addPictures, let wallpaper = openWallpaperID else { return }

        addPictures(wallpaper)
    }

    private var canTakeDroppedFiles: Bool {
        addDroppedFiles != nil && openWallpaperID != nil
    }

    private func canTakeADroppedFile(into state: WallpaperModel.SlotState) -> Bool {
        state.canTakeAFile && addDroppedFile != nil && openWallpaperID != nil
    }

    private func reportDroppedFiles(_ files: [URL]) {
        guard let addDroppedFiles, let wallpaper = openWallpaperID, !files.isEmpty else { return }

        addDroppedFiles(files, wallpaper)
    }

    private func reportDroppedFiles(_ files: [URL], onto state: WallpaperModel.SlotState) {
        guard let addDroppedFile, let wallpaper = openWallpaperID else { return }
        guard files.count == 1, let file = files.first else {
            reportDroppedFiles(files)
            return
        }

        addDroppedFile(file, state.slot, wallpaper)
    }

    private func send(_ action: @escaping @MainActor () async -> Void) {
        Task.immediate { await action() }
    }
}

private extension WallpaperModel.SlotState {
    var holdsAPictureThatCanBeReplaced: Bool {
        isFilled && canTakeAFile
    }
}
