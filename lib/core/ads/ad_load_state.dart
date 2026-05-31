sealed class AdLoadState {
  const AdLoadState();
}

class AdLoaded extends AdLoadState {
  const AdLoaded();
}

class AdFailed extends AdLoadState {
  const AdFailed();
}
