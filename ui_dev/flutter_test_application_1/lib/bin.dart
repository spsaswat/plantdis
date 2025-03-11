// ! SCRAPED VERSIONS

// Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           //
//           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
//           // action in the IDE, or press "p" in the console), to see the
//           // wireframe for each widget.
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text('You have pushed the button this many times:'),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         )




// Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             Container(
//               // height: double.infinity,
//               // width: double.infinity,
//               height: 100.0,
//               width: 100.0,
//               // padding: EdgeInsets.all(50.0),
//               // margin: EdgeInsets.all(50.0),
//               decoration: BoxDecoration(
//                 color: Colors.red,
//                 borderRadius: BorderRadius.circular(25.0),
//               ),
//               child: Center(
//                 child: Text("Box1", style: TextStyle(color: Colors.black)),
//               ),
//             ),

//             Container(
//               // height: double.infinity,
//               // width: double.infinity,\
//               height: 100.0,
//               width: 100.0,
//               // padding: EdgeInsets.all(50.0),
//               // margin: EdgeInsets.all(50.0),
//               decoration: BoxDecoration(
//                 color: Colors.lightGreenAccent,
//                 borderRadius: BorderRadius.circular(25.0),
//               ),
//               child: Center(
//                 child: Text("Box2", style: TextStyle(color: Colors.black)),
//               ),
//             ),
//           ],
//         ),
//       )



// Container(
//         padding: EdgeInsets.all(10.0),
//         child: Stack(
//           children: [
//             // Image.asset(
//             //   "assets/images/background.jpg",
//             //   // height: double.infinity,
//             //   fit: BoxFit.fill,
//             // ),
//             SizedBox(
//               height: 350,
//               child: Center(child: Text("Text over Image")),
//             ),
//             ListTile(
//               leading: Icon(Icons.join_full),
//               tileColor: Colors.pink,
//               title: Text("Title Text"),
//               trailing: Text("Trailing Text"),
//               onTap: () => print("clicked on list tile!"),
//             ),
//           ],
//         ),
//       )





// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // TRY THIS: Try running your application with "flutter run". You'll see
//         // the application has a purple toolbar. Then, without quitting the app,
//         // try changing the seedColor in the colorScheme below to Colors.green
//         // and then invoke "hot reload" (save your changes or press the "hot
//         // reload" button in a Flutter-supported IDE, or press "r" if you used
//         // the command line to start the app).
//         //
//         // Notice that the counter didn't reset back to zero; the application
//         // state is not lost during the reload. To reset the state, use hot
//         // restart instead.
//         //
//         // This works for code too, not just values: Most code changes can be
//         // tested with just a hot reload.
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.green,
//           brightness: Brightness.dark,
//         ),
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.

//   // This class is the configuration for the state. It holds the values (in this
//   // case the title) provided by the parent (in this case the App widget) and
//   // used by the build method of the State. Fields in a Widget subclass are
//   // always marked "final".

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // TRY THIS: Try changing the color here to a specific color (to
//         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
//         // change color while the other colors stay the same.
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: Text(widget.title),
//         // leading: Icon(Icons.notification_add, color: Colors.cyanAccent),
//       ),
//       body: ,

//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }




// home: Scaffold(
//   appBar: AppBar(
//     title: Text("First App from Scratch"),
//     centerTitle: true,
//     leading: Icon(Icons.arrow_back_ios_new_rounded),
//     actions: [
//       InkWell(
//         child: Wrap(
//           children: [Text("Logout"), Icon(Icons.exit_to_app_rounded)],
//         ),
//         onTap: () => debugPrint("User says: \"LET ME OUTTTTT!!!!!\""),
//       ),
//     ],
//     backgroundColor: Colors.teal,




// ! Entire REDO


// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.teal,
//           brightness: Brightness.dark,
//         ),
//       ),
//       home: MyHomePage(),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key});

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int currentIndex = 0;

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         appBar: AppBar(
//           title: Text("First App from Scratch"),
//           centerTitle: true,
//         ),
//         drawer: Drawer(
//           child: Column(
//             children: [
//               ListTile(
//                 leading: Icon(Icons.logout_outlined),
//                 title: Text("Logout"),
//               ),
//             ],
//           ),
//         ),
//         body:
//             currentIndex == 0
//                 ? Center(child: Text("HomePage"))
//                 : Center(child: Text("Other Page")),
//         floatingActionButton: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             FloatingActionButton(
//               onPressed: () {},
//               child: Icon(Icons.add_a_photo_outlined),
//             ),
//             SizedBox(height: 10.0),
//             FloatingActionButton(
//               onPressed: () {},
//               child: Icon(Icons.add_card_rounded),
//             ),
//           ],
//         ),
//         bottomNavigationBar: NavigationBar(
//           destinations: [
//             NavigationDestination(
//               icon: Icon(Icons.home_rounded),
//               label: "Home",
//             ),
//             NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
//             NavigationDestination(
//               icon: Icon(Icons.menu_rounded),
//               label: "Settings",
//             ),
//           ],
//           onDestinationSelected:
//               (value) => {
//                 setState(() {
//                   currentIndex = value;
//                 }),
//               },
//           selectedIndex: currentIndex,
//         ),
//       ),
//     );
//   }
// }