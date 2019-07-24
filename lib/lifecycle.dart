import 'live_data.dart';
import 'map.dart';

enum LifeState {
  /// The [LifeState.dispose] method has been called and the [LifeState] object is
  /// no longer able to build.
  DESTROYED,

  /// The [LifeState] object has been created. [LifeState.initState] is called at this
  /// time.
  INITIALIZED,

  /// The [LifeState] object is ready to build and [LifeState.dispose] has not yet been
  /// called.
  CREATED,

  /// The application is not currently visible to the user, not responding to
  /// user input, and running in the background.
  ///
  /// When the application is in this state, the engine will not call the
  /// [Window.onBeginFrame] and [Window.onDrawFrame] callbacks.
  STARTED,

  /// The application is visible and responding to user input.
  RESUMED,
}

enum Event {
  /// Constant for onDestroy event of the {@link LifecycleOwner}.
  ON_DEFUNCT,

  /// Constant for onReady event of the {@link LifecycleOwner}.
  ON_READY,

  /// Constant for onPause event of the {@link LifecycleOwner}.
  ON_PAUSE,

  /// Constant for onInactive event of the {@link LifecycleOwner}.
  ON_INACTIVE,

  /// Constant for onResume event of the {@link LifecycleOwner}.
  ON_RESUME,

  /// An {@link Event Event} constant that can be used to match all events.
  ON_ANY
}

class StateUtil {
  static bool isAtLeast(LifeState current, LifeState compare) {
    return current.index >= compare.index;
  }
}

abstract class Lifecycle {
  /// Adds a LifecycleObserver that will be notified when the LifecycleOwner changes
  /// state.
  /// <p>
  /// The given observer will be brought to the current state of the LifecycleOwner.
  /// For example, if the LifecycleOwner is in {@link State#STARTED} state, the given observer
  /// will receive {@link Event#ON_CREATE}, {@link Event#ON_START} events.
  ///
  /// @param observer The observer to notify.
  addObserver(LifecycleObserver observer);

  /// Removes the given observer from the observers list.
  /// <p>
  /// If this method is called while a state change is being dispatched,
  /// <ul>
  /// <li>If the given observer has not yet received that event, it will not receive it.
  /// <li>If the given observer has more than 1 method that observes the currently dispatched
  /// event and at least one of them received the event, all of them will receive the event and
  /// the removal will happen afterwards.
  /// </ul>
  ///
  /// @param observer The observer to be removed.
  removeObserver(LifecycleObserver observer);

  /// Returns the current state of the Lifecycle.
  ///
  /// @return The current state of the Lifecycle.
  LifeState getCurrentState();
}

abstract class LifecycleOwner {
  /// Returns the Lifecycle of the provider.
  ///
  /// @return The lifecycle of the provider.

  Lifecycle getLifecycle();
}




class LifecycleObserver {

  onReady(LifecycleOwner owner) {}

  onResume(LifecycleOwner owner) {}

  onPause(LifecycleOwner owner) {}

  onInactive(LifecycleOwner owner) {}

  onDefunct(LifecycleOwner owner) {}
}

class LifecycleRegistry extends Lifecycle {
  FastSafeIterableMap<LifecycleObserver, _ObserverWithState> _mObserverMap =
      FastSafeIterableMap<LifecycleObserver, _ObserverWithState>();

  /// Current state
  LifeState _mState = LifeState.INITIALIZED;

  LifecycleOwner _mLifecycleOwner;

  int _mAddingObserverCounter = 0;

  bool _mHandlingEvent = false;
  bool _mNewEventOccurred = false;

  // we have to keep it for cases:
  // void onStart() {
  //     mRegistry.removeObserver(this);
  //     mRegistry.add(newObserver);
  // }
  // newObserver should be brought only to CREATED state during the execution of
  // this onStart method. our invariant with mObserverMap doesn't help, because parent observer
  // is no longer in the map.
  List<LifeState> _mParentStates = new List<LifeState>();

  LifecycleRegistry(this._mLifecycleOwner);

  /// Moves the Lifecycle to the given state and dispatches necessary events to the observers.
  ///
  /// @param state new state
  void markState(LifeState state) {
    _moveToState(state);
  }

  /// Sets the current state and notifies the observers.
  /// <p>
  /// Note that if the {@code currentState} is the same state as the last call to this method,
  /// calling this method has no effect.
  ///
  /// @param event The event that was received
  handleLifecycleEvent(Event event) {
    LifeState next = _getStateAfter(event);
    _moveToState(next);
  }
  
