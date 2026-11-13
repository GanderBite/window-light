import Foundation

@MainActor
struct ArrangingUndo {
    private enum Direction {
        case backward, forward

        var opposite: Self {
            self == .backward ? .forward : .backward
        }
    }

    private let model: WallpaperModel

    init(model: WallpaperModel) {
        self.model = model
    }

    func stepCountChanged(from oldCount: Int, to newCount: Int, in undoManager: UndoManager?) {
        guard let undoManager else { return }

        if newCount == 0 {
            undoManager.removeAllActions(withTarget: model)
        } else if newCount > oldCount {
            let stepName = model.lastStep.flatMap { ArrangingWording.undoActionName(of: $0, from: .module) }
            Self.register(.backward, named: stepName ?? "", for: model, in: undoManager)
        }
    }

    private static func register(
        _ direction: Direction,
        named stepName: String,
        for model: WallpaperModel,
        in undoManager: UndoManager,
    ) {
        undoManager.registerUndo(withTarget: model) { [weak undoManager] model in
            MainActor.assumeIsolated {
                send(direction, to: model)
                guard let undoManager else { return }

                register(direction.opposite, named: stepName, for: model, in: undoManager)
            }
        }
        undoManager.setActionName(stepName)
    }

    private static func send(_ direction: Direction, to model: WallpaperModel) {
        Task.immediate {
            switch direction {
            case .backward: await model.undo()
            case .forward: await model.redo()
            }
        }
    }
}
