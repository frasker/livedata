import 'dart:collection';

import 'package:meta/meta.dart';

class SafeIterableMap<K, V> extends Iterable<MapEntry<K, V>> {
  Entry<K, V> _mStart;
  Entry<K, V> _mEnd;

  HashMap<SupportRemove<K, V>, bool> _mIterators =
      new HashMap<SupportRemove<K, V>, bool>();

  int _mSize = 0;

  @protected
  Entry<K, V> get(K k) {
    Entry<K, V> currentNode = _mStart;
    while (currentNode != null) {
      if (currentNode.key == k) {
        break;
      }
      currentNode = currentNode.mNext;
    }
    return currentNode;
  }

  /// If the specified key is not already associated
  /// with a value, associates it with the given value.
  ///
  /// @param key key with which the specified value is to be associated
  /// @param v   value to be associated with the specified key
  /// @return the previous value associated with the specified key,
  /// or {@code null} if there was no mapping for the key
  V putIfAbsent(K key, V v) {
    Entry<K, V> entry = get(key);
    if (entry != null) {
      return entry._mValue;
    }
    put(key, v);
    return null;
  }

  @protected
  Entry<K, V> put(K key, V v) {
    Entry<K, V> newEntry = new Entry<K, V>(key, v);
    _mSize++;
    if (_mEnd == null) {
      _mStart = newEntry;
      _mEnd = _mStart;
      return newEntry;
    }

    _mEnd.mNext = newEntry;
    newEntry.mPrevious = _mEnd;
    _mEnd = newEntry;
    return newEntry;
  }

  /// Removes the mapping for a key from this map if it is present.
  ///
  /// @param key key whose mapping is to be removed from the map
  /// @return the previous value associated with the specified key,
  /// or {@code null} if there was no mapping for the key
  V remove(K key) {
    Entry<K, V> toRemove = get(key);
    if (toRemove == null) {
      return null;
    }
    _mSize--;
    if (_mIterators.isNotEmpty) {
      for (SupportRemove<K, V> iter in _mIterators.keys) {
        iter.supportRemove(toRemove);
      }
    }

    if (toRemove.mPrevious != null) {
      toRemove.mPrevious.mNext = toRemove.mNext;
    } else {
      _mStart = toRemove.mNext;
    }

    if (toRemove.mNext != null) {
      toRemove.mNext.mPrevious = toRemove.mPrevious;
    } else {
      _mEnd = toRemove.mPrevious;
    }

    toRemove.mNext = null;
    toRemove.mPrevious = null;
    return toRemove._mValue;
  }

  int get length => _mSize;

  /// @return eldest added entry or null
  MapEntry<K, V> eldest() {
    return _mStart;
  }

  /// @return newest added entry or null
  MapEntry<K, V> newest() {
    return _mEnd;
  }

  @override
  Iterator<MapEntry<K, V>> get iterator {
    _ListIterator<K, V> iterator = new _AscendingIterator<K, V>(_mStart, _mEnd);
    _mIterators[iterator] = false;
    return iterator;
  }

  /// @return an descending iterator, which doesn't include new elements added during an
  /// iteration.
  Iterator<MapEntry<K, V>> descendingIterator() {
    _DescendingIterator<K, V> iterator =
        new _DescendingIterator<K, V>(_mEnd, _mStart);
    _mIterators[iterator] = false;
    return iterator;
  }

  /// return an iterator with additions.
  IteratorWithAdditions iteratorWithAdditions() {
    IteratorWithAdditions<K, V> iterator =
        new IteratorWithAdditions<K, V>(this);
    _mIterators[iterator] = false;
    return iterator;
  }

  @override
  bool operator ==(obj) {
    if (obj == this) {
      return true;
    }
    if (!(obj is SafeIterableMap)) {
      return false;
    }
    SafeIterableMap map = obj;
    if (this.length != map.length) {
      return false;
    }
    Iterator<MapEntry<K, V>> iterator1 = iterator;
    Iterator iterator2 = map.iterator;
    while (iterator1.moveNext() && iterator2.moveNext()) {
      MapEntry<K, V> next1 = iterator1.current;
      Object next2 = iterator2.current;
      if ((next1 == null && next2 != null) ||
          (next1 != null && !(next1 == next2))) {
        return false;
      }
    }
    return !iterator1.moveNext() && !iterator2.moveNext();
  }

  @override
  int get hashCode {
    int h = 0;
    Iterator<MapEntry<K, V>> i = iterator;
    while (i.moveNext()) {
      h += i.current.hashCode;
    }
    return h;
  }

  @override
  String toString() {
    var string = "[";
    Iterator<MapEntry<K, V>> it = iterator;
    while (it.moveNext()) {
      string += iterator.current.toString();
      string += ", ";
    }
    string += "]";
    return string;
  }
}

abstract class SupportRemove<K, V> {
  void supportRemove(MapEntry<K, V> entry);
}

class Entry<K, V> implements MapEntry<K, V> {
  final K _mKey;
  final V _mValue;
  Entry<K, V> mNext;
  Entry<K, V> mPrevious;