  void _moveToState(LifeState next) {
    if (_mState == next) {
      return;
    }
    _mState = next;
    if (_mHandlingEvent || _mAddingObserverCounter != 0) {
      _mNewEventOccurred = true;
      // we will figure out what to do on upper level.
      return;
    }
    _mHandlingEvent = true;
    _sync();
    _mHandlingEvent = false;
  }

  _sync() {
    if (_mLifecycleOwner == null) {
      //you shouldn't try dispatch new events from it
      return;
    }
    while (!_isSynced()) {
      _mNewEventOccurred = false;
      // no need to check eldest for nullability, because isSynced does it for us.
      if (_mState.index < _mObserverMap.eldest().value.mState.index) {
        _backwardPass(_mLifecycleOwner);
      }
      Entry<LifecycleObserver, _ObserverWithState> newest =
          _mObserverMap.newest();
      if (!_mNewEventOccurred &&
          newest != null &&
          _mState.index > newest.value.mState.index) {
        _forwardPass(_mLifecycleOwner);
      }
    }
    _mNewEventOccurred = false;
  }

  _backwardPass(LifecycleOwner lifecycleOwner) {
    Iterator<Entry<LifecycleObserver, _ObserverWithState>> descendingIterator =
        _mObserverMap.descendingIterator();
    while (descendingIterator.moveNext() && !_mNewEventOccurred) {
      Entry<LifecycleObserver, _ObserverWithState> entry =
          descendingIterator.current;
      _ObserverWithState observer = entry.value;
      while ((observer.mState.index > _mState.index &&
          !_mNewEventOccurred &&
          _mObserverMap.containsValue(entry.key))) {
        Event event = _downEvent(observer.mState);
        _pushParentState(_getStateAfter(event));
        observer.dispatchEvent(lifecycleOwner, event);
        _popParentState();
      }
    }
  }

  void _pushParentState(LifeState state) {
    _mParentStates.add(state);
  }

  void _popParentState() {
    _mParentStates.remove(_mParentStates.length - 1);
  }

  _forwardPass(LifecycleOwner lifecycleOwner) {
    IteratorWithAdditions<LifecycleObserver, _ObserverWithState>
        ascendingIterator = _mObserverMap.iteratorWithAdditions();
    while (ascendingIterator.moveNext() && !_mNewEventOccurred) {
      Entry<LifecycleObserver, _ObserverWithState> entry =
          ascendingIterator.current;
      _ObserverWithState observer = entry.value;
      while ((observer.mState.index < _mState.index &&
          !_mNewEventOccurred &&
          _mObserverMap.containsValue(entry.key))) {
        _pushParentState(observer.mState);
        observer.dispatchEvent(lifecycleOwner, _upEvent(observer.mState));
        _popParentState();
      }
    }
  }

  bool _isSynced() {
    if (_mObserverMap.length == 0) {
      return true;
    }
    LifeState eldestObserverState = _mObserverMap.eldest().value.mState;
    LifeState newestObserverState = _mObserverMap.newest().value.mState;
    return eldestObserverState == newestObserverState &&
        _mState == newestObserverState;
  }

  static LifeState _getStateAfter(Event event) {
    switch (event) {
      case Event.ON_READY:
      case Event.ON_INACTIVE:
        return LifeState.CREATED;
      case Event.ON_PAUSE:
        return LifeState.STARTED;
      case Event.ON_RESUME:
        return LifeState.RESUMED;
      case Event.ON_DEFUNCT:
        return LifeState.DESTROYED;
      case Event.ON_ANY:
        break;
    }
    throw new Exception("Unexpected event value " + event.toString());
  }

  static Event _downEvent(LifeState state) {
    switch (state) {
      case LifeState.INITIALIZED:
        throw new Exception();
      case LifeState.CREATED:
        return Event.ON_DEFUNCT;
      case LifeState.STARTED:
        return Event.ON_INACTIVE;
      case LifeState.RESUMED:
        return Event.ON_PAUSE;
      case LifeState.DESTROYED:
        throw new Exception();
    }
    throw new Exception("Unexpected state value " + state.toString());
  }

  static Event _upEvent(LifeState state) {
    switch (state) {
      case LifeState.INITIALIZED:
      case LifeState.DESTROYED:
        return Event.ON_READY;
      case LifeState.CREATED:
        return Event.ON_PAUSE;
      case LifeState.STARTED:
        return Event.ON_RESUME;
      case LifeState.RESUMED:
        throw new Exception();
    }
    throw new Exception("Unexpected state value " + state.toString());
  }

  static LifeState _min(LifeState state1, LifeState state2) {
    return state2 != null && state2.index < state1.index ? state2 : state1;
  }

