import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);
  runApp(const MerchantApp());
}

class MerchantApp extends StatelessWidget {
  const MerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merchant Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: LoginPage(),
    );
  }
}

final String baseUrl = 'http://localhost:8000';

// --- HELPERS ---
String formatIDR(dynamic n) =>
    NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
        .format(n);
String formatDate(String d) =>
    DateFormat('dd MMM yyyy, HH:mm', 'id').format(DateTime.parse(d));
String getMY(String d) =>
    DateFormat('MMMM yyyy', 'id').format(DateTime.parse(d));

// --- 1. LOGIN & REGISTER ---
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final u = TextEditingController(), p = TextEditingController();
  void _login() async {
    try {
      final r = await http.post(Uri.parse('$baseUrl/login'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"username": u.text, "password": p.text}));
      if (r.statusCode == 200)
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (c) => MainNavigation()));
      else
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Login Gagal!")));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(32),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.store_mall_directory_rounded,
                  size: 80, color: Colors.indigo),
              const Text("Merchant Pro",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                  controller: u,
                  decoration: const InputDecoration(
                      labelText: "Username", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(
                  controller: p,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: "Password", border: OutlineInputBorder())),
              const SizedBox(height: 32),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                      onPressed: _login, child: const Text("MASUK"))),
              TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (c) => RegisterPage())),
                  child: const Text("Daftar Akun Baru"))
            ])),
      );
}

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final u = TextEditingController(),
      p = TextEditingController(),
      s = TextEditingController();
  void _register() async {
    final r = await http.post(Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(
            {"username": u.text, "password": p.text, "store_name": s.text}));
    if (r.statusCode == 200) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Daftar Akun")),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              TextField(
                  controller: s,
                  decoration: const InputDecoration(
                      labelText: "Nama Toko", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(
                  controller: u,
                  decoration: const InputDecoration(
                      labelText: "Username", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(
                  controller: p,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: "Password", border: OutlineInputBorder())),
              const SizedBox(height: 32),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                      onPressed: _register, child: const Text("DAFTAR")))
            ])),
      );
}

// --- 2. MAIN NAVIGATION ---
class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _idx = 0;
  final List<Widget> _pages = [
    DashboardPage(),
    MonthlyReportPage(),
    TopProductsPage(),
    ProductPage(),
    ProfilePage()
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _pages[_idx],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart), label: 'Laporan'),
            NavigationDestination(icon: Icon(Icons.star), label: 'Terlaris'),
            NavigationDestination(
                icon: Icon(Icons.inventory_2), label: 'Produk'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      );
}

// --- 3. DASHBOARD ---
class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, List> groups = {};
  double total = 0;
  String store = "Memuat...";

  void fetch() async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/transactions'));
      final p = await http.get(Uri.parse('$baseUrl/profile'));
      if (r.statusCode == 200) {
        List data = json.decode(r.body);
        Map<String, List> newGroups = {};
        for (var x in data) {
          String k = getMY(x['date']);
          newGroups[k] = (newGroups[k] ?? [])..add(x);
        }
        setState(() {
          groups = newGroups;
          total = data.fold(0.0, (s, i) => s + (i['amount'] ?? 0));
          store = json.decode(p.body)['store_name'];
        });
      }
    } catch (e) {}
  }

  @override
  void initState() {
    super.initState();
    fetch();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(store),
          actions: [
            IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (c) => LoginPage())))
          ],
        ),
        body: Column(children: [
          _summaryCard(),
          Expanded(
              child: RefreshIndicator(
                  onRefresh: () async => fetch(),
                  child: ListView.builder(
                      itemCount: groups.keys.length,
                      itemBuilder: (c, i) {
                        String m = groups.keys.elementAt(i);
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(m,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo))),
                              ...groups[m]!.map((t) => Card(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    child: ListTile(
                                      title: Text(t['item_name']),
                                      subtitle: Text(formatDate(t['date'])),
                                      trailing: Text(formatIDR(t['amount']),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      onTap: () => _editDate(t),
                                      onLongPress: () =>
                                          _confirmDelete(t['id']),
                                    ),
                                  ))
                            ]);
                      }))),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (c) => CartPage(storeName: store)))
              .then((_) => fetch()),
          label: const Text("Kasir"),
          icon: const Icon(Icons.add_shopping_cart),
        ),
      );

  Widget _summaryCard() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [Colors.indigo, Colors.indigo.shade800]),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Total Pendapatan",
              style: TextStyle(color: Colors.white70)),
          Text(formatIDR(total),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
        ]),
      );

  void _editDate(Map t) async {
    DateTime? p = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(t['date']),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (p != null) {
      DateTime old = DateTime.parse(t['date']);
      DateTime updated = DateTime(p.year, p.month, p.day, old.hour, old.minute);
      await http.put(Uri.parse('$baseUrl/transactions/${t['id']}'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({...t, "date": updated.toIso8601String()}));
      fetch();
    }
  }

  void _confirmDelete(int id) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Hapus Transaksi?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Batal")),
                FilledButton(
                    onPressed: () async {
                      await http.delete(Uri.parse('$baseUrl/transactions/$id'));
                      Navigator.pop(ctx);
                      fetch();
                    },
                    child: const Text("Hapus")),
              ],
            ));
  }
}

// --- 4. KASIR ---
class CartPage extends StatefulWidget {
  final String storeName;
  CartPage({required this.storeName});
  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List products = [], cart = [];
  @override
  void initState() {
    super.initState();
    http
        .get(Uri.parse('$baseUrl/products'))
        .then((r) => setState(() => products = json.decode(r.body)));
  }

