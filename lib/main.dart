import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Háttér üzenet: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

runApp(const MyApp());
}

// ---------------- APP ----------------

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool login = false;

  @override
  void initState() {
    super.initState();
    check();
  }

  void check() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      login = prefs.getBool("login") ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: login ? const FoMenu() : const LoginOldal(),
    );
  }
}

// ---------------- DESIGN ----------------

class CircuitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.2)
      ..strokeWidth = 2;

    canvas.drawLine(
        const Offset(50, 100), Offset(size.width - 50, 100), paint);
    canvas.drawCircle(const Offset(50, 100), 5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CircuitBackground extends StatelessWidget {
  final Widget child;
  const CircuitBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF001a00),
                Color(0xFF003300),
                Color(0xFF001a00),
              ],
            ),
          ),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: CircuitPainter(),
        ),
        child,
      ],
    );
  }
}

// ---------------- LOGIN ----------------

class LoginOldal extends StatefulWidget {
  const LoginOldal({super.key});

  @override
  State<LoginOldal> createState() => _LoginOldalState();
}

class _LoginOldalState extends State<LoginOldal> {
  final TextEditingController user = TextEditingController();
  final TextEditingController pass = TextEditingController();

  // 🔐 LOGIN
  void login() async {
    var result = await FirebaseFirestore.instance
        .collection("users")
        .where("user", isEqualTo: user.text)
        .where("pass", isEqualTo: pass.text)
        .get();

    if (result.docs.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();

      final token = await FirebaseMessaging.instance.getToken();
      final userDoc = result.docs.first;

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userDoc.id)
          .update({
        "online": true,
        "token": token,
      });

      await prefs.setBool("login", true);
      await prefs.setString("user", user.text);
      await prefs.setBool("admin", user.text == "gabor2001");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FoMenu()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hibás adatok ❌")),
      );
    }
  }

  // 📝 REGISZTRÁCIÓ (DUPLIKÁLT VÉDELEM!)
  void regisztral() async {
    if (user.text.isEmpty || pass.text.isEmpty) return;

    // 🔍 létezik-e már?
    var exists = await FirebaseFirestore.instance
        .collection("users")
        .where("user", isEqualTo: user.text)
        .get();

    if (exists.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ez a név már foglalt ❌")),
      );
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();

    await FirebaseFirestore.instance.collection("users").add({
      "user": user.text,
      "pass": pass.text,
      "token": token,
      "online": false,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Regisztráció kész 😄")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // háttér
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF001a00),
                  Color(0xFF003300),
                  Color(0xFF001a00),
                ],
              ),
            ),
          ),

          CustomPaint(
            size: Size.infinite,
            painter: CircuitPainter(),
          ),

          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory,
                      size: 60, color: Colors.greenAccent),

                  const SizedBox(height: 20),

                  TextField(
                    controller: user,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(
                      hintText: "Felhasználónév",
                      hintStyle:
                          TextStyle(color: Colors.greenAccent),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: pass,
                    obscureText: true,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(
                      hintText: "Jelszó",
                      hintStyle:
                          TextStyle(color: Colors.greenAccent),
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: login,
                    child: const Text("Belépés"),
                  ),

                  ElevatedButton(
                    onPressed: regisztral,
                    child: const Text("Regisztráció"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- FŐMENÜ ----------------

class FoMenu extends StatefulWidget {
  const FoMenu({super.key});

  @override
  State<FoMenu> createState() => _FoMenuState();
}

class _FoMenuState extends State<FoMenu> {
  int index = 0;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  void checkAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isAdmin = prefs.getBool("admin") ?? false;
    });
  }

  void logout() async {
  final prefs = await SharedPreferences.getInstance();
  final user = prefs.getString("user");

  // 🔥 OFFLINE
  var query = await FirebaseFirestore.instance
      .collection("users")
      .where("user", isEqualTo: user)
      .get();

  if (query.docs.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(query.docs.first.id)
        .update({"online": false});
  }

  await prefs.setBool("login", false);

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const LoginOldal()),
  );
}
  @override
  Widget build(BuildContext context) {
    final oldalak = [
      const NaptarOldal(),
      const JegyekOldal(),
      const JegyzetekOldal(),
      const UserListaOldal(),
      const KapottEsemenyekOldal(),
      if (isAdmin) const AdminOldal(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,

      // 🔥 APPBAR KISZEDVE

      body: Stack(
        children: [
          oldalak[index],

          // 🔥 LOGOUT GOMB (JOBB FELSŐ SAROK)
          Positioned(
            top: 40,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.4),
                    blurRadius: 10,
                  )
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.greenAccent),
                onPressed: logout,
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          border: const Border(
            top: BorderSide(color: Colors.greenAccent, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.3),
              blurRadius: 10,
            )
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.greenAccent,
          unselectedItemColor: Colors.grey,
          currentIndex: index,
          onTap: (i) {
            setState(() {
              index = i;
            });
          },
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month), label: "Naptár"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.school), label: "Jegyek"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.note), label: "Jegyzetek"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.chat), label: "Chat"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.share), label: "Események"),
            if (isAdmin)
              const BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings),
                  label: "Admin"),
          ],
        ),
      ),
    );
  }
}

