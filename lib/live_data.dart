import 'package:meta/meta.dart';

import 'lifecycle.dart';
import 'map.dart';

/// A simple callback that can receive from {@link LiveData}.
///
/// @param <T> The type of the parameter
///
/// @see LiveData LiveData - for a usage description.
typedef Observer<T> = Function(T t);

class LiveData<T> {
  static final int START_VERSION = -1;
  static final Object NOT_SET = new Object();
  SafeIterableMap _mObservers = new SafeIterableMap();

  int _mActiveCount = 0;
  Object _mData = NOT_SET;
  int _mVersion = START_VERSION;
  bool _mDispatchingValue;
  bool _mDispatchInvalidated;

  void _considerNotify(_ObserverWrapper observer) {
    if (!observer.mActive) {
      return;
    }
    // Check latest state b4 dispatch. Maybe it changed state but we didn't get the event yet.
    //
    // we still first check observer.active to keep it as the entrance for events. So even if
    // the observer moved to an active state, if we've not received that event, we better not
    // notify for a more predictable notification order.
    if (!observer.shouldBeActive()) {
      observer.activeStateChanged(false);
      return;
    }
    if (observer.mLastVersion >= _mVersion) {
      return;
    }
    observer.mLastVersion = _mVersion;
    //noinspection unchecked
    observer.mObserver(_mData as T);
  }

  void _dispatchingValue(_ObserverWrapper initiator) {
    if (_mDispatchingValue) {
      _mDispatchInvalidated = true;
      return;
    }
    _mDispatchingValue = true;
    do {
      _mDispatchInvalidated = false;
      if (initiator != null) {
        _considerNotify(initiator);
        initiator = null;
      } else {
        for (IteratorWithAdditions<Observer<T>, _ObserverWrapper> iterator =
                _mObservers.iteratorWithAdditions();
            iterator.moveNext();) {
          _considerNotify(iterator.current.value);
          if (_mDispatchInvalidated) {
            break;
          }
        }
      }
    } while (_mDispatchInvalidated);
    _mDispatchingValue = false;
  }

  /// Adds the given observer to the observers list within the lifespan of the given
  /// owner. The events are dispatched on the main thread. If LiveData already has data
  /// set, it will be delivered to the observer.
  /// <p>
  /// The observer will only receive events if the owner is in {@link Lifecycle.State#STARTED}
  /// or {@link Lifecycle.State#RESUMED} state (active).
  /// <p>
  /// If the owner moves to the {@link Lifecycle.State#DESTROYED} state, the observer will
  /// automatically be removed.
  /// <p>
  /// When data changes while the {@code owner} is not active, it will not receive any updates.
  /// If it becomes active again, it will receive the last available data automatically.
  /// <p>
  /// LiveData keeps a strong reference to the observer and the owner as long as the
  /// given LifecycleOwner is not destroyed. When it is destroyed, LiveData removes references to
  /// the observer &amp; the owner.
  /// <p>
  /// If the given owner is already in {@link Lifecycle.State#DESTROYED} state, LiveData
  /// ignores the call.
  /// <p>
  /// If the given owner, observer tuple is already in the list, the call is ignored.
  /// If the observer is already in the list with another owner, LiveData throws an
  /// {@link IllegalArgumentException}.
  ///
  /// @param owner    The LifecycleOwner which controls the observer
  /// @param observer The observer that will receive the events
  void observe(LifecycleOwner owner, Observer<T> observer) {
    if (owner.getLifecycle().getCurrentState() == LifeState.DESTROYED) {
      // ignore
      return;
    }
    _LifecycleBoundObserver wrapper =
        new _LifecycleBoundObserver(this, owner, observer: observer);
    _ObserverWrapper existing = _mObservers.putIfAbsent(observer, wrapper);
    if (existing != null && !existing.isAttachedTo(owner)) {
      throw new Exception(
          "Cannot add the same observer with different lifecycles");
    }
    if (existing != null) {
      return;
    }
    owner.getLifecycle().addObserver(wrapper);
  }

  /// Adds the given observer to the observers list. This call is similar to
  /// {@link LiveData#observe(LifecycleOwner, Observer)} with a LifecycleOwner, which
  /// is always active. This means that the given observer will receive all events and will never
  /// be automatically removed. You should manually call {@link #removeObserver(Observer)} to stop
  /// observing this LiveData.
  /// While LiveData has one of such observers, it will be considered
  /// as active.
  /// <p>
  /// If the observer was already added with an owner to this LiveData, LiveData throws an
  /// {@link IllegalArgumentException}.
  ///
  /// @param observer The observer that will receive the events
  void observeForever(Observer<T> observer) {
    _AlwaysActiveObserver wrapper = new _AlwaysActiveObserver(this, observer);
    _ObserverWrapper existing = _mObservers.putIfAbsent(observer, wrapper);
    if (existing != null && existing is _LifecycleBoundObserver) {
      throw new Exception(
          "Cannot add the same observer with different lifecycles");
    }
    if (existing != null) {
      return;
    }
    wrapper.activeStateChanged(true);
  }

