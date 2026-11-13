import Domain
import Foundation
import Presentation
import SwiftUI

public struct WallpaperScreen: View {
    private let model: WallpaperModel
    @Environment(\.undoManager) private var undoManager
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
                ToolbarItem {
                    Button(action: model.askToPlaceByTimeAgain) {
                        Text(verbatim: WallpaperText.placeByTimeAgain.inTheAppLanguage)
                    }
                    .disabled(!model.canPlaceByTimeAgain)
                }
            }
            .confirmationDialog(
                Text(verbatim: WallpaperText.placeByTimeAgainQuestion.inTheAppLanguage),
                isPresented: isAskingToPlaceByTimeAgain,
                titleVisibility: .visible,
            ) {
                Button {
                    send { await model.confirmPlacingByTimeAgain() }
                } label: {
                    Text(verbatim: WallpaperText.confirmPlaceByTimeAgain.inTheAppLanguage)
                }
                Button(role: .cancel) {
                    model.declinePlacingByTimeAgain()
                } label: {
                    Text(verbatim: WallpaperText.cancel.inTheAppLanguage)
                }
            } message: {
                Text(verbatim: WallpaperText.placeByTimeAgainConsequence.inTheAppLanguage)
            }
            .alert(
                Text(verbatim: WallpaperText.couldNotSaveTitle.inTheAppLanguage),
                isPresented: isShowingArrangingFailure,
            ) {
                Button(role: .cancel) {
                    model.dismissArrangingFailure()
                } label: {
                    Text(verbatim: WallpaperText.ok.inTheAppLanguage)
                }
            } message: {
                Text(verbatim: WallpaperText.unavailableMessage.inTheAppLanguage)
            }
            .onChange(of: model.lastStep) { _, newStep in
                announce(newStep)
            }
            .onChange(of: model.newStepCount) { oldCount, newCount in
                ArrangingUndo(model: model).stepCountChanged(from: oldCount, to: newCount, in: undoManager)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: model.name)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityAddTraits(.isHeader)
                if model.needsMorePictures {
                    Text(verbatim: WallpaperText.needsMorePictures.inTheAppLanguage)
                        .foregroundStyle(.secondary)
                }
            }
            .padding([.horizontal, .top])
            List(model.slots, selection: selectedSlot) { state in
                row(of: state)
            }
            .focusedValue(\.slotListIsFocused, true)
        }
    }

    private func row(of state: WallpaperModel.SlotState) -> some View {
        let slotName = WallpaperText.name(of: state.slot).inTheAppLanguage
        let caption = caption(of: state)
        let add = addAction(for: state)
        let destinations = destinations(forThePictureIn: state)
        let remove = removeAction(for: state)
        return SlotRow(
            slotName: slotName,
            thumbnail: thumbnail(of: state),
            caption: caption,
            addTitle: WallpaperText.addPicture.inTheAppLanguage,
            add: add,
            pictureActions: remove.map { remove in
                pictureActions(movingFrom: state.slot, to: destinations, remove: remove)
            },
        )
        .accessibilityRepresentation {
            HStack {
                Text(verbatim: slotName)
                    .accessibilityValue(Text(verbatim: caption))
                    .accessibilityActions {
                        ForEach(destinations, id: \.self) { destination in
                            Button {
                                movePicture(from: state.slot, to: destination)
                            } label: {
                                Text(verbatim: WallpaperText.moveTo.inTheAppLanguage(filledWith: name(of: destination)))
                            }
                        }
                        if let remove {
                            Button(action: remove) {
                                Text(verbatim: WallpaperText.removePicture.inTheAppLanguage)
                            }
                        }
                    }
                if let add {
                    Button(action: add) {
                        Text(verbatim: WallpaperText.addPictureToSlot.inTheAppLanguage(filledWith: slotName))
                    }
                }
            }
        }
        .modifier(DraggingThePicture(picture: draggedPicture(in: state), preview: state.preview))
        .dropDestination(for: SlotRowDrop.self, isEnabled: openWallpaperID != nil) { drops, _ in
            take(drops, onto: state)
        }
    }

    private func thumbnail(of state: WallpaperModel.SlotState) -> SlotRow.Thumbnail {
        if let preview = state.preview {
            .picture(preview)
        } else if !state.isFilled, let borrowedPreview = state.standIn?.preview {
            .borrowedPicture(borrowedPreview)
        } else {
            .empty
        }
    }

    private func caption(of state: WallpaperModel.SlotState) -> String {
        if !state.isFilled, let standIn = state.standIn {
            WallpaperText.emptySlotBorrowing.inTheAppLanguage(
                filledWith: WallpaperText.name(of: standIn.slot).inTheAppLanguage,
            )
        } else if !state.isFilled {
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

private extension WallpaperScreen {
    func pictureActions(
        movingFrom source: Slot,
        to destinations: [Slot],
        remove: @escaping () -> Void,
    ) -> SlotRow.PictureActions {
        SlotRow.PictureActions(
            menuTitle: WallpaperText.pictureActions.inTheAppLanguage,
            moveTitle: WallpaperText.moveToMenu.inTheAppLanguage,
            destinations: destinations.map { destination in
                SlotRow.PictureActions.Destination(title: name(of: destination)) {
                    movePicture(from: source, to: destination)
                }
            },
            removeTitle: WallpaperText.removePicture.inTheAppLanguage,
            remove: remove,
        )
    }

    func destinations(forThePictureIn state: WallpaperModel.SlotState) -> [Slot] {
        guard state.isFilled, state.canBeMoved else { return [] }

        return Slot.allCases.filter { $0 != state.slot }
    }

    func removeAction(for state: WallpaperModel.SlotState) -> (() -> Void)? {
        guard state.isFilled else { return nil }

        return { send { await model.removePicture(from: state.slot) } }
    }

    func movePicture(from source: Slot, to destination: Slot) {
        send { await model.movePicture(from: source, to: destination) }
    }

    func draggedPicture(in state: WallpaperModel.SlotState) -> DraggedPicture? {
        guard state.canBeMoved, let wallpaper = openWallpaperID else { return nil }

        return DraggedPicture(slot: state.slot, wallpaper: wallpaper)
    }

    func take(_ drops: [SlotRowDrop], onto state: WallpaperModel.SlotState) {
        let files = drops.compactMap(\.file)
        if !files.isEmpty {
            reportDroppedFilesOnARow(files, onto: state)
        } else if let picture = drops.lazy.compactMap(\.picture).first {
            move(picture, onto: state.slot)
        }
    }

    func reportDroppedFilesOnARow(_ files: [URL], onto state: WallpaperModel.SlotState) {
        if canTakeADroppedFile(into: state) {
            reportDroppedFiles(files, onto: state)
        } else {
            reportDroppedFiles(files)
        }
    }

    func move(_ picture: DraggedPicture, onto destination: Slot) {
        guard picture.wallpaper == openWallpaperID, picture.slot != destination else { return }

        movePicture(from: picture.slot, to: destination)
    }

    func name(of slot: Slot) -> String {
        WallpaperText.name(of: slot).inTheAppLanguage
    }

    var selectedSlot: Binding<Slot?> {
        Binding(
            get: { model.selectedSlot },
            set: { slot in model.select(slot) },
        )
    }

    var isAskingToPlaceByTimeAgain: Binding<Bool> {
        Binding(
            get: { model.isAskingToPlaceByTimeAgain },
            set: { _ in },
        )
    }

    var isShowingArrangingFailure: Binding<Bool> {
        Binding(
            get: { model.arrangingFailure != nil },
            set: { stillShowing in
                if !stillShowing {
                    model.dismissArrangingFailure()
                }
            },
        )
    }

    func announce(_ step: WallpaperModel.Step?) {
        guard let step, let announcement = ArrangingWording.announcement(of: step, from: .module) else { return }

        AccessibilityNotification.Announcement(announcement).post()
    }
}

private extension WallpaperModel.SlotState {
    var holdsAPictureThatCanBeReplaced: Bool {
        isFilled && canTakeAFile
    }
}