// ---------------- NAPTÁR (FIXED) ----------------

class NaptarOldal extends StatefulWidget {
  const NaptarOldal({super.key});

  @override
  State<NaptarOldal> createState() => _NaptarOldalState();
}

class _NaptarOldalState extends State<NaptarOldal> {
  Map<DateTime, List<String>> events = {};
  DateTime selected = DateTime.now();

  List<String> getEvents(DateTime day) {
    return events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void addEvent(DateTime day, String event) {
    final key = DateTime(day.year, day.month, day.day);
    setState(() {
      events.putIfAbsent(key, () => []);
      events[key]!.add(event);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 🔥 CÍM
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  "Naptár",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              // 🔥 CYBER CHIP DOBOZ A NAPTÁR KÖRÜL
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),

                  // 🔥 "chip keret"
                  border: Border.all(color: Colors.greenAccent),

                  // glow
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),

                child: TableCalendar(
                  firstDay: DateTime(2024),
                  lastDay: DateTime(2030),
                  focusedDay: selected,

                  selectedDayPredicate: (d) =>
                      isSameDay(d, selected),

                  eventLoader: (day) => getEvents(day),

                  onDaySelected: (d, f) {
                    setState(() => selected = d);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NapReszletek(
                          datum: d,
                          lista: getEvents(d),
                          onAdd: (uj) => addEvent(d, uj),
                        ),
                      ),
                    );
                  },

                  // 🔥 CYBER STYLE
                  calendarStyle: const CalendarStyle(
                    defaultTextStyle:
                        TextStyle(color: Colors.greenAccent),
                    weekendTextStyle:
                        TextStyle(color: Colors.redAccent),

                    todayDecoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),

                    selectedDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),

