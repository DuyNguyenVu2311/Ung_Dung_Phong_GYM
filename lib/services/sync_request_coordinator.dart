class SyncRequestCoordinator {
  Future<bool>? _activeRequest;
  bool _requestedAgain = false;

  Future<bool> run(Future<bool> Function() syncPass) {
    final activeRequest = _activeRequest;
    if (activeRequest != null) {
      _requestedAgain = true;
      return activeRequest;
    }

    late final Future<bool> request;
    request = _runRequestedPasses(syncPass).whenComplete(() {
      if (identical(_activeRequest, request)) _activeRequest = null;
    });
    _activeRequest = request;
    return request;
  }

  Future<bool> _runRequestedPasses(Future<bool> Function() syncPass) async {
    bool succeeded;
    do {
      _requestedAgain = false;
      succeeded = await syncPass();
    } while (_requestedAgain);
    return succeeded;
  }
}
