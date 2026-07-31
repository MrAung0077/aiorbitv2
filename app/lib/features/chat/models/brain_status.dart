enum BrainStatus { understanding, selectingAi, optimizing, completed }

extension BrainStatusX on BrainStatus {
  String get label {
    switch (this) {
      case BrainStatus.understanding:
        return 'Understanding your goal';
      case BrainStatus.selectingAi:
        return 'Planning the best approach';
      case BrainStatus.optimizing:
        return 'Preparing your result';
      case BrainStatus.completed:
        return 'Ready';
    }
  }
}