  void _printStruk(double total) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) => pw.Column(children: [
              pw.Text(widget.storeName,
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(DateFormat('dd/MM/yy HH:mm').format(DateTime.now())),
              pw.Divider(),
              ...cart.map((i) => pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("${i['name']} x${i['qty']}"),
                        pw.Text(formatIDR(i['price'] * i['qty'])),
                      ])),
              pw.Divider(),
              pw.Text("TOTAL: ${formatIDR(total)}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ])));
    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    double total = cart.fold(0.0, (s, i) => s + (i['price'] * i['qty']));
    return Scaffold(
      appBar: AppBar(title: const Text("Kasir")),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<Map>(
              decoration: const InputDecoration(
                  labelText: "Tambah Barang", border: OutlineInputBorder()),
              items: products
                  .map((p) =>
                      DropdownMenuItem<Map>(value: p, child: Text(p['name'])))
                  .toList(),
              onChanged: (v) => setState(() {
                    int idx = cart.indexWhere((i) => i['id'] == v!['id']);
                    if (idx != -1)
                      cart[idx]['qty']++;
                    else
                      cart.add({...v!, 'qty': 1});
                  })),
        ),
        Expanded(
            child: ListView.builder(
                itemCount: cart.length,
                itemBuilder: (c, i) => ListTile(
                      title: Text(cart[i]['name']),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setState(() => cart[i]['qty'] > 1
                                ? cart[i]['qty']--
                                : cart.removeAt(i))),
                        Text("${cart[i]['qty']}"),
                        IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => cart[i]['qty']++)),
                      ]),
                    ))),
        Padding(
            padding: const EdgeInsets.all(20),
            child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
                onPressed: cart.isEmpty
                    ? null
                    : () async {
                        String names = cart
                            .map((e) => "${e['name']} (x${e['qty']})")
                            .join(', ');
                        await http.post(Uri.parse('$baseUrl/transactions'),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode({
                              "item_name": names,
                              "amount": total,
                              "date": DateTime.now().toIso8601String()
                            }));
                        _printStruk(total);
                        Navigator.pop(context);
                      },
                child: Text("BAYAR ${formatIDR(total)}")))
      ]),
    );
  }
}

// --- 5. PRODUK TERLARIS ---
class TopProductsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Produk Terlaris")),
        body: FutureBuilder<List>(
            future: http
                .get(Uri.parse('$baseUrl/top-products'))
                .then((r) => json.decode(r.body)),
            builder: (c, s) => s.hasData
                ? ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: s.data!.length,
                    itemBuilder: (c, i) => Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text("${i + 1}")),
                        title: Text(s.data![i]['name'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text("${s.data![i]['count']} Terjual",
                            style: const TextStyle(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator())),
      );
}

// --- 6. MASTER PRODUK ---
class ProductPage extends StatefulWidget {
  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List p = [];
  final n = TextEditingController(), pr = TextEditingController();
  void _get() => http
      .get(Uri.parse('$baseUrl/products'))
      .then((r) => setState(() => p = json.decode(r.body)));
  @override
  void initState() {
    super.initState();
    _get();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Master Produk")),
        body: ListView.builder(
            itemCount: p.length,
            itemBuilder: (c, i) => ListTile(
                  title: Text(p[i]['name']),
                  subtitle: Text(formatIDR(p[i]['price'])),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await http.delete(
                            Uri.parse('$baseUrl/products/${p[i]['id']}'));
                        _get();
                      }),
                )),
        floatingActionButton: FloatingActionButton(
            onPressed: () => _showAdd(), child: const Icon(Icons.add)),
      );
  void _showAdd() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Tambah Produk"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: n,
                    decoration: const InputDecoration(labelText: "Nama")),
                TextField(
                    controller: pr,
                    decoration: const InputDecoration(labelText: "Harga"),
                    keyboardType: TextInputType.number)
              ]),
              actions: [
                FilledButton(
                    onPressed: () async {
                      await http.post(Uri.parse('$baseUrl/products'),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({
                            "name": n.text,
                            "price": double.parse(pr.text)
                          }));
                      Navigator.pop(ctx);
                      _get();
                    },
                    child: const Text("Simpan"))
              ],
            ));
  }
}

// --- 7. LAPORAN & PROFIL ---
class MonthlyReportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Laporan")),
        body: FutureBuilder<List>(
            future: http
                .get(Uri.parse('$baseUrl/monthly-report'))
                .then((r) => json.decode(r.body)),
            builder: (c, s) => s.hasData
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Text("Statistik Pendapatan Bulanan",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 32),
                      Expanded(
                          child: BarChart(BarChartData(
                              barGroups: s.data!
                                  .asMap()
                                  .entries
                                  .map((e) =>
                                      BarChartGroupData(x: e.key, barRods: [
                                        BarChartRodData(
                                            toY: e.value['total'].toDouble(),
                                            color: const Color.fromARGB(255, 63, 181, 177),
                                            width: 20)
                                      ]))
                                  .toList()))),
                    ]))
                : const Center(child: CircularProgressIndicator())),
      );
}

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final n = TextEditingController(), a = TextEditingController();
  @override
  void initState() {
    super.initState();
    http.get(Uri.parse('$baseUrl/profile')).then((r) {
      var d = json.decode(r.body);
      n.text = d['store_name'];
      a.text = d['address'];
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Profil Toko")),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              TextField(
                  controller: n,
                  decoration: const InputDecoration(
                      labelText: "Nama Toko", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(
                  controller: a,
                  decoration: const InputDecoration(
                      labelText: "Alamat Toko", border: OutlineInputBorder())),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                      onPressed: () async {
                        await http.post(Uri.parse('$baseUrl/profile'),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode(
                                {"store_name": n.text, "address": a.text}));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Profil Disimpan")));
                      },
                      child: const Text("Simpan Perubahan")))
            ])),
      );
}