  /// Removes the given observer from the observers list.
  ///
  /// @param observer The Observer to receive events.
  void removeObserver(final Observer<T> observer) {
    _ObserverWrapper removed = _mObservers.remove(observer);
    if (removed == null) {
      return;
    }
    removed.detachObserver();
    removed.activeStateChanged(false);
  }

  /// Removes all observers that are tied to the given {@link LifecycleOwner}.
  ///
  /// @param owner The {@code LifecycleOwner} scope for the observers to be removed.
  void removeObservers(final LifecycleOwner owner) {
    for (MapEntry<Observer<T>, _ObserverWrapper> entry in _mObservers) {
      if (entry.value.isAttachedTo(owner)) {
        removeObserver(entry.key);
      }
    }
  }

  /// Sets the value. If there are active observers, the value will be dispatched to them.
  /// <p>
  ///
  /// @param value The new value
  @protected
  set value(T value) {
    _mVersion++;
    _mData = value;
    _dispatchingValue(null);
  }

  /// Returns the current value.
  /// Note that calling this method on a background thread does not guarantee that the latest
  /// value set will be received.
  ///
  /// @return the current value
  T get value {
    Object data = _mData;
    if (data != NOT_SET) {
      //noinspection unchecked
      return data as T;
    }
    return null;
  }

  int get version => _mVersion;

  /// Called when the number of active observers change to 1 from 0.
  /// <p>
  /// This callback can be used to know that this LiveData is being used thus should be kept
  /// up to date.
  @protected
  void onActive() {}

  /// Called when the number of active observers change from 1 to 0.
  /// <p>
  /// This does not mean that there are no observers left, there may still be observers but their
  /// lifecycle states aren't {@link Lifecycle.State#STARTED} or {@link Lifecycle.State#RESUMED}
  /// (like an Activity in the back stack).
  /// <p>
  /// You can check if there are observers via {@link #hasObservers()}.
  @protected
  void onInactive() {}

  /// Returns true if this LiveData has observers.
  ///
  /// @return true if this LiveData has observers
  bool hasObservers() {
    return _mObservers.length > 0;
  }

  /// Returns true if this LiveData has active observers.
  ///
  /// @return true if this LiveData has active observers
  bool hasActiveObservers() {
    return _mActiveCount > 0;
  }
}

abstract class _ObserverWrapper<T> {
  final LiveData<T> mLiveData;
  final Observer<T> mObserver;
  bool mActive;
  int mLastVersion = LiveData.START_VERSION;

  bool isAttachedTo(LifecycleOwner owner) {
    return false;
  }

  void detachObserver() {}

  _ObserverWrapper(this.mLiveData, this.mObserver);

  bool shouldBeActive();

  void activeStateChanged(bool newActive) {
    if (newActive == mActive) {
      return;
    }
    // immediately set active state, so we'd never dispatch anything to inactive
    // owner
    mActive = newActive;
    bool wasInactive = mLiveData._mActiveCount == 0;
    mLiveData._mActiveCount += mActive ? 1 : -1;
    if (wasInactive && mActive) {
      mLiveData.onActive();
    }
    if (mLiveData._mActiveCount == 0 && !mActive) {
      mLiveData.onInactive();
    }
    if (mActive) {
      mLiveData._dispatchingValue(this);
    }
  }
}

/// Internal class that can receive any lifecycle change and dispatch it to the receiver.
/// @hide
abstract class GenericLifecycleObserver extends LifecycleObserver {
  /// Called when a state transition event happens.
  ///
  /// @param source The source of the event
  /// @param event The event
  onStateChanged(LifecycleOwner owner, Event event) {}
}

class _LifecycleBoundObserver<T> extends _ObserverWrapper<T>
    implements GenericLifecycleObserver {
  final LiveData<T> mLiveData;
  final LifecycleOwner mOwner;

  _LifecycleBoundObserver(this.mLiveData, this.mOwner, {Observer<T> observer})
      : super(mLiveData, observer);

  @override
  bool shouldBeActive() {
    return StateUtil.isAtLeast(
        mOwner.getLifecycle().getCurrentState(), LifeState.STARTED);
  }

  @override
  bool isAttachedTo(LifecycleOwner owner) {
    return mOwner == owner;
  }

  @override
  void detachObserver() {
    mOwner.getLifecycle().removeObserver(this);
  }

  @override
  onReady(LifecycleOwner owner) {}

  @override
  onDefunct(LifecycleOwner owner) {}

  @override
  onInactive(LifecycleOwner owner) {}

  @override
  onPause(LifecycleOwner owner) {}

  @override
  onResume(LifecycleOwner owner) {}

  @override
  onStateChanged(LifecycleOwner owner, Event event) {}
}

class _AlwaysActiveObserver<T> extends _ObserverWrapper<T> {
  _AlwaysActiveObserver(LiveData<T> owner, Observer<T> observer)
      : super(owner, observer);

  @override
  bool shouldBeActive() {
    return true;
  }
}

/// {@lin«k LiveData} which publicly exposes {@link #setValue(T)} and {@link #postValue(T)} method.
///
/// @param <T> The type of data hold by this instance
class MutableLiveData<T> extends LiveData<T> {
  @override
  set value(T value) {
    super.value = value;
  }
}
