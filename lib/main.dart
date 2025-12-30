import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(MaterialApp(
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
    ));

// GANTI LOCALHOST KE IP LAPTOP JIKA PAKAI HP FISIK
final String baseUrl = 'http://localhost:8000';

// --- 1. HALAMAN LOGIN ---
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final user = TextEditingController();
  final pass = TextEditingController();

  Future<void> doLogin() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/login'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"username": user.text, "password": pass.text}));
      if (res.statusCode == 200) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (c) => DashboardPage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal Login: Username/Password Salah")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Server Tidak Terhubung")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(30),
          child: Column(children: [
            Icon(Icons.storefront, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text("E-MERCHANT LOGIN",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 30),
            TextField(
                controller: user,
                decoration: InputDecoration(
                    labelText: "Username", border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(
                controller: pass,
                decoration: InputDecoration(
                    labelText: "Password", border: OutlineInputBorder()),
                obscureText: true),
            SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: doLogin,
                  child: Text("MASUK"),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.all(15))),
            ),
            TextButton(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (c) => RegisterPage())),
                child: Text("Belum punya akun? Daftar"))
          ]),
        ),
      ),
    );
  }
}

// --- 2. HALAMAN REGISTER ---
class RegisterPage extends StatelessWidget {
  final user = TextEditingController();
  final pass = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Daftar Akun")),
      body: Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [
            TextField(
                controller: user,
                decoration: InputDecoration(
                    labelText: "Buat Username", border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(
                controller: pass,
                decoration: InputDecoration(
                    labelText: "Buat Password", border: OutlineInputBorder())),
            SizedBox(height: 20),
            ElevatedButton(
                onPressed: () async {
                  await http.post(Uri.parse('$baseUrl/register'),
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode(
                          {"username": user.text, "password": pass.text}));
                  Navigator.pop(context);
                },
                child: Text("Daftar Sekarang")),
          ])),
    );
  }
}

// --- 3. DASHBOARD UTAMA (DENGAN INPUT BARANG OTOMATIS) ---
class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List transactions = [];
  List products = [];
  double dailyTotal = 0;
  String selectedDate = DateTime.now().toString().split(' ')[0];

  Future<void> refresh() async {
    final res = await http.get(Uri.parse('$baseUrl/transactions'));
    final prodRes = await http.get(Uri.parse('$baseUrl/products'));
    if (res.statusCode == 200 && prodRes.statusCode == 200) {
      setState(() {
        List all = json.decode(res.body);
        transactions = all.where((x) => x['date'] == selectedDate).toList();
        dailyTotal = transactions.fold(0, (s, i) => s + i['amount']);
        products = json.decode(prodRes.body);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void _addTransaction() {
    String? selectedProduct;
    double? price;

    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: Text("Input Penjualan"),
              content: StatefulBuilder(builder: (context, setPopupState) {
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    hint: Text("Pilih Barang"),
                    items: products
                        .map((p) => DropdownMenuItem<String>(
                            value: p['name'],
                            child: Text("${p['name']} (Rp ${p['price']})")))
                        .toList(),
                    onChanged: (v) {
                      setPopupState(() {
                        selectedProduct = v;
                        price =
                            products.firstWhere((p) => p['name'] == v)['price'];
                      });
                    },
                  ),
                  SizedBox(height: 15),
                  Text("Harga: Rp ${price ?? 0}",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]);
              }),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c), child: Text("Batal")),
                ElevatedButton(
                    onPressed: () async {
                      if (selectedProduct != null) {
                        await http.post(Uri.parse('$baseUrl/transactions'),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode({
                              "item_name": selectedProduct,
                              "amount": price,
                              "date": selectedDate
                            }));
                        refresh();
                        Navigator.pop(c);
                      }
                    },
                    child: Text("Simpan")),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Merchant Dashboard"), elevation: 2),
      drawer: Drawer(
        child: ListView(children: [
          DrawerHeader(
              child: Icon(Icons.store, size: 80, color: Colors.blue),
              decoration: BoxDecoration(color: Colors.blue.shade50)),
          ListTile(
              leading: Icon(Icons.home),
              title: Text("Harian"),
              onTap: () => Navigator.pop(context)),
          ListTile(
              leading: Icon(Icons.bar_chart),
              title: Text("Grafik & Rekap Bulanan"),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (c) => MonthlyReportPage()))),
          ListTile(
              leading: Icon(Icons.inventory_2),
              title: Text("Stok Barang Dijual"),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (c) => ProductPage()))),
          ListTile(
              leading: Icon(Icons.person),
              title: Text("Profil Toko"),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (c) => ProfilePage()))),
          Divider(),
          ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text("Logout"),
              onTap: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => LoginPage()),
                  (r) => false)),
        ]),
      ),
      body: Column(children: [
        ListTile(
          tileColor: Colors.blue.shade50,
          title: Text("Data Tanggal: $selectedDate",
              style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Icon(Icons.calendar_today),
          onTap: () async {
            DateTime? p = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100));
            if (p != null) {
              setState(() => selectedDate = p.toString().split(' ')[0]);
              refresh();
            }
          },
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20))),
          child: Column(children: [
            Text("TOTAL PENDAPATAN",
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            Text("Rp $dailyTotal",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(
          child: transactions.isEmpty
              ? Center(child: Text("Tidak ada penjualan hari ini"))
              : ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (c, i) => Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        child: ListTile(
                          title: Text(transactions[i]['item_name'],
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Terjual pd $selectedDate"),
                          trailing: Text("Rp ${transactions[i]['amount']}",
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                          onLongPress: () async {
                            await http.delete(Uri.parse(
                                '$baseUrl/transactions/${transactions[i]['id']}'));
                            refresh();
                          },
                        ),
                      )),
        )
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTransaction,
        label: Text("Input Penjualan"),
        icon: Icon(Icons.add_shopping_cart),
      ),
    );
  }
}

