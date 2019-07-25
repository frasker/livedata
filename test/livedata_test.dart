import 'package:flutter_test/flutter_test.dart';

import 'package:livedata/livedata.dart';
import 'package:livedata/transformations.dart';

abstract class TestIn<T> {
  onChange(T t);
}

testFun<T>(TestIn<T> f, T t) {
  f.onChange(t);
}

void main() {
  test('adds one to input values', () {
    MutableLiveData<int> count = MutableLiveData<int>();

    List<int> tst = List();
    tst.add(1);
    tst.add(1);
    tst.add(1);
    tst.add(1);
    tst.forEach((x) {
      print("=========   $x");
    });

    count.observeForever((x) {
      print("hahhahahha   $x");
    });

    count.value = 4;
    count.value = 5;
    count.value = 6;
    count.value = 7;


    SafeIterableMap<int,String> map = new SafeIterableMap<int,String>();

    Iterator<MapEntry<int, String>> descendingIterator = map.descendingIterator();

    print("hhhhh " + descendingIterator.toString());


    MutableLiveData<int> num = MutableLiveData();

    MutableLiveData<String> convert= Transformations.map(num, (num){
      return "变成字符串 $num";
    });

    num.value = 8;

    convert.observeForever((str){
      print("----------------   $str");
    });

  });
}
