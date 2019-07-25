import 'package:meta/meta.dart';

import 'live_data.dart';
import 'map.dart';

class Transformations {
  /// Returns a {@code LiveData} mapped from the input {@code source} {@code LiveData} by applying
  /// {@code mapFunction} to each value set on {@code source}.
  /// <p>
  /// This method is analogous to {@link io.reactivex.Observable#map}.
  /// <p>
  /// {@code transform} will be executed on the main thread.
  /// <p>
  /// Here is an example mapping a simple {@code User} struct in a {@code LiveData} to a
  /// {@code LiveData} containing their full name as a {@code String}.
  ///
  /// <pre>
  /// LiveData<User> userLiveData = ...;
  /// LiveData<String> userFullNameLiveData =
  ///     Transformations.map(
  ///         userLiveData,
  ///         user -> user.firstName + user.lastName);
  /// });
  /// </pre>
  ///
  /// @param source      the {@code LiveData} to map from
  /// @param mapFunction a function to apply to each value set on {@code source} in order to set
  ///                    it
  ///                    on the output {@code LiveData}
  /// @param <X>         the generic type parameter of {@code source}
  /// @param <Y>         the generic type parameter of the returned {@code LiveData}
  /// @return a LiveData mapped from {@code source} to type {@code <Y>} by applying
  /// {@code mapFunction} to each value set.
  static LiveData<Y> map<X, Y>(
      LiveData<X> source, Y mapFunction(X x)) {
    final MediatorLiveData<Y> result = new MediatorLiveData<Y>();
    result.addSource(source, (x) {
      result.value = mapFunction(x);
    });
    return result;
  }

  /// Returns a {@code LiveData} mapped from the input {@code source} {@code LiveData} by applying
  /// {@code switchMapFunction} to each value set on {@code source}.
  /// <p>
  /// The returned {@code LiveData} delegates to the most recent {@code LiveData} created by
  /// calling {@code switchMapFunction} with the most recent value set to {@code source}, without
  /// changing the reference. In this way, {@code switchMapFunction} can change the 'backing'
  /// {@code LiveData} transparently to any observer registered to the {@code LiveData} returned
  /// by {@code switchMap()}.
  /// <p>
  /// Note that when the backing {@code LiveData} is switched, no further values from the older
  /// {@code LiveData} will be set to the output {@code LiveData}. In this way, the method is
  /// analogous to {@link io.reactivex.Observable#switchMap}.
  ///
  /// Here is an example class that holds a typed-in name of a user
  /// {@code String} (such as from an {@code EditText}) in a {@link LiveData} and
  /// returns a {@code LiveData} containing a List of {@code User} objects for users that have
  /// that name. It populates that {@code LiveData} by requerying a repository-pattern object
  /// each time the typed name changes.
  /// <p>
  /// This {@code ViewModel} would permit the observing UI to update "live" as the user ID text
  /// changes.
  ///
  /// <pre>
  /// class UserViewModel extends ViewModel {
  ///     MutableLiveData<String> nameQueryLiveData = ...
  ///
  ///     LiveData<List<String>> getUsersWithNameLiveData() {
  ///         return Transformations.switchMap(
  ///             nameQueryLiveData,
  ///                 name -> myDataSource.getUsersWithNameLiveData(name));
  ///     }
  ///
  ///     void setNameQuery(String name) {
  ///         this.nameQueryLiveData.setValue(name);
  ///     }
  /// }
  /// </pre>
  ///
  /// @param source            the {@code LiveData} to map from
  /// @param switchMapFunction a function to apply to each value set on {@code source} to create a
  ///                          new delegate {@code LiveData} for the returned one
  /// @param <X>               the generic type parameter of {@code source}
  /// @param <Y>               the generic type parameter of the returned {@code LiveData}
  /// @return a LiveData mapped from {@code source} to type {@code <Y>} by delegating
  /// to the LiveData returned by applying {@code switchMapFunction} to each
  /// value set
  static LiveData<Y> switchMap<X, Y>(LiveData<X> source,
      LiveData<Y> switchMapFunction(X source)) {
    final MediatorLiveData<Y> result = new MediatorLiveData<Y>();
    LiveData<Y> mSource;
    result.addSource(source, (x) {
      LiveData<Y> newLiveData = switchMapFunction(x);
      if (mSource == newLiveData) {
        return;
      }
      if (mSource != null) {
        result.removeSource(mSource);
      }
      mSource = newLiveData;
      if (mSource != null) {
        result.addSource(mSource, (y) {
          result.value = y;
        });
      }
    });
    return result;
  }
}

class MediatorLiveData<T> extends MutableLiveData<T> {
  SafeIterableMap<LiveData, _Source> _mSources = new SafeIterableMap();


  /// Starts to listen the given {@code source} LiveData, {@code onChanged} observer will be called
  /// when {@code source} value was changed.
  /// <p>
  /// {@code onChanged} callback will be called only when this {@code MediatorLiveData} is active.
  /// <p> If the given LiveData is already added as a source but with a different Observer,
  /// {@link IllegalArgumentException} will be thrown.
  ///
  /// @param source    the {@code LiveData} to listen to
  /// @param onChanged The observer that will receive the events
  /// @param <S>       The type of data hold by {@code source} LiveData
  void addSource<S>(LiveData<S> source, Observer<S> onChanged) {
    _Source<S> e = new _Source<S>(source, onChanged);
    _Source existing = _mSources.putIfAbsent(source, e);
    if (existing != null && existing.mObserver != onChanged) {
      throw new Exception(
          "This source was already added with the different observer");
    }
    if (existing != null) {
      return;
    }

    if (hasActiveObservers()) {
      e.plug();
    }
  }

  /// Stops to listen the given {@code LiveData}.
  ///
  /// @param toRemote {@code LiveData} to stop to listen
  /// @param <S>      the type of data hold by {@code source} LiveData
  void removeSource<S>(LiveData<S> toRemote) {
    _Source source = _mSources.remove(toRemote);
    if (source != null) {
      source.unplug();
    }
  }

  @mustCallSuper
  @override
  void onActive() {
    for (MapEntry<LiveData, _Source> source in _mSources) {
      source.value.plug();
    }
  }

  @override
  void onInactive() {
    for (MapEntry<LiveData, _Source> source in _mSources) {
      source.value.unplug();
    }
  }

}

class _Source<V> {
  final LiveData<V> mLiveData;
  final Observer<V> mObserver;
  int mVersion = LiveData.START_VERSION;

  _Source(this.mLiveData, this.mObserver);

  void plug() {
    mLiveData.observeForever(onChanged);
  }

  void unplug() {
    mLiveData.removeObserver(onChanged);
  }

  void onChanged(V v) {
    if (mVersion != mLiveData.version) {
      mVersion = mLiveData.version;
      mObserver(v);
    }
  }
}
