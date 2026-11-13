import Domain
import SwiftUI

public struct WallpaperCommands: Commands {
    private let model: WallpaperModel
    private let addPicture: (Slot, WallpaperID) -> Void
    @FocusedValue(\.slotListIsFocused) private var slotListIsFocused

    public init(model: WallpaperModel, addPicture: @escaping (Slot, WallpaperID) -> Void) {
        self.model = model
        self.addPicture = addPicture
    }

    public var body: some Commands {
        CommandMenu(Text(verbatim: WallpaperText.pictureMenu.inTheAppLanguage)) {
            Button {
                movePicture(to: model.slotEarlierThanSelected)
            } label: {
                Text(verbatim: WallpaperText.moveEarlier.inTheAppLanguage)
            }
            .keyboardShortcut(.upArrow, modifiers: [.option, .command])
            .disabled(!canMovePicture || model.slotEarlierThanSelected == nil)
            Button {
                movePicture(to: model.slotLaterThanSelected)
            } label: {
                Text(verbatim: WallpaperText.moveLater.inTheAppLanguage)
            }
            .keyboardShortcut(.downArrow, modifiers: [.option, .command])
            .disabled(!canMovePicture || model.slotLaterThanSelected == nil)
            Menu {
                ForEach(slotsOtherThanSelected, id: \.self) { destination in
                    Button {
                        movePicture(to: destination)
                    } label: {
                        Text(verbatim: WallpaperText.name(of: destination).inTheAppLanguage)
                    }
                }
            } label: {
                Text(verbatim: WallpaperText.moveToMenu.inTheAppLanguage)
            }
            .disabled(!canMovePicture)
            Divider()
            Button(action: addPictureToSelectedSlot) {
                Text(verbatim: WallpaperText.addPicture.inTheAppLanguage)
            }
            .disabled(wallpaperOpenForAPictureInSelectedSlot == nil)
            Button(action: removeSelectedPicture) {
                Text(verbatim: WallpaperText.removePicture.inTheAppLanguage)
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(selectedSlotState?.isFilled != true)
            Divider()
            Button(action: model.askToPlaceByTimeAgain) {
                Text(verbatim: WallpaperText.placeByTimeAgain.inTheAppLanguage)
            }
            .disabled(!model.canPlaceByTimeAgain)
        }
    }

    private var selectedSlotState: WallpaperModel.SlotState? {
        guard slotListIsFocused == true, let selected = model.selectedSlot else { return nil }

        return model.slots.first { $0.slot == selected }
    }

    private var canMovePicture: Bool {
        selectedSlotState?.canBeMoved == true
    }

    private var slotsOtherThanSelected: [Slot] {
        Slot.allCases.filter { $0 != model.selectedSlot }
    }

    private var wallpaperOpenForAPictureInSelectedSlot: WallpaperID? {
        guard selectedSlotState?.canTakeAFile == true, model.phase == .open else { return nil }

        return model.wallpaperID
    }

    private func movePicture(to destination: Slot?) {
        guard canMovePicture, let source = selectedSlotState?.slot, let destination else { return }

        Task.immediate { await model.movePicture(from: source, to: destination) }
    }

    private func addPictureToSelectedSlot() {
        guard let slot = selectedSlotState?.slot, let wallpaper = wallpaperOpenForAPictureInSelectedSlot else { return }

        addPicture(slot, wallpaper)
    }

    private func removeSelectedPicture() {
        guard let slot = selectedSlotState?.slot, selectedSlotState?.isFilled == true else { return }

        Task.immediate { await model.removePicture(from: slot) }
    }
}

extension FocusedValues {
    @Entry var slotListIsFocused: Bool?
}
