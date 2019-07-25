# livedata

LiveData 是参考Android LiveData 实现的可被观察的生命周期感知的可观察数据，是对Flutter原生ValueNotifier等的扩展。

## 如何使用

LiveData与Android使用方式一致，针对flutter提供了LifeCycleState来替代默认的State，以便观察生命周期。
```
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends LifeCycleState<MyHomePage> {
 MutableLiveData<int> count = MutableLiveData<int>();
  _MyHomePageState(){
    count.observe(this,(x){
      print("====================$x");
    });
  }
  int _counter = 0;
  void _incrementCounter() {
    setState(() {
     count.value = _counter;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Text("数字  $_counter"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

```
## 如何依赖
暂时请依赖github
```
 livedata:
    git: https://github.com/frasker/livedata
