enum BrainStatus { understanding, selectingAi, optimizing, completed }

extension BrainStatusX on BrainStatus {
  String get label {
    switch (this) {
      case BrainStatus.understanding:
        return 'Understanding your request';
      case BrainStatus.selectingAi:
        return 'Selecting the best AI';
      case BrainStatus.optimizing:
        return 'Optimizing prompt';
      case BrainStatus.completed:
        return 'Ready';
    }
  }
}
