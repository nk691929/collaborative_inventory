import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
class ConnectivityService {
  bool _isOnline = true;
  final Stream<bool> _connectivityStream;

  ConnectivityService() : _connectivityStream = _createConnectivityStream();
  bool get isOnline => _isOnline;
  static Stream<bool> _createConnectivityStream() async* {
    yield true; 
    if (kDebugMode) {
        await Future.delayed(const Duration(seconds: 10));
        yield false;
        await Future.delayed(const Duration(seconds: 10));
        yield true;
    }
  }
  
  void setOnlineStatus(bool status) {
    if (_isOnline != status) {
      _isOnline = status;
      debugPrint('Connectivity status manually set to: $_isOnline');
    }
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  
  return service._connectivityStream.map((status) {
    service.setOnlineStatus(status);
    return status;
  });
});