  @override
  addObserver(LifecycleObserver observer) {
    LifeState initialState =
        _mState == LifeState.DESTROYED ? LifeState.DESTROYED : LifeState.INITIALIZED;
    _ObserverWithState statefulObserver =
        new _ObserverWithState(observer, initialState);
    _ObserverWithState previous =
        _mObserverMap.putIfAbsent(observer, statefulObserver);
    if (previous != null) {
      return null;
    }
    if (_mLifecycleOwner == null) {
      // it is null we should be destroyed. Fallback quickly
      return null;
    }
    bool isReentrance = _mAddingObserverCounter != 0 || _mHandlingEvent;
    LifeState targetState = _calculateTargetState(observer);
    _mAddingObserverCounter++;
    while ((statefulObserver.mState.index < targetState.index &&
        _mObserverMap.containsValue(observer))) {
      _pushParentState(statefulObserver.mState);
      statefulObserver.dispatchEvent(
          _mLifecycleOwner, _upEvent(statefulObserver.mState));
      _popParentState();
      // mState / subling may have been changed recalculate
      targetState = _calculateTargetState(observer);
    }
    if (!isReentrance) {
      // we do sync only on the top level.
      _sync();
    }
    _mAddingObserverCounter--;
  }

  LifeState _calculateTargetState(LifecycleObserver observer) {
    Entry<LifecycleObserver, _ObserverWithState> previous =
        _mObserverMap.ceil(observer);

    LifeState siblingState = previous != null ? previous.value.mState : null;
    LifeState parentState = _mParentStates.isNotEmpty
        ? _mParentStates[_mParentStates.length - 1]
        : null;
    return _min(_min(_mState, siblingState), parentState);
  }

  @override
  LifeState getCurrentState() {
    return _mState;
  }

  @override
  removeObserver(LifecycleObserver observer) {
    // we consciously decided not to send destruction events here in opposition to addObserver.
    // Our reasons for that:
    // 1. These events haven't yet happened at all. In contrast to events in addObservers, that
    // actually occurred but earlier.
    // 2. There are cases when removeObserver happens as a consequence of some kind of fatal
    // event. If removeObserver method sends destruction events, then a clean up routine becomes
    // more cumbersome. More specific example of that is: your LifecycleObserver listens for
    // a web connection, in the usual routine in OnStop method you report to a server that a
    // session has just ended and you close the connection. Now let's assume now that you
    // lost an internet and as a result you removed this observer. If you get destruction
    // events in removeObserver, you should have a special case in your onStop method that
    // checks if your web connection died and you shouldn't try to report anything to a server.
    _mObserverMap.remove(observer);
  }

  int getObserverCount() {
    return _mObserverMap.length;
  }
}

class _ObserverWithState {
  LifeState mState;
  GenericLifecycleObserver mLifecycleObserver;

  _ObserverWithState(LifecycleObserver observer, LifeState initialState){
    mLifecycleObserver = _FullLifecycleObserverAdapter(observer);
    mState = initialState;
  }

  void dispatchEvent(LifecycleOwner owner, Event event) {
    LifeState newState = LifecycleRegistry._getStateAfter(event);
    mState = LifecycleRegistry._min(mState, newState);
    mLifecycleObserver.onStateChanged(owner, event);
    mState = newState;
  }
}

class _FullLifecycleObserverAdapter implements GenericLifecycleObserver {

  final LifecycleObserver mObserver;

  _FullLifecycleObserverAdapter(this.mObserver);

  @override
  onReady(LifecycleOwner owner) {
    mObserver.onReady(owner);
  }

  @override
  onDefunct(LifecycleOwner owner) {
    mObserver.onDefunct(owner);
  }

  @override
  onInactive(LifecycleOwner owner) {
    mObserver.onInactive(owner);
  }

  @override
  onPause(LifecycleOwner owner) {
    mObserver.onPause(owner);
  }

  @override
  onResume(LifecycleOwner owner) {
    mObserver.onResume(owner);
  }

  @override
  onStateChanged(LifecycleOwner owner, Event event) {
    switch(event){
      case Event.ON_READY:
        mObserver.onReady(owner);
        break;
      case Event.ON_DEFUNCT:
        mObserver.onDefunct(owner);
        break;
      case Event.ON_PAUSE:
        mObserver.onPause(owner);
        break;
      case Event.ON_INACTIVE:
        mObserver.onInactive(owner);
        break;
      case Event.ON_RESUME:
        mObserver.onResume(owner);
        break;
      case Event.ON_ANY:
        throw new Exception("ON_ANY must not been send by anybody");
    }
  }

  

  
}
