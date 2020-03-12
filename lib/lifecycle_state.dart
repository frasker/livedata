import 'package:flutter/widgets.dart';

import 'lifecycle.dart';

abstract class LifeCycleState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver
    implements LifecycleOwner {
  final _LifecycleOwnerImpl _mLifecycleOwner = _LifecycleOwnerImpl();
  static final int _INITIALIZING = 0; // Not yet created.
  static final int _CREATED = 1; // Created.
  static final int _STOPPED = 2; // Fully created, not started.
  static final int _STARTED = 3; // Created and started, not resumed.
  static final int _RESUMED = 4;

  int _mState = _INITIALIZING;

  @protected
  @mustCallSuper
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @protected
  @mustCallSuper
  @override
  void didChangeDependencies() {
    if (_mState == _INITIALIZING) {
      _mState = _CREATED;
      _mLifecycleOwner.mLifecycleRegistry.handleLifecycleEvent(Event.ON_READY);
      if (WidgetsBinding.instance.framesEnabled) {
        _mState = _STARTED;
        _mLifecycleOwner.mLifecycleRegistry
            .handleLifecycleEvent(Event.ON_PAUSE);
      }
    }
    super.didChangeDependencies();
  }

  @protected
  @mustCallSuper
  @override
  void dispose() {
    _mState = _INITIALIZING;
    _mLifecycleOwner.mLifecycleRegistry.handleLifecycleEvent(Event.ON_DEFUNCT);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_mState >= _CREATED) {
      switch (state) {
        case AppLifecycleState.resumed:
          _mState = _RESUMED;
          _mLifecycleOwner.mLifecycleRegistry
              .handleLifecycleEvent(Event.ON_RESUME);
          break;
        case AppLifecycleState.paused:
          _mState = _STOPPED;
          _mLifecycleOwner.mLifecycleRegistry
              .handleLifecycleEvent(Event.ON_INACTIVE);
          break;
        case AppLifecycleState.inactive:
          _mState = _STARTED;
          _mLifecycleOwner.mLifecycleRegistry
              .handleLifecycleEvent(Event.ON_PAUSE);
          break;
        default:
          break;
      }
    }
  }

  @override
  Lifecycle getLifecycle() {
    return _mLifecycleOwner.getLifecycle();
  }
}

class _LifecycleOwnerImpl extends LifecycleOwner {
  LifecycleRegistry mLifecycleRegistry;

  _LifecycleOwnerImpl() {
    mLifecycleRegistry = LifecycleRegistry(this);
  }

  @override
  Lifecycle getLifecycle() {
    return mLifecycleRegistry;
  }
}
