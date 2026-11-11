import Domain
import Presentation
import SwiftUI

public struct LibraryScreen: View {
    private let model: LibraryModel
    private let createWallpaper: (() -> Void)?
    @State private var hasAskedToOpen = false

    public init(model: LibraryModel, createWallpaper: (() -> Void)? = nil) {
        self.model = model
        self.createWallpaper = createWallpaper
    }

    public var body: some View {
        content
            .onAppear(perform: openOnFirstAppearance)
            .confirmationDialog(
                Text(verbatim: deleteQuestion),
                isPresented: isAskingToDelete,
                titleVisibility: .visible,
            ) {
                Button(role: .destructive) {
                    send { await model.confirmDeletion() }
                } label: {
                    Text(verbatim: LibraryText.confirmDelete.inTheAppLanguage)
                }
                Button(role: .cancel) {
                    model.declineDeletion()
                } label: {
                    Text(verbatim: LibraryText.cancel.inTheAppLanguage)
                }
            } message: {
                Text(verbatim: LibraryText.deleteConsequence.inTheAppLanguage)
            }
            .alert(Text(verbatim: problemText), isPresented: isShowingProblem) {
                Button(role: .cancel) {
                    model.dismissProblem()
                } label: {
                    Text(verbatim: LibraryText.ok.inTheAppLanguage)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .opening:
            ProgressView {
                Text(verbatim: LibraryText.opening.inTheAppLanguage)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        case .unreadable:
            failure(title: .unreadableTitle, message: .unreadableMessage)
        case .unavailable:
            failure(title: .unavailableTitle, message: .unavailableMessage)
        case .open where model.isEmpty:
            emptyLibrary
        case .open:
            wallpaperList
        }
    }

    private func failure(title: LibraryText, message: LibraryText) -> some View {
        VStack(spacing: 16) {
            TitledMessage(title: title.inTheAppLanguage, message: message.inTheAppLanguage)
            Button {
                send { await model.open() }
            } label: {
                Text(verbatim: LibraryText.tryAgain.inTheAppLanguage)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 16) {
            TitledMessage(
                title: LibraryText.emptyTitle.inTheAppLanguage,
                message: LibraryText.emptyExplanation.inTheAppLanguage,
            )
            if let createWallpaper {
                Button(action: createWallpaper) {
                    Text(verbatim: LibraryText.createWallpaper.inTheAppLanguage)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wallpaperList: some View {
        ScrollViewReader { scroller in
            List(selection: selection) {
                ForEach(model.wallpapers) { wallpaper in
                    row(of: wallpaper)
                        .tag(wallpaper.id)
                        .id(wallpaper.id)
                        .contextMenu {
                            Button {
                                model.startRenaming(wallpaper.id)
                            } label: {
                                Text(verbatim: LibraryText.rename.inTheAppLanguage)
                            }
                            Button(role: .destructive) {
                                model.askToDelete(wallpaper.id)
                            } label: {
                                Text(verbatim: LibraryText.delete.inTheAppLanguage)
                            }
                        }
                }
            }
            .onAppear {
                if let openWallpaper = listedOpenWallpaper {
                    scroller.scrollTo(openWallpaper, anchor: .center)
                }
            }
            .onKeyPress(.return) {
                guard model.wallpaperBeingRenamed == nil, let openWallpaper = listedOpenWallpaper else {
                    return .ignored
                }

                model.startRenaming(openWallpaper)
                return .handled
            }
            .onDeleteCommand {
                if let openWallpaper = listedOpenWallpaper {
                    model.askToDelete(openWallpaper)
                }
            }
        }
    }

    @ViewBuilder
    private func row(of wallpaper: LibraryWallpaper) -> some View {
        let caption = LibraryText.picturesOfEight.inTheAppLanguage(filledWith: wallpaper.pictureCount)
        if model.wallpaperBeingRenamed == wallpaper.id {
            WallpaperNameField(
                currentName: wallpaper.name,
                caption: caption,
                problem: nameProblemText,
                keep: { proposedName in send { await model.rename(to: proposedName) } },
                leave: { model.cancelRenaming() },
            )
        } else {
            WallpaperRow(name: wallpaper.name, pictures: wallpaper.previews, caption: caption)
        }
    }

    private var selection: Binding<WallpaperID?> {
        Binding(
            get: { model.openWallpaperID },
            set: { chosenWallpaper in
                if let chosenWallpaper, chosenWallpaper != model.openWallpaperID {
                    send { await model.select(chosenWallpaper) }
                }
            },
        )
    }

    private var listedOpenWallpaper: WallpaperID? {
        model.wallpapers.first { $0.id == model.openWallpaperID }?.id
    }

    private var isAskingToDelete: Binding<Bool> {
        Binding(
            get: { model.wallpaperAwaitingDeletion != nil },
            set: { _ in },
        )
    }

    private var isShowingProblem: Binding<Bool> {
        Binding(
            get: { model.problem != nil },
            set: { stillShowing in
                if !stillShowing {
                    model.dismissProblem()
                }
            },
        )
    }

    private var deleteQuestion: String {
        LibraryText.deleteQuestion.inTheAppLanguage(filledWith: model.wallpaperAwaitingDeletion?.name ?? "")
    }

    private var problemText: String {
        switch model.problem {
        case .wallpaperGone: LibraryText.wallpaperGone.inTheAppLanguage
        case .noSpaceLeft: LibraryText.noSpaceLeft.inTheAppLanguage
        case .changeNotKept: LibraryText.changeNotKept.inTheAppLanguage
        case nil: ""
        }
    }

    private var nameProblemText: String? {
        switch model.nameProblem {
        case .empty: LibraryText.nameEmpty.inTheAppLanguage
        case let .tooLong(limit): LibraryText.nameTooLong.inTheAppLanguage(filledWith: limit)
        case nil: nil
        }
    }

    private func openOnFirstAppearance() {
        guard !hasAskedToOpen else { return }

        hasAskedToOpen = true
        Task { await model.open() }
    }

    private func send(_ action: @escaping @MainActor () async -> Void) {
        Task.immediate { await action() }
    }
}

public extension LibraryScreen {
    static var defaultWallpaperNameStem: String {
        LibraryText.defaultNameStem.inTheAppLanguage
    }
}

private struct WallpaperNameField: View {
    let caption: String
    let problem: String?
    let keep: (String) -> Void
    let leave: () -> Void

    @State private var proposedName: String
    @State private var selectedText: TextSelection?
    @FocusState private var isFocused: Bool

    init(
        currentName: String,
        caption: String,
        problem: String?,
        keep: @escaping (String) -> Void,
        leave: @escaping () -> Void,
    ) {
        self.caption = caption
        self.problem = problem
        self.keep = keep
        self.leave = leave
        _proposedName = State(initialValue: currentName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(
                LibraryText.nameField.inTheAppLanguage,
                text: $proposedName,
                selection: $selectedText,
            )
            .labelsHidden()
            .accessibilityLabel(Text(verbatim: LibraryText.nameField.inTheAppLanguage))
            .focused($isFocused)
            .onSubmit { keep(proposedName) }
            .onExitCommand { leave() }
            Text(verbatim: caption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let problem {
                Text(verbatim: problem)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
        .onAppear(perform: selectTheWholeName)
        .onChange(of: problem) { _, newProblem in
            if let newProblem {
                AccessibilityNotification.Announcement(newProblem).post()
            }
        }
    }

    private func selectTheWholeName() {
        selectedText = TextSelection(range: proposedName.startIndex ..< proposedName.endIndex)
        isFocused = true
    }
}
