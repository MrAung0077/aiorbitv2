enum BetaAccessStatus { checking, needsInvitation, activating, authorized }

class BetaAccessState {
  const BetaAccessState({
    this.status = BetaAccessStatus.checking,
    this.message,
  });

  final BetaAccessStatus status;
  final String? message;

  bool get isAuthorized => status == BetaAccessStatus.authorized;
}
