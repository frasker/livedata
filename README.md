# livedata

LiveData 是参考Android LiveData 实现的可被观察的生命周期感知的可观察数据，是对Flutter原生ValueNotifier等的扩展。

## 如何使用

LiveData与Android使用方式一致，针对flutter提供了LifeCycleState来替代默认的State，以便观察生命周期。
```
class MyApp extends StatelessWidget {
  // This widget is the root of your application.
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

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

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