                    markerDecoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),

                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,

                    // 🔥 CHIP BUTTON
                    formatButtonDecoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.greenAccent),
                    ),

                    formatButtonTextStyle: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),

                    titleTextStyle: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),

                    leftChevronIcon: const Icon(
                        Icons.chevron_left,
                        color: Colors.greenAccent),
                    rightChevronIcon: const Icon(
                        Icons.chevron_right,
                        color: Colors.greenAccent),
                  ),

                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle:
                        TextStyle(color: Colors.greenAccent),
                    weekendStyle:
                        TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),

              // 🔥 ESEMÉNYEK
              Expanded(
                child: getEvents(selected).isEmpty
                    ? const Center(
                        child: Text(
                          "Nincs esemény 😄",
                          style: TextStyle(
                              color: Colors.greenAccent),
                        ),
                      )
                    : ListView(
                        children: getEvents(selected)
                            .map<Widget>((e) {
                          return Card(
                            color:
                                Colors.black.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(15),
                              side: const BorderSide(
                                  color: Colors.greenAccent),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.event,
                                color: Colors.greenAccent,
                              ),
                              title: Text(
                                e,
                                style: const TextStyle(
                                    color:
                                        Colors.greenAccent),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- JEGYEK ----------------

class JegyekOldal extends StatefulWidget {
  const JegyekOldal({super.key});

  @override
  State<JegyekOldal> createState() => _JegyekOldalState();
}

class _JegyekOldalState extends State<JegyekOldal> {
  Map<String, dynamic> tantargyak = {};
  int maxKredit = 30; // 🔥 ÚJ

  @override
  void initState() {
    super.initState();
    betoltes();
  }

  // 🔽 BETÖLTÉS
  void betoltes() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString("user");

    final data = prefs.getString("tantargyak_$user");

    setState(() {
      tantargyak = data != null ? jsonDecode(data) : {};
      maxKredit = prefs.getInt("maxKredit_$user") ?? 30;
    });
  }

  // 🔽 MENTÉS
  void mentes() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString("user");

    prefs.setString("tantargyak_$user", jsonEncode(tantargyak));
  }

  // 🔽 MAX KREDIT MENTÉS
  void mentesMaxKredit() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString("user");

    prefs.setInt("maxKredit_$user", maxKredit);
  }

  // 🔥 ÖSSZES KREDIT
  int osszKredit() {
    int sum = 0;
    for (var t in tantargyak.values) {
      sum += (t["kreditek"] ?? 0) as int;
    }
    return sum;
  }

  // 🔥 ÁTLAG
  double felevesAtlag() {
    double ossz = 0;
    int kreditSum = 0;

    for (var t in tantargyak.values) {
      List<int> jegyek = List<int>.from(t["jegyek"] ?? []);
      int kredit = t["kreditek"] ?? 0;

      if (jegyek.isNotEmpty) {
        double atlag =
            jegyek.reduce((a, b) => a + b) / jegyek.length;

        ossz += atlag * kredit;
        kreditSum += kredit;
      }
    }

    if (kreditSum == 0) return 0;
    return ossz / kreditSum;
  }

  // ➕ ÚJ TÁRGY
  void ujTantargy() {
    TextEditingController nev = TextEditingController();
    TextEditingController kredit = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Új tárgy",
            style: TextStyle(color: Colors.greenAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nev,
              style: const TextStyle(color: Colors.greenAccent),
              decoration:
                  const InputDecoration(hintText: "Név"),
            ),
            TextField(
              controller: kredit,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.greenAccent),
              decoration:
                  const InputDecoration(hintText: "Kredit"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (nev.text.isEmpty ||
                  kredit.text.isEmpty) return;

              setState(() {
                tantargyak[nev.text] = {
                  "jegyek": [],
                  "kreditek": int.parse(kredit.text)
                };
              });

              mentes();
              Navigator.pop(context);
            },
            child: const Text("Mentés",
                style: TextStyle(color: Colors.greenAccent)),
          )
        ],
      ),
    );
  }

  // ❌ TÖRLÉS
  void torles(String nev) {
    setState(() {
      tantargyak.remove(nev);
    });
    mentes();
  }

  // 🔥 MAX KREDIT BEÁLLÍTÁS
  void allitMaxKredit() {
    TextEditingController c = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "Max kredit beállítása",
          style: TextStyle(color: Colors.greenAccent),
        ),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.greenAccent),
          decoration: const InputDecoration(
            hintText: "Pl: 60",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (c.text.isEmpty) return;

              setState(() {
                maxKredit = int.parse(c.text);
              });

              mentesMaxKredit();

              Navigator.pop(context);
            },
            child: const Text(
              "Mentés",
              style: TextStyle(color: Colors.greenAccent),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 🔥 DASHBOARD
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                        color: Colors.greenAccent,
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent
                            .withOpacity(0.3),
                        blurRadius: 25,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.school,
                          color: Colors.greenAccent,
                          size: 35),
                      const SizedBox(height: 10),

                      Text(
                        "Összes kredit: ${osszKredit()}",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "Féléves átlag: ${felevesAtlag().toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // 🔥 DINAMIKUS PROGRESS
                      LinearProgressIndicator(
                        value: maxKredit == 0
                            ? 0
                            : osszKredit() / maxKredit,
                        backgroundColor: Colors.black,
                        valueColor:
                            const AlwaysStoppedAnimation(
                                Colors.greenAccent),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "${osszKredit()} / $maxKredit kredit",
                        style: const TextStyle(
                            color: Colors.white54),
                      ),

                      const SizedBox(height: 10),

                      // 🔥 BEÁLLÍTÓ GOMB
                      ElevatedButton(
                        onPressed: allitMaxKredit,
                        child: const Text("Cél kredit beállítása"),
                      ),
                    ],
                  ),
                ),
              ),

              // 🔥 LISTA
              Expanded(
                child: tantargyak.isEmpty
                    ? const Center(
                        child: Text(
                          "Nincs még tárgy 😄",
                          style: TextStyle(
                              color: Colors.greenAccent),
                        ),
                      )
                    : ListView(
                        children:
                            tantargyak.keys.map((nev) {
                          var adat = tantargyak[nev];

                          List<int> jegyek =
                              List<int>.from(
                                  adat["jegyek"] ?? []);

                          double atlag = jegyek.isEmpty
                              ? 0
                              : jegyek.reduce(
                                      (a, b) => a + b) /
                                  jegyek.length;

                          return Card(
                            color: Colors.black
                                .withOpacity(0.7),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(20),
                              side: const BorderSide(
                                  color:
                                      Colors.greenAccent),
                            ),
                            child: ListTile(
                              title: Text(
                                "$nev (${adat["kreditek"]} kredit)",
                                style: const TextStyle(
                                  color:
                                      Colors.greenAccent,
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Átlag: ${atlag.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    color: Colors.white70),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red),
                                onPressed: () =>
                                    torles(nev),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.black,
        onPressed: ujTantargy,
        child: const Icon(Icons.add),
      ),
    );
  }
}
// ---------------- JEGYZETEK ----------------

class JegyzetekOldal extends StatefulWidget {
  const JegyzetekOldal({super.key});

  @override
  State<JegyzetekOldal> createState() => _JegyzetekOldalState();
}

class _JegyzetekOldalState extends State<JegyzetekOldal> {
  List<String> jegyzetek = [];

  @override
  void initState() {
    super.initState();
    betoltes();
  }

  void betoltes() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString("user");

    setState(() {
      jegyzetek =
          prefs.getStringList("jegyzetek_$user") ?? [];
    });
  }

  void mentes() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString("user");

    prefs.setStringList("jegyzetek_$user", jegyzetek);
  }

  void ujJegyzet() {
    TextEditingController c = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "Új jegyzet",
          style: TextStyle(color: Colors.greenAccent),
        ),
        content: TextField(
          controller: c,
          style: const TextStyle(color: Colors.greenAccent),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (c.text.isEmpty) return;

              setState(() {
                jegyzetek.add(c.text);
              });

              mentes();
              Navigator.pop(context);
            },
            child: const Text(
              "Mentés",
              style: TextStyle(color: Colors.greenAccent),
            ),
          )
        ],
      ),
    );
  }

  void torles(int i) {
    setState(() {
      jegyzetek.removeAt(i);
    });
    mentes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 🔝 CÍM
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  "Jegyzetek",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 📋 LISTA
              Expanded(
                child: jegyzetek.isEmpty
                    ? const Center(
                        child: Text(
                          "Nincs még jegyzet 😄",
                          style: TextStyle(
                              color: Colors.greenAccent),
                        ),
                      )
                    : ListView.builder(
                        itemCount: jegyzetek.length,
                        itemBuilder: (_, i) => Card(
                          color:
                              Colors.black.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(15),
                            side: const BorderSide(
                                color: Colors.greenAccent),
                          ),
                          child: ListTile(
                            title: Text(
                              jegyzetek[i],
                              style: const TextStyle(
                                  color:
                                      Colors.greenAccent),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () =>
                                  torles(i),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.black,
        onPressed: ujJegyzet,
        child: const Icon(Icons.add),
      ),
    );
  }
}
// ---------------- ADMIN ----------------

class AdminOldal extends StatefulWidget {
  const AdminOldal({super.key});

  @override
  State<AdminOldal> createState() => _AdminOldalState();
}

class _AdminOldalState extends State<AdminOldal> {

  // ❌ USER TÖRLÉS
  void torles(String id) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  "Admin panel 👑",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 👇 USER LISTA FIREBASE-BŐL
              Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    var users = snapshot.data!.docs;

                    if (users.isEmpty) {
                      return const Center(
                        child: Text(
                          "Nincs még felhasználó 😄",
                          style:
                              TextStyle(color: Colors.greenAccent),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (_, i) {
                        var u = users[i].data();

                        return Card(
                          color: Colors.black.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(15),
                            side: const BorderSide(
                                color: Colors.greenAccent),
                          ),
                          child: ListTile(
                            title: Text(
                              u["user"],
                              style: const TextStyle(
                                  color: Colors.greenAccent),
                            ),

                            subtitle: const Text(
                              "Felhasználó",
                              style: TextStyle(
                                  color: Colors.white70),
                            ),

                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () =>
                                  torles(users[i].id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NapReszletek extends StatefulWidget {
  final DateTime datum;
  final List<String> lista;
  final Function(String) onAdd;

  const NapReszletek({
    super.key,
    required this.datum,
    required this.lista,
    required this.onAdd,
  });

  @override
  State<NapReszletek> createState() => _NapReszletekState();
}

class _NapReszletekState extends State<NapReszletek> {
  late List<String> lista;

  @override
  void initState() {
    super.initState();
    lista = List.from(widget.lista);
  }

  // ➕ ÚJ ESEMÉNY
  void ujEsemeny() {
    TextEditingController c = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Új esemény",
            style: TextStyle(color: Colors.greenAccent)),
        content: TextField(
          controller: c,
          style: const TextStyle(color: Colors.greenAccent),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (c.text.isEmpty) return;

              setState(() {
                lista.add(c.text);
              });

              widget.onAdd(c.text);
              Navigator.pop(context);
            },
            child: const Text("Mentés",
                style: TextStyle(color: Colors.greenAccent)),
          )
        ],
      ),
    );
  }

  // 🔥 USER LISTÁS MEGOSZTÁS
  void esemenyKuld(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString("user");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Kinek küldöd?",
            style: TextStyle(color: Colors.greenAccent)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection("users")
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              var users = snapshot.data!.docs;

              return ListView(
                children: users.map((u) {
                  String nev = u["user"];

                  if (nev == user) return Container();

                  return ListTile(
                    title: Text(
                      nev,
                      style: const TextStyle(
                          color: Colors.greenAccent),
                    ),
                    onTap: () async {
                      await FirebaseFirestore.instance
                          .collection("shared_events")
                          .add({
                        "text": text,
                        "from": user,
                        "to": nev,
                        "time": Timestamp.now(),
                      });

                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  "${widget.datum.year}.${widget.datum.month}.${widget.datum.day}",
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Expanded(
                child: lista.isEmpty
                    ? const Center(
                        child: Text(
                          "Nincs esemény 😄",
                          style: TextStyle(
                              color: Colors.greenAccent),
                        ),
                      )
                    : ListView.builder(
                        itemCount: lista.length,
                        itemBuilder: (_, i) => Card(
                          color: Colors.black.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(15),
                            side: const BorderSide(
                                color: Colors.greenAccent),
                          ),
                          child: ListTile(
                            title: Text(
                              lista[i],
                              style: const TextStyle(
                                  color: Colors.greenAccent),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.share,
                                      color: Colors.greenAccent),
                                  onPressed: () {
                                    esemenyKuld(lista[i]);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      lista.removeAt(i);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.black,
        onPressed: ujEsemeny,
        child: const Icon(Icons.add),
      ),
    );
  }
}
class JegyReszletekOldal extends StatefulWidget {
  final String tantargy;
  final Map<String, dynamic> adat;
  final Function(Map<String, dynamic>) onUpdate;

  const JegyReszletekOldal({
    super.key,
    required this.tantargy,
    required this.adat,
    required this.onUpdate,
  });

  @override
  State<JegyReszletekOldal> createState() =>
      _JegyReszletekOldalState();
}

class _JegyReszletekOldalState
    extends State<JegyReszletekOldal> {
  late List jegyek;
  late List sulyok;

  @override
  void initState() {
    super.initState();
    jegyek = List.from(widget.adat["jegyek"]);
    sulyok = List.from(widget.adat["sulyok"]);
  }

  void ujJegy() {
    TextEditingController jegy = TextEditingController();
    TextEditingController suly = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Új jegy",
            style: TextStyle(color: Colors.greenAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: jegy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Jegy"),
            ),
            TextField(
              controller: suly,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Súly"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (jegy.text.isEmpty || suly.text.isEmpty) return;

              setState(() {
                jegyek.add(int.parse(jegy.text));
                sulyok.add(int.parse(suly.text));
              });

              widget.onUpdate({
                "kreditek": widget.adat["kreditek"],
                "jegyek": jegyek,
                "sulyok": sulyok,
              });

              Navigator.pop(context);
            },
            child: const Text("Mentés"),
          )
        ],
      ),
    );
  }

  double atlag() {
    if (jegyek.isEmpty) return 0;

    double ossz = 0;
    double sulySum = 0;

    for (int i = 0; i < jegyek.length; i++) {
      ossz += jegyek[i] * sulyok[i];
      sulySum += sulyok[i];
    }

    return ossz / sulySum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackground(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              "${widget.tantargy} - ${atlag().toStringAsFixed(2)}",
              style: const TextStyle(
                  color: Colors.greenAccent, fontSize: 22),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: jegyek.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(
                    "Jegy: ${jegyek[i]} (súly: ${sulyok[i]})",
                    style:
                        const TextStyle(color: Colors.greenAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ujJegy,
        child: const Icon(Icons.add),
      ),
    );
  }
}
class UserListaOldal extends StatelessWidget {
  const UserListaOldal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 🔝 CÍM
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  "Felhasználók",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 👥 USER LISTA
              Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    var users = snapshot.data!.docs;

                    if (users.isEmpty) {
                      return const Center(
                        child: Text(
                          "Nincs felhasználó 😄",
                          style:
                              TextStyle(color: Colors.greenAccent),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (_, i) {
                        var u = users[i].data();
                        String nev = u["user"];

                        bool online = u["online"] ?? false;

                        return Card(
                          color: Colors.black.withOpacity(0.6),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: const BorderSide(
                                color: Colors.greenAccent),
                          ),
                          child: ListTile(
                            // 🔥 AVATAR + ONLINE DOT
                            leading: Stack(
                              children: [
                                const Icon(Icons.person,
                                    color: Colors.greenAccent, size: 30),

                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: online
                                          ? Colors.green
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.black, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 👤 NÉV
                            title: Text(
                              nev,
                              style: const TextStyle(
                                  color: Colors.greenAccent),
                            ),

                            // ➡️ NYÍL
                            trailing: const Icon(Icons.arrow_forward,
                                color: Colors.greenAccent),

                            // 💬 CHAT
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ChatOldal(otherUser: nev),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class KapottEsemenyekOldal extends StatelessWidget {
  const KapottEsemenyekOldal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  "Kapott események",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("shared_events")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    var docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "Nincs esemény 😄",
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        var d = docs[i];

                        return Card(
                          color: Colors.black.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: const BorderSide(
                                color: Colors.greenAccent),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.event,
                                color: Colors.greenAccent),
                            title: Text(
                              d["text"],
                              style: const TextStyle(
                                  color: Colors.greenAccent),
                            ),
                            subtitle: Text(
                              "Küldte: ${d["from"]}",
                              style: const TextStyle(
                                  color: Colors.white70),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
// ---------------- CHAT ----------------

class ChatOldal extends StatefulWidget {
  final String otherUser;

  const ChatOldal({super.key, required this.otherUser});

  @override
  State<ChatOldal> createState() => _ChatOldalState();
}

class _ChatOldalState extends State<ChatOldal> {
  final TextEditingController controller = TextEditingController();
  String? user;

  @override
  void initState() {
    super.initState();
    getUser();
  }

  void getUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      user = prefs.getString("user");
    });
  }

  // 🔥 ÜZENET KÜLDÉS + TOKEN LEKÉRÉS
  void sendMessage() async {
    if (controller.text.isEmpty || user == null) return;

    // 1️⃣ ÜZENET MENTÉS
    await FirebaseFirestore.instance.collection("messages").add({
      "text": controller.text,
      "from": user,
      "to": widget.otherUser,
      "time": Timestamp.now(),
    });

    // 2️⃣ CÉL USER TOKEN LEKÉRÉS
    var query = await FirebaseFirestore.instance
        .collection("users")
        .where("user", isEqualTo: widget.otherUser)
        .get();

    if (query.docs.isNotEmpty) {
      var token = query.docs.first["token"];

      print("CÉL TOKEN: $token");

      // 🔥 IDE JÖN MAJD A VALÓDI PUSH (Cloud Function)
    }

    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CircuitBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 🔝 CÍM
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  "Chat - ${widget.otherUser}",
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 💬 ÜZENETEK
              Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("messages")
                      .orderBy("time")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    var docs = snapshot.data!.docs.where((d) {
                      var data = d.data();
                      return (data["from"] == user &&
                              data["to"] == widget.otherUser) ||
                          (data["from"] == widget.otherUser &&
                              data["to"] == user);
                    }).toList();

                    return ListView(
                      padding: const EdgeInsets.all(10),
                      children: docs.map((d) {
                        var data = d.data();
                        bool isMe = data["from"] == user;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.greenAccent
                                  : Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(15),
                              border:
                                  Border.all(color: Colors.greenAccent),
                            ),
                            child: Text(
                              data["text"],
                              style: TextStyle(
                                color: isMe
                                    ? Colors.black
                                    : Colors.greenAccent,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

              // ✍️ INPUT
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style:
                            const TextStyle(color: Colors.greenAccent),
                        decoration: const InputDecoration(
                          hintText: "Írj üzenetet...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.greenAccent),
                      onPressed: sendMessage,
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}