  Entry(this._mKey, this._mValue);

  @override
  K get key => _mKey;

  @override
  V get value => _mValue;

  @override
  String toString() {
    return _mKey.toString() + "=" + _mValue.toString();
  }

  @override
  bool operator ==(other) {
    if (other == this) {
      return true;
    }
    if (!(other is Entry)) {
      return false;
    }
    Entry entry = other;
    return _mKey == entry._mKey && _mValue == entry._mValue;
  }

  @override
  int get hashCode => _mKey.hashCode ^ _mValue.hashCode;
}

abstract class _ListIterator<K, V>
    implements Iterator<MapEntry<K, V>>, SupportRemove<K, V> {
  Entry<K, V> mExpectedEnd;
  Entry<K, V> mNext;
  Entry<K, V> mCurrent;

  _ListIterator(this.mExpectedEnd, this.mNext);

  bool _hasNext() {
    return mNext != null;
  }

  Entry<K, V> _nextNode() {
    if (mNext == mExpectedEnd || mExpectedEnd == null) {
      return null;
    }
    return forward(mNext);
  }

  MapEntry<K, V> _next() {
    MapEntry<K, V> result = mNext;
    mNext = _nextNode();
    return result;
  }

  @override
  MapEntry<K, V> get current => mCurrent;

  @override
  bool moveNext() {
    if (_hasNext()) {
      mCurrent = _next();
    }
    return false;
  }

  Entry<K, V> forward(Entry<K, V> entry);

  Entry<K, V> backward(Entry<K, V> entry);

  @override
  void supportRemove(MapEntry<K, V> entry) {
    if (mExpectedEnd == entry && entry == mNext) {
      mNext = null;
      mExpectedEnd = null;
    }

    if (mExpectedEnd == entry) {
      mExpectedEnd = backward(mExpectedEnd);
    }

    if (mNext == entry) {
      mNext = _nextNode();
    }
  }
}

class _AscendingIterator<K, V> extends _ListIterator<K, V> {
  _AscendingIterator(Entry<K, V> mExpectedEnd, Entry<K, V> mNext)
      : super(mExpectedEnd, mNext);

  @override
  Entry<K, V> backward(Entry<K, V> entry) {
    return entry.mNext;
  }

  @override
  Entry<K, V> forward(Entry<K, V> entry) {
    return entry.mPrevious;
  }
}

class _DescendingIterator<K, V> extends _ListIterator<K, V> {
  _DescendingIterator(Entry<K, V> mExpectedEnd, Entry<K, V> mNext)
      : super(mExpectedEnd, mNext);

  @override
  Entry<K, V> backward(Entry<K, V> entry) {
    return entry.mPrevious;
  }

  @override
  Entry<K, V> forward(Entry<K, V> entry) {
    return entry.mNext;
  }
}

class IteratorWithAdditions<K, V>
    implements Iterator<MapEntry<K, V>>, SupportRemove<K, V> {
  final SafeIterableMap<K, V> _map;

  IteratorWithAdditions(this._map);

  Entry<K, V> _mCurrent;
  bool _mBeforeStart = true;

  bool _hasNext() {
    if (_mBeforeStart) {
      return _map._mStart != null;
    }
    return _mCurrent != null && _mCurrent.mNext != null;
  }

  MapEntry<K, V> _next() {
    if (_mBeforeStart) {
      _mBeforeStart = false;
      _mCurrent = _map._mStart;
    } else {
      _mCurrent = _mCurrent != null ? _mCurrent.mNext : null;
    }
    return _mCurrent;
  }

  @override
  MapEntry<K, V> get current => _mCurrent;

  @override
  bool moveNext() {
    if (_hasNext()) {
      _next();
    }
    return false;
  }

  @override
  void supportRemove(MapEntry<K, V> entry) {
    if (entry == _mCurrent) {
      _mCurrent = _mCurrent.mPrevious;
      _mBeforeStart = _mCurrent == null;
    }
  }
}

class FastSafeIterableMap<K, V> extends SafeIterableMap<K, V> {
  HashMap<K, Entry<K, V>> _mHashMap = new HashMap<K, Entry<K, V>>();

  @override
  Entry<K, V> get(K k) {
    return _mHashMap[k];
  }

  @override
  V putIfAbsent(K key, V v) {
    Entry<K, V> current = get(key);
    if (current != null) {
      return current._mValue;
    }
    _mHashMap[key] = put(key, v);
    return null;
  }

  @override
  V remove(K key) {
    V removed = super.remove(key);
    _mHashMap.remove(key);
    return removed;
  }

  /// Returns {@code true} if this map contains a mapping for the specified
  /// key.
  bool containsValue(K key) {
    return _mHashMap.containsValue(key);
  }

  /// Return an entry added to prior to an entry associated with the given key.
  ///
  /// @param k the key
  MapEntry<K, V> ceil(K k) {
    if (containsValue(k)) {
      return _mHashMap[k].mPrevious;
    }
    return null;
  }
}