// --- 4. HALAMAN GRAFIK & REKAP BULANAN ---
class MonthlyReportPage extends StatelessWidget {
  Future<List> getReport() async {
    final res = await http.get(Uri.parse('$baseUrl/monthly-report'));
    return json.decode(res.body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Grafik Pendapatan")),
      body: FutureBuilder<List>(
          future: getReport(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return Center(child: CircularProgressIndicator());
            List data = snapshot.data!;

            return Column(children: [
              SizedBox(height: 20),
              Text("Visualisasi Bulanan",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                height: 250,
                padding: EdgeInsets.all(20),
                child: BarChart(BarChartData(
                  barGroups: data
                      .asMap()
                      .entries
                      .map((e) => BarChartGroupData(x: e.key, barRods: [
                            BarChartRodData(
                                toY: e.value['total'],
                                color: Colors.blue,
                                width: 15)
                          ]))
                      .toList(),
                  titlesData: FlTitlesData(
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false))),
                )),
              ),
              Expanded(
                  child: ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (c, i) => ListTile(
                            leading: Icon(Icons.calendar_month),
                            title: Text("Bulan ${data[i]['month']}"),
                            trailing: Text("Rp ${data[i]['total']}",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          )))
            ]);
          }),
    );
  }
}

// --- 5. HALAMAN MANAJEMEN BARANG (PRODUK) ---
class ProductPage extends StatefulWidget {
  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List products = [];
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  Future<void> fetch() async {
    final res = await http.get(Uri.parse('$baseUrl/products'));
    setState(() => products = json.decode(res.body));
  }

  @override
  void initState() {
    super.initState();
    fetch();
  }

  void _showAdd() {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: Text("Tambah Barang"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: "Nama Barang")),
                TextField(
                    controller: priceCtrl,
                    decoration: InputDecoration(
                        labelText: "Harga Jual", prefixText: "Rp "),
                    keyboardType: TextInputType.number),
              ]),
              actions: [
                ElevatedButton(
                    onPressed: () async {
                      await http.post(Uri.parse('$baseUrl/products'),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({
                            "name": nameCtrl.text,
                            "price": double.parse(priceCtrl.text)
                          }));
                      nameCtrl.clear();
                      priceCtrl.clear();
                      Navigator.pop(context);
                      fetch();
                    },
                    child: Text("Simpan"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Daftar Barang Jualan")),
      body: ListView.builder(
          itemCount: products.length,
          itemBuilder: (c, i) => ListTile(
                leading: CircleAvatar(child: Icon(Icons.inventory)),
                title: Text(products[i]['name']),
                subtitle: Text("Harga: Rp ${products[i]['price']}"),
                trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await http.delete(
                          Uri.parse('$baseUrl/products/${products[i]['id']}'));
                      fetch();
                    }),
              )),
      floatingActionButton:
          FloatingActionButton(onPressed: _showAdd, child: Icon(Icons.add)),
    );
  }
}

// --- 6. HALAMAN PROFIL ---
class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final name = TextEditingController();
  final addr = TextEditingController();
  @override
  void initState() {
    super.initState();
    http.get(Uri.parse('$baseUrl/profile')).then((res) {
      var d = json.decode(res.body);
      setState(() {
        name.text = d['store_name'];
        addr.text = d['address'];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profil Toko")),
      body: Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [
            TextField(
                controller: name,
                decoration: InputDecoration(
                    labelText: "Nama Toko", border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(
                controller: addr,
                decoration: InputDecoration(
                    labelText: "Alamat Toko", border: OutlineInputBorder())),
            SizedBox(height: 20),
            ElevatedButton(
                onPressed: () async {
                  await http.post(Uri.parse('$baseUrl/profile'),
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode(
                          {"store_name": name.text, "address": addr.text}));
                  Navigator.pop(context);
                },
                child: Text("Simpan Perubahan")),
          ])),
    );
  }
}
