import Presentation
import SwiftUI
import UniformTypeIdentifiers

public extension View {
    func importingPictures(with model: PictureImportModel) -> some View {
        modifier(PictureImportPresenter(model: model))
    }
}

private struct PictureImportPresenter: ViewModifier {
    private static let summaryMinimumWidth: CGFloat = 360
    private static let summaryMaximumHeight: CGFloat = 320

    let model: PictureImportModel

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: isChoosingFiles,
                allowedContentTypes: [.image, .movie],
                allowsMultipleSelection: allowsSeveralFiles,
                onCompletion: importChosenFiles,
                onCancellation: model.cancelChoosingFiles,
            )
            .overlay {
                if model.isImporting {
                    importingSign
                }
            }
            .sheet(isPresented: isShowingOutcome) {
                if let outcome = model.outcome {
                    summary(of: outcome.wordingInTheAppLanguage)
                }
            }
            .alert(Text(verbatim: refusalMessage), isPresented: isShowingRefusal) {
                Button(role: .cancel) {
                    model.dismissRefusal()
                } label: {
                    Text(verbatim: PictureImportText.ok.inTheAppLanguage)
                }
            }
    }

    private var importingSign: some View {
        VStack(spacing: 12) {
            ProgressView {
                Text(verbatim: PictureImportText.importing.inTheAppLanguage)
            }
            Button(action: model.stopImporting) {
                Text(verbatim: PictureImportText.stop.inTheAppLanguage)
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func summary(of wording: ImportOutcomeWording) -> some View {
        VStack(alignment: .trailing, spacing: 16) {
            ImportSummaryList(headline: wording.headline, notes: wording.notes)
                .frame(maxHeight: Self.summaryMaximumHeight)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                model.dismissOutcome()
            } label: {
                Text(verbatim: PictureImportText.ok.inTheAppLanguage)
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(minWidth: Self.summaryMinimumWidth)
        .onExitCommand(perform: model.dismissOutcome)
        .onAppear {
            AccessibilityNotification.Announcement(wording.headline).post()
        }
    }

    private var allowsSeveralFiles: Bool {
        guard case .slot = model.destinationAwaitingFiles else { return true }

        return false
    }

    private var isChoosingFiles: Binding<Bool> {
        Binding(
            get: { model.destinationAwaitingFiles != nil },
            set: { _ in },
        )
    }

    private var isShowingOutcome: Binding<Bool> {
        Binding(
            get: { model.outcome != nil },
            set: { stillShowing in
                if !stillShowing {
                    model.dismissOutcome()
                }
            },
        )
    }

    private var isShowingRefusal: Binding<Bool> {
        Binding(
            get: { model.refusal != nil },
            set: { stillShowing in
                if !stillShowing {
                    model.dismissRefusal()
                }
            },
        )
    }

    private var refusalMessage: String {
        model.refusal?.messageInTheAppLanguage ?? ""
    }

    private func importChosenFiles(_ result: Result<[URL], any Error>) {
        guard case let .success(files) = result, !files.isEmpty else {
            model.cancelChoosingFiles()
            return
        }

        Task.immediate { await model.importChosenFiles(files) }
    }
}
