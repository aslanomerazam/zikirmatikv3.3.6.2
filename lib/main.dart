import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MaterialApp(
    home: SplashScreen(),
    debugShowCheckedModeBanner: false,
  ));
  
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Zikirmatik();
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
  super.initState();
  Future.delayed(const Duration(seconds: 2), () { // 2 saniye bekleme örneği
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MyApp(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        // Ekran geçişi sırasında bir arka plan rengi belirleyin
        opaque: true, // Bu değer, alttaki ekranın geçiş sırasında görünmesini engeller
        // Buradaki renk, geçiş anındaki arka plan rengidir
        barrierColor: Colors.black,
      ),
    );
  });
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
              image: AssetImage('assets/zikirmatik_osmanli1_market.png'),
              width: 300,
              height: 300,
            ),
            SizedBox(height: 20),
            Text(
              'ZİKİRMATİK',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ZikirmatikItem sınıfına renk özellikleri eklendi
class ZikirmatikItem {
  final String id;
  final String name;
  final int cost;
  final String imagePath;
  final String? lightImagePath;
  final String? marketImagePath;
  final String? marketLightImagePath;
  final bool isDefault;
  final Color buttonColor;
  final Color countColor;
  final String collection;

  ZikirmatikItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.imagePath,
    this.lightImagePath,
    this.marketImagePath,
    this.marketLightImagePath,
    this.isDefault = false,
    required this.buttonColor,
    required this.countColor,
    this.collection = 'Diğer',
  });
}

class TesbihatItem {
  String name;
  final TextEditingController controller;
  int count;
  bool isCompleted;

  TesbihatItem({
    required this.name,
    required this.controller,
    this.count = 0,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
      'isCompleted': isCompleted,
    };
  }

  factory TesbihatItem.fromJson(Map<String, dynamic> json) {
    return TesbihatItem(
      name: json['name'],
      // Kontrolcü yeniden oluşturuluyor
      controller: TextEditingController(text: json['count'].toString()),
      count: json['count'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }

}

enum MarketViewMode { grid, list }

class Zikirmatik extends StatefulWidget {
  const Zikirmatik({super.key});

  @override
  State<Zikirmatik> createState() => _ZikirmatikState();
}

// WidgetsBindingObserver mixin'i eklendi
class _ZikirmatikState extends State<Zikirmatik>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _count = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<TesbihatItem> _addedTesbihats = [];
  int _currentTesbihatIndex = -1;

  var _zikirPuan = 0;
  var _marketPuan = 0;

  TesbihatItem? _editingItem;
  TextEditingController _editNameController = TextEditingController();
  TextEditingController _editCountController = TextEditingController();

  double _scaleIncrement = 1.0;
  double _scaleReset = 1.0;

  late BannerAd _bannerAd;
  bool _isBannerAdLoaded = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkThemeEnabled = true;
  bool _isProcessingPurchase = false;
  bool _shakeToResetEnabled = true;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  final TextEditingController _zikirToMarketController = TextEditingController();
  int _dailyAdWatchLimit = 2;

  String _selectedZikirmatikId = 'default';
  Map<String, bool> _unlockedZikirmatiks = {'default': true};
  MarketViewMode _marketViewMode = MarketViewMode.grid;

  final List<ZikirmatikItem> _allZikirmatiks = [
    ZikirmatikItem(
      id: 'default',
      name: 'Mosmor',
      cost: 0,
      imagePath: 'assets/zikirmatik.png',
      lightImagePath: 'assets/zikirmatik_aydinlik.png',
      marketImagePath: 'assets/zikirmatik_market.png',
      marketLightImagePath: 'assets/zikirmatik_market_aydinlik.png',
      isDefault: true,
      buttonColor: Colors.purpleAccent,
      countColor: Colors.cyanAccent,
      collection: 'Neon Koleksiyonu'
    ),
    ZikirmatikItem(
      id: 'cyan',
      name: 'Turkuaz',
      cost: 33,
      imagePath: 'assets/zikirmatik_cyan.png',
      lightImagePath: 'assets/zikirmatik_cyan_aydinlik.png',
      marketImagePath: 'assets/zikirmatik_cyan_market.png',
      marketLightImagePath: 'assets/zikirmatik_cyan_market_aydinlik.png',
      buttonColor: Colors.cyanAccent,
      countColor: Colors.cyanAccent,
      collection: 'Neon Koleksiyonu'
    ),
    ZikirmatikItem(
      id: 'osmanli1',
      name: 'Fatih',
      cost: 66,
      imagePath: 'assets/zikirmatik_osmanli1.png',
      lightImagePath: 'assets/zikirmatik_osmanli1_aydinlik.png',
      marketImagePath: 'assets/zikirmatik_osmanli1_market.png',
      marketLightImagePath: 'assets/zikirmatik_osmanli1_market_aydinlik.png',
      buttonColor: Color(0xFFF9DD93),
      countColor: Color(0xFFF9DD93),
      collection: 'Osmanlı Koleksiyonu'
    ),
    ZikirmatikItem(
      id: 'osmanli2',
      name: 'Lale Devri',
      cost: 66,
      imagePath: 'assets/zikirmatik_osmanli2.png',
      lightImagePath: 'assets/zikirmatik_osmanli2_aydinlik.png',
      marketImagePath: 'assets/zikirmatik_osmanli2_market.png',
      marketLightImagePath: 'assets/zikirmatik_osmanli2_market_aydinlik.png',
      buttonColor: Color(0xFFF9DD93),
      countColor: Color(0xFFF9DD93),
      collection: 'Osmanlı Koleksiyonu'
    ),
    ZikirmatikItem(
      id: 'osmanli3',
      name: 'Payitaht',
      cost: 66,
      imagePath: 'assets/zikirmatik_osmanli3.png',
      lightImagePath: 'assets/zikirmatik_osmanli3_aydinlik.png',
      marketImagePath: 'assets/zikirmatik_osmanli3_market.png',
      marketLightImagePath: 'assets/zikirmatik_osmanli3_market_aydinlik.png',
      buttonColor: Color(0xFFF9DD93),
      countColor: Color(0xFFF9DD93),
      collection: 'Osmanlı Koleksiyonu'
    ),
    ZikirmatikItem(
      id: 'uzay',
      name: 'Samanyolu',
      cost: 99,
      imagePath: 'assets/zikirmatik_uzay.png',
      lightImagePath: 'assets/zikirmatik_uzay_aydinlik.png',
      marketImagePath: 'assets/zikirmatik_uzay_market.png',
      marketLightImagePath: 'assets/zikirmatik_uzay_market_aydinlik.png',
      buttonColor: Color(0xFFECEAE6),
      countColor: Color(0xFFECEAE6),
      collection: 'Uzay Koleksiyonu'
    ),
    ZikirmatikItem(
      id: 'uzay2',
      name: 'Uzay',
      cost: 99,
      imagePath: 'assets/zikirmatik_uzay2.png',
      lightImagePath: 'assets/zikirmatik_uzay2_aydinlik.png',
      marketImagePath: 'assets/zikirmatik_uzay2_market.png',
      marketLightImagePath: 'assets/zikirmatik_uzay2_market_aydinlik.png',
      buttonColor: Color(0xFF30E0F1),
      countColor: Color(0xFF30E0F1),
      collection: 'Uzay Koleksiyonu'
    ),
  ];

  // Tesbihat listesini kaydetme fonksiyonu
  Future<void> _saveAddedTesbihats() async {
    final prefs = await SharedPreferences.getInstance();
    final String tesbihatsJson = jsonEncode(_addedTesbihats.map((item) => item.toJson()).toList());
    await prefs.setString('added_tesbihats', tesbihatsJson);
     await prefs.setInt('current_tesbihat_index', _currentTesbihatIndex); // Yeni eklendi
  }

  // Tesbihat listesini yükleme fonksiyonu
  Future<void> _loadAddedTesbihats() async {
  final prefs = await SharedPreferences.getInstance();
  final String? tesbihatsJson = prefs.getString('added_tesbihats');
  if (tesbihatsJson != null) {
    final List<dynamic> tesbihatsData = jsonDecode(tesbihatsJson);
    setState(() {
      _addedTesbihats = tesbihatsData.map((data) => TesbihatItem.fromJson(data)).toList();
    });
  }
  _currentTesbihatIndex = prefs.getInt('current_tesbihat_index') ?? -1;

  // Eğer liste boşsa veya tümü tamamlanmışsa serbest moda geç
  if (_addedTesbihats.isEmpty || _addedTesbihats.every((item) => item.isCompleted)) {
    _currentTesbihatIndex = -1;
  } else if (_currentTesbihatIndex >= _addedTesbihats.length) {
    _currentTesbihatIndex = 0;
  }
}

  void _moveToNextIncompleteTesbihat() {
  if (_addedTesbihats.isEmpty) {
    _currentTesbihatIndex = -1;
    _count = 0;
    return;
  }

  int startIndex = _currentTesbihatIndex;
  int index = _currentTesbihatIndex;
  bool foundNext = false;

  do {
    index = (index + 1) % _addedTesbihats.length;
    if (!_addedTesbihats[index].isCompleted) {
      foundNext = true;
      break;
    }
  } while (index != startIndex);

  if (foundNext) {
    _currentTesbihatIndex = index;
    _count = 0;
  } else {
    // Tüm tesbihatlar tamamlanmış, serbest moda geç
    _currentTesbihatIndex = -1;
    _count = 0;
  }
  _saveAddedTesbihats();
}

  

  @override
  void initState() {
    super.initState();
    MobileAds.instance.initialize();
    _loadBannerAd();
    _loadPreferences();
    _loadAddedTesbihats(); 
    _setSystemUIOverlayStyle();
    

    
    // Uygulama yaşam döngüsü gözlemcisi eklendi
    WidgetsBinding.instance.addObserver(this);
    // Uygulama başladığında sensör başlatılıyor
    _startSensor();
  }

  // Uygulama yaşam döngüsü değişikliklerini dinler
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Uygulama arka plana geçtiğinde sensörü durdur
      _stopSensor();
    } else if (state == AppLifecycleState.resumed) {
      // Uygulama ön plana döndüğünde sensörü tekrar başlat
      _startSensor();
    }
  }

  void _yeniTesbihatEkle(BuildContext context, StateSetter parentSetState, List<TesbihatItem> addedTesbihats) {
  List<TesbihatItem> _availableTesbihats = [
    TesbihatItem(name: 'Subhanallah', controller: TextEditingController(text: '33')),
    TesbihatItem(name: 'Elhemdülillah', controller: TextEditingController(text: '33')),
    TesbihatItem(name: 'Allahuekber', controller: TextEditingController(text: '33')),
  ];

  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _customCountController = TextEditingController(text: '33');

  const List<String> predefinedNames = ['Subhanallah', 'Elhemdülillah', 'Allahuekber'];


  showDialog(
    
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          Widget _buildAddedTesbihatRow(TesbihatItem item) {
            bool isEditing = item == _editingItem;
            bool isPredefined = predefinedNames.contains(item.name);
            

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  isEditing
                      ? Expanded(
                          child: Row(
                            children: [
                              isPredefined
                                  ? Text(
                                      '${item.name}: ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _darkThemeEnabled ? Colors.white : Colors.black,
                                      ),
                                    )
                                  : Expanded(
                                      child: TextField(
                                        controller: _editNameController,
                                        style: TextStyle(color: _darkThemeEnabled ? Colors.white : Colors.black),
                                        decoration: InputDecoration(
                                          labelText: 'Tesbihat Adı',
                                          labelStyle: TextStyle(color: _darkThemeEnabled ? Colors.white54 : Colors.black54),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          filled: true,
                                          fillColor: _darkThemeEnabled ? Colors.grey[700] : Colors.grey[200],
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _editCountController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: _darkThemeEnabled ? Colors.white : Colors.black),
                                  decoration: InputDecoration(
                                    labelText: 'Sayı',
                                    labelStyle: TextStyle(color: _darkThemeEnabled ? Colors.white54 : Colors.black54),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    filled: true,
                                    fillColor: _darkThemeEnabled ? Colors.grey[700] : Colors.grey[200],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Expanded(
                  child: Row(
                    children: [
                      Text(
                        '• ${item.name} (${item.count})',
                        style: TextStyle(
                          fontSize: 16,
                          color: _darkThemeEnabled ? Colors.white : Colors.black,
                        ),
                      ),
                      if (item.isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
                  isEditing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green[300]),
                              onPressed: () {
                                final newName = isPredefined ? item.name : _editNameController.text.trim();
                                final newCount = int.tryParse(_editCountController.text) ?? 0;

                                if (newName.isNotEmpty && newCount > 0) {
                                  parentSetState(() {
                                    item.name = newName;
                                    item.count = newCount;
                                  });
                                  _saveAddedTesbihats();
                                }
                                setState(() {
                                  _editingItem = null;
                                });
                              },
                              tooltip: 'Kaydet',
                              iconSize: 20,
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red[300]),
                              onPressed: () {
                                setState(() {
                                  _editingItem = null;
                                });
                              },
                              tooltip: 'İptal',
                              iconSize: 20,
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!item.isCompleted)
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue[300]),
                                onPressed: () {
                                  setState(() {
                                    _editingItem = item;
                                    _editNameController.text = item.name;
                                    _editCountController.text = item.count.toString();
                                  });
                                },
                                tooltip: 'Düzenle',
                                iconSize: 20,
                              ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red[300]),
                              onPressed: () {
                                final int removedIndex = addedTesbihats.indexOf(item);
                                parentSetState(() {
                                  addedTesbihats.remove(item);                                  
                                  if (_currentTesbihatIndex == removedIndex) {
  if (addedTesbihats.isEmpty) {
    _currentTesbihatIndex = -1;
  } else {
    _currentTesbihatIndex = removedIndex % addedTesbihats.length;
  }
} else if (_currentTesbihatIndex > removedIndex) {
  _currentTesbihatIndex--;
}
                                });
                                setState(() {});
                                _saveAddedTesbihats();
                              },
                              tooltip: 'Sil',
                              iconSize: 20,
                            ),
                          ],
                        ),
                ],
              ),
            );
          }
          
          Widget _buildTesbihatRow(String name, TextEditingController controller, {required VoidCallback onAdd}) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    color: _darkThemeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 50,
                        
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: _darkThemeEnabled ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Sayı',
                            labelStyle: TextStyle(color: _darkThemeEnabled ? Colors.white54 : Colors.black54),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            filled: true,
                            fillColor: _darkThemeEnabled ? Colors.grey[700] : Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _darkThemeEnabled ? Colors.orangeAccent : Colors.blue,
                          foregroundColor: _darkThemeEnabled ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Ekle'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Dialog(
  backgroundColor: Colors.transparent,
  child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15.0),
      gradient: LinearGradient(
        colors: _darkThemeEnabled
            ? [const Color(0xFF1B1B1B), const Color(0xFF262626)]
            : [const Color(0xFFFFFFFF), const Color(0xFFF0F0F0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 10.0,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Yeni Tesbihat Ekle',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _darkThemeEnabled ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Yapılacak Tesbihler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkThemeEnabled ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),

          // Değiştirilecek Kısım BURADAN BAŞLIYOR
          if (addedTesbihats.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Henüz eklenmiş tesbihat yok.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: _darkThemeEnabled ? Colors.white70 : Colors.black54,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.2), // Ekranın %40'ı
              child: SingleChildScrollView(
                child: Column(
                  children: addedTesbihats
                      .map((item) => _buildAddedTesbihatRow(item))
                      .toList(),
                ),
              ),
            ),
          // Değiştirilecek Kısım BURADA BİTİYOR

          const Divider(height: 20, thickness: 1),
          Text(
            'Eklenebilir Tesbihler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkThemeEnabled ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          ..._availableTesbihats.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildTesbihatRow(
                  item.name,
                  item.controller,
                  onAdd: () async {
                    parentSetState(() {
                      final count = int.tryParse(item.controller.text) ?? 0;
                      if (count > 0) {
                        addedTesbihats.add(TesbihatItem(
                            name: item.name,
                            controller: TextEditingController(),
                            count: count));
                        if (addedTesbihats.length == 1) {
                          _count = 0;
                          _currentTesbihatIndex = 0;
                        }
                      }
                    });
                    _saveAddedTesbihats();
                    item.controller.text = '';
                    await Future.delayed(const Duration(milliseconds: 200));
                    setState(() {
                      item.controller.text = '33';
                    });
                  },
                ),
              )),
          const Divider(height: 20, thickness: 1),
          Text(
            'Özel Tesbihat Ekle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkThemeEnabled ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customNameController,
                  style: TextStyle(
                      color: _darkThemeEnabled ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Tesbihat Adı',
                    labelStyle: TextStyle(
                        color: _darkThemeEnabled ? Colors.white54 : Colors.black54),
                    isDense: true,
                    filled: true,
                    fillColor:
                        _darkThemeEnabled ? Colors.grey[700] : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _customCountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      color: _darkThemeEnabled ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Sayı',
                    labelStyle: TextStyle(
                        color: _darkThemeEnabled ? Colors.white54 : Colors.black54),
                    isDense: true,
                    filled: true,
                    fillColor:
                        _darkThemeEnabled ? Colors.grey[700] : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final name = _customNameController.text.trim();
                  final count = int.tryParse(_customCountController.text) ?? 0;

                  if (name.isNotEmpty && count > 0) {
                    parentSetState(() {
                      addedTesbihats.add(TesbihatItem(
                          name: name,
                          controller: TextEditingController(),
                          count: count));
                    });

                    if (addedTesbihats.length == 1) {
                      _count = 0;
                      _currentTesbihatIndex = 0;
                    }

                    _saveAddedTesbihats();
                    setState(() {
                      _customNameController.clear();
                      _customCountController.text = '33';
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Kapat', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    ),
  ),
);
        },
      );
    },
  );
}

int _shakeCount = 0;
Timer? _shakeResetTimer;

void _startSensor() {
  _accelerometerSubscription ??=
      accelerometerEventStream().listen((AccelerometerEvent event) {
    double acceleration = event.x * event.x + event.y * event.y + event.z * event.z;

    const double shakeThreshold = 850; //sarsıntı eşiği
    const int requiredShakeCount = 7; //sallama sayısı
    const Duration shakeInterval = Duration(milliseconds: 500);

    if (acceleration > shakeThreshold) {
      if (_shakeToResetEnabled) { // Bu satırı ekleyin [cite: 55]
        _shakeCount++;
        HapticFeedback.lightImpact();

        _shakeResetTimer?.cancel();
        _shakeResetTimer = Timer(shakeInterval, () {
          _shakeCount = 0;
        });

        if (_shakeCount >= requiredShakeCount) {
          _reset();
          _shakeCount = 0;
          _shakeResetTimer?.cancel();
        }
      }
    }
  });
}

  // Sensörü durduran yeni metot
  void _stopSensor() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  @override
  void dispose() {
    // Uygulama yaşam döngüsü gözlemcisi kaldırıldı
    WidgetsBinding.instance.removeObserver(this);
    // Sensör durduruldu
    _stopSensor();
    _audioPlayer.dispose();
    _zikirToMarketController.dispose();
    _bannerAd.dispose();
    super.dispose();
  }
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          _isBannerAdLoaded = false;
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = prefs.getInt('count') ?? 0;
      _soundEnabled = prefs.getBool('sound') ?? true;
      _vibrationEnabled = prefs.getBool('vibration') ?? true;
      _darkThemeEnabled = prefs.getBool('theme') ?? true;
      _zikirPuan = prefs.getInt('zikirPuan') ?? 0;
      _marketPuan = prefs.getInt('marketPuan') ?? 0;
      _dailyAdWatchLimit = prefs.getInt('dailyAdWatchLimit') ?? 2;
      _shakeToResetEnabled = prefs.getBool('shakeToResetEnabled') ?? true;

      _selectedZikirmatikId = prefs.getString('selectedZikirmatikId') ?? 'default';
      List<String>? unlockedList = prefs.getStringList('unlockedZikirmatiks');
      if (unlockedList != null) {
        _unlockedZikirmatiks = {for (var id in unlockedList) id: true};
      } else {
        _unlockedZikirmatiks = {'default': true};
      }
      if (!_unlockedZikirmatiks.containsKey('default')) {
        _unlockedZikirmatiks['default'] = true;
      }

      String? viewMode = prefs.getString('marketViewMode');
      if (viewMode == 'list') {
        _marketViewMode = MarketViewMode.list;
      } else {
        _marketViewMode = MarketViewMode.grid;
      }
    });
  }

  Future<void> _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('count', _count);
    await prefs.setBool('sound', _soundEnabled);
    await prefs.setBool('vibration', _vibrationEnabled);
    await prefs.setBool('theme', _darkThemeEnabled);
    await prefs.setInt('zikirPuan', _zikirPuan);
    await prefs.setInt('marketPuan', _marketPuan);
    await prefs.setInt('dailyAdWatchLimit', _dailyAdWatchLimit);
    await prefs.setBool('shakeToResetEnabled', _shakeToResetEnabled);

    await prefs.setString('selectedZikirmatikId', _selectedZikirmatikId);
    await prefs.setStringList(
        'unlockedZikirmatiks', _unlockedZikirmatiks.keys.toList());

    await prefs.setString('marketViewMode', _marketViewMode == MarketViewMode.grid ? 'grid' : 'list');
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          _darkThemeEnabled ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          _darkThemeEnabled ? Brightness.dark : Brightness.light,
    ));
  }

  Future<void> _playClickSound() async {
    if (_soundEnabled) {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/click.wav'));
    }
  }

  Future<void> _playWrongSound() async {
    if (_soundEnabled) {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/wrong.wav'));
    }
  }

  void _saveZikir() async {
    if (_count > 0) {
      if (_vibrationEnabled) HapticFeedback.heavyImpact();
      await _playClickSound();
      if (!mounted) return;
      setState(() {
        _zikirPuan += _count;
        _count = 0;
      });
      _savePreferences();
    } else {
      await _playWrongSound();
    }
  }

  void _animateAndDo(VoidCallback action, String button) {
    setState(() {
      if (button == 'increment') {
        _scaleIncrement = 1.1;
      } else if (button == 'reset') {
        _scaleReset = 1.1;
      }
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        if (button == 'increment') {
          _scaleIncrement = 1.0;
        } else if (button == 'reset') {
          _scaleReset = 1.0;
        }
        action();
        _savePreferences();
      });
    });
  }

  void _increment() async {
  if (_vibrationEnabled) HapticFeedback.lightImpact();
  await _playClickSound();
  _animateAndDo(() {
    if (_addedTesbihats.isNotEmpty && _currentTesbihatIndex != -1) {
      TesbihatItem currentItem = _addedTesbihats[_currentTesbihatIndex];
      if (_count < currentItem.count) {
        _count++;
      }

      if (_count == currentItem.count) {
        currentItem.isCompleted = true;
        _count = 0;
        _saveAddedTesbihats();

        _moveToNextIncompleteTesbihat();

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('${currentItem.name} tamamlandı!')),
          );
      }
    } else {
      // Serbest modda sayma
      _count = (_count + 1) % 10000;
    }
  }, 'increment');
}

  void _reset() async {
  if (_vibrationEnabled) HapticFeedback.mediumImpact();
  if (_count == 0) {
    await _playWrongSound();
  } else {
    await _playClickSound();
  }

  _animateAndDo(() {
    _count = 0;
    if (_addedTesbihats.isNotEmpty && _currentTesbihatIndex != -1) {
      _addedTesbihats[_currentTesbihatIndex].isCompleted = false;
    }
  }, 'reset');
  _saveAddedTesbihats();
}

  Future<bool> _purchaseZikirmatik(ZikirmatikItem item) async {
    if (_isProcessingPurchase) return false;

    setState(() {
      _isProcessingPurchase = true; // Satın alma işlemi başladı
    });

    if (_marketPuan >= item.cost) {
      bool confirmPurchase = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Satın Almayı Onayla'),
            content: Text('${item.name} zikirmatiği ${item.cost} market puanıyla satın almak istediğinize emin misiniz?'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Hayır'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Evet'),
              ),
            ],
          );
        },
      ) ?? false;

      if (!mounted) return false;

      if (confirmPurchase) {
        setState(() {
          _isProcessingPurchase = false;
          _marketPuan -= item.cost;
          _unlockedZikirmatiks[item.id] = true;
        });
        await _savePreferences();
        if (!mounted) return false;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(            
            SnackBar(content: Text('${item.name} zikirmatik satın alındı!')),
          );
        return true;
      }
    } else {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content:Text('Yetersiz Market Puanı!'),),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _isProcessingPurchase = false; // Satın alma işlemi başladı
        });

    }
    return false;
  }

  void _selectZikirmatik(ZikirmatikItem item) {
    setState(() {
      _selectedZikirmatikId = item.id;
    });
    _savePreferences();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${item.name} zikirmatik seçildi!')),
      );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final double bottomPadding = MediaQuery.of(context).viewInsets.bottom;

        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setModalState) {
            void toggleSound() {
              setState(() => _soundEnabled = !_soundEnabled);
              setModalState(() {});
              _savePreferences();
            }

            void toggleVibration() {
              setState(() => _vibrationEnabled = !_vibrationEnabled);
              setModalState(() {});
              _savePreferences();
            }

            void toggleTheme() {
              setState(() {
                _darkThemeEnabled = !_darkThemeEnabled;
                _setSystemUIOverlayStyle();
              });
              setModalState(() {});
              _savePreferences();
            }
            
            void toggleShakeToReset() {
              setState(() {
                _shakeToResetEnabled = !_shakeToResetEnabled;
              });
              setModalState(() {});
              _savePreferences();
            }

            Future<void> resetSettings() async {
              bool confirmReset = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Varsayılan Ayarlar'),
                    content: const Text(
                      'Ayarlar varsayılan değerlere dönecek. Emin misiniz?'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Hayır'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Evet'),
                      ),
                    ],
                  );
                },
              ) ?? false;


              if (!confirmReset) return;

                SharedPreferences prefs = await SharedPreferences.getInstance();

                await prefs.setBool('sound', true);
                await prefs.setBool('vibration', true);
                await prefs.setBool('theme', true);
                await prefs.setBool('shakeToResetEnabled', true);

                setState(() {
                  _soundEnabled = true;
                  _vibrationEnabled = true;
                  _darkThemeEnabled = true;
                  _shakeToResetEnabled = true;
                  _setSystemUIOverlayStyle();
                });
                setModalState(() {});
                _savePreferences();
            }


            Future<void> resetApp() async {
              bool confirmReset = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Uygulamayı Sıfırla'),
                    content: const Text(
                       'Tüm veriler silinecek ve uygulama varsayılan ayarlara dönecek. Emin misiniz?'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('Hayır'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text('Evet'),
                        ),
                      ],
                    );
                  },
                ) ?? false;

                if (!confirmReset) return;

                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                setState(() {
                  _count = 0;
                  _soundEnabled = true;
                  _vibrationEnabled = true;
                  _darkThemeEnabled = true;
                  _shakeToResetEnabled = true;
                  _zikirPuan = 0;
                  _marketPuan = 0;
                  _dailyAdWatchLimit = 2;
                  _selectedZikirmatikId = 'default';
                  _unlockedZikirmatiks = {'default': true};
                  _addedTesbihats = [];
                 _setSystemUIOverlayStyle();
               });
               setModalState(() {});
               _savePreferences();
              }



            Color bgColor =
                _darkThemeEnabled ? Colors.grey[900]! : Colors.white;
            Color textColor = _darkThemeEnabled ? Colors.white : Colors.black;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ayarlar',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: Icon(Icons.volume_up, color: textColor),
                        title: Text('Ses', style: TextStyle(color: textColor)),
                        trailing: Switch(
                          value: _soundEnabled,
                          onChanged: (val) => toggleSound(),
                          activeColor: Colors.greenAccent,
                        ),
                        onTap: toggleSound,
                      ),
                      ListTile(
                        leading: Icon(Icons.vibration, color: textColor),
                        title: Text('Titreşim', style: TextStyle(color: textColor)),
                        trailing: Switch(
                          value: _vibrationEnabled,
                          onChanged: (val) => toggleVibration(),
                          activeColor: Colors.greenAccent,
                        ),
                        onTap: toggleVibration,
                      ),
                      ListTile(
                        leading: Icon(Icons.brightness_6, color: textColor),
                        title:
                            Text('Karanlık Tema', style: TextStyle(color: textColor)),
                        trailing: Switch(
                          value: _darkThemeEnabled,
                          onChanged: (val) => toggleTheme(),
                          activeColor: Colors.amber,
                        ),
                        onTap: toggleTheme,
                      ),
                      ListTile(
                        leading: Icon(Icons.screen_rotation, color: textColor),
                        title: Text('Sallayarak Sıfırlama', style: TextStyle(color: textColor)),
                        trailing: Switch(
                          value: _shakeToResetEnabled,
                          onChanged: (val) => toggleShakeToReset(), // toggleShakeToReset() metodunu çağırın
                          activeColor: Colors.purpleAccent,
                        ),
                        onTap: toggleShakeToReset, // onTap için de aynı metodu çağırın
                      ),
                      ListTile(
                        leading: Icon(Icons.restore, color: textColor),
                        title:
                            Text('Varsayılan Ayarlar', style: TextStyle(color: textColor)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: resetSettings,
                          child: const Icon(Icons.restore),
                        ),
                      ),                      
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: resetApp,
                        icon: const Icon(Icons.warning_amber_outlined,
                            size: 24, color: Colors.redAccent),
                        label: const Text(
                          "Uygulamayı Sıfırla",
                          style: TextStyle(fontSize: 16, color: Colors.redAccent),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _darkThemeEnabled ? Colors.white : Colors.black,
                          foregroundColor:
                              _darkThemeEnabled ? Colors.black : Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kapat'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Ortak bir puan değeri kutusu widget'ı oluşturuldu, ikon ve renk parametreleri eklendi.
  Widget _buildPuanValueBox(int value, IconData icon, Color iconColor) {
    const double fixedWidth = 60.0;
    return Container(
      width: fixedWidth,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: iconColor.withAlpha((255 * 0.3).toInt()),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: iconColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: iconColor.withAlpha((255 * 0.3).toInt()),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 14,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              "$value",
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _darkThemeEnabled ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ortak bir puan başlığı ve içerik widget'ı oluşturuldu.
  Widget _buildPuanDisplayWithHeader(String title, int value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: _darkThemeEnabled
            ? Colors.grey[850]?.withAlpha((255 * 0.7).toInt())
            : Colors.grey[200]?.withAlpha((255 * 0.7).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _darkThemeEnabled ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (_darkThemeEnabled ? Colors.black : Colors.grey[400]!).withAlpha((255 * 0.3).toInt()),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _darkThemeEnabled ? Colors.white : Colors.black,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          _buildPuanValueBox(value, icon, iconColor),
        ],
      ),
    );
  }
  
  // Market puanı girişi için ayrı bir widget, ikon ve renk parametreleri eklendi.
  Widget _buildMarketInputPuanBox(TextEditingController controller, IconData icon, Color iconColor) {
    const double fixedWidth = 60.0;
    return Container(
      width: fixedWidth,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: iconColor.withAlpha((255 * 0.3).toInt()),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: iconColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: iconColor.withAlpha((255 * 0.3).toInt()),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        textAlign: TextAlign.right,
        style: TextStyle(
          color: _darkThemeEnabled ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          border: InputBorder.none,
          suffixIcon: Icon(icon, color: iconColor, size: 14),
          suffixIconConstraints: const BoxConstraints(minWidth: 14, minHeight: 14),
        ),
      ),
    );
  }

  Widget _buildMarketPuanDisplayWithHeaderContent(String title, Widget contentWidget) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: _darkThemeEnabled
            ? Colors.grey[850]?.withAlpha((255 * 0.7).toInt())
            : Colors.grey[200]?.withAlpha((255 * 0.7).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _darkThemeEnabled ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (_darkThemeEnabled ? Colors.black : Colors.grey[400]!).withAlpha((255 * 0.3).toInt()),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _darkThemeEnabled ? Colors.white : Colors.black,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          contentWidget,
        ],
      ),
    );
  }

  void _showMarket() {
    ValueNotifier<MarketViewMode> currentViewModeNotifier = ValueNotifier(_marketViewMode);
    ValueNotifier<bool> marketThemeNotifier = ValueNotifier(_darkThemeEnabled);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        // Ekran boyutunu al
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final screenHeight = MediaQuery.of(dialogContext).size.height;

        return Dialog(
           insetPadding: EdgeInsets.only(
            right: (screenWidth * 0.13) / 2,
            left: (screenWidth * 0.13) / 2,
            top: (screenHeight * 0.05) / 2,
            bottom: (screenHeight * 0.06),
           ), // Değiştirilmiş değer
          backgroundColor: Colors.transparent, // Diyalogun kendisi şeffaf yapıldı
          child: Center( // İçeriği ortalamak için Center kullanıldı
            child: Container(
              width: screenWidth * 0.87, // Değiştirilmiş değer
              height: screenHeight * 0.93, // Değiştirilmiş değer
              decoration: BoxDecoration(
                color: _darkThemeEnabled
                    ? Colors.black.withAlpha((255 * 0.7).toInt())
                    : Colors.white.withAlpha((255 * 0.7).toInt()),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _darkThemeEnabled ? Colors.grey[900]?.withAlpha((255 * 0.8).toInt()) : Colors.grey[300]?.withAlpha((255 * 0.8).toInt()),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: TabBar(
                        labelColor: Colors.purpleAccent,
                        unselectedLabelColor:
                            _darkThemeEnabled ? Colors.white70 : Colors.black54,
                        indicatorColor: Colors.purpleAccent,
                        tabs: const [
                          Tab(icon: Icon(Icons.touch_app, size: 20), text: 'Zikirmatik'),
                          //arka plan ikon
                          Tab(icon: Icon(Icons.fiber_smart_record, size: 20), text: 'Market Puanı'),
                        ],
                        onTap: (index) {
                          // TabController zaten sekme değişimlerini otomatik olarak yönetir.
                        },
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.transparent, // TabBarView için transparan renk
                        child: TabBarView(
                          children: [
                            // Zikirmatikler bölümü
StatefulBuilder(
  builder: (BuildContext innerDialogContext, StateSetter setInnerDialogState) {
    MarketViewMode currentViewMode = currentViewModeNotifier.value;
    bool marketDarkThemeEnabled = marketThemeNotifier.value;

    // Zikirmatikleri koleksiyonlara göre gruplandır
    final Map<String, List<ZikirmatikItem>> groupedZikirmatiks = {};
    for (var item in _allZikirmatiks) {
      if (!groupedZikirmatiks.containsKey(item.collection)) {
        groupedZikirmatiks[item.collection] = [];
      }
      groupedZikirmatiks[item.collection]!.add(item);
    }

    // Koleksiyon başlıklarını sırala (isteğe bağlı)
    final List<String> collectionTitles = groupedZikirmatiks.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tema değiştirme butonu
              ElevatedButton.icon(
                onPressed: () {
                  setInnerDialogState(() {
                    marketThemeNotifier.value = !marketDarkThemeEnabled;
                  });
                },
                icon: Icon(
                  marketDarkThemeEnabled ? Icons.sunny : Icons.dark_mode_outlined,
                  size: 20,
                ),
                label: Text(
                  marketDarkThemeEnabled ? 'Aydınlık halleri' : 'Karanlık halleri',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: marketDarkThemeEnabled ? Colors.white : Colors.black,
                  foregroundColor: marketDarkThemeEnabled ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Görünüm:',
                    style: TextStyle(
                      color: _darkThemeEnabled ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.grid_view,
                      color: currentViewMode == MarketViewMode.grid
                          ? Colors.purpleAccent
                          : (_darkThemeEnabled ? Colors.white54 : Colors.black38),
                    ),
                    onPressed: () {
                      setInnerDialogState(() {
                        currentViewModeNotifier.value = MarketViewMode.grid;
                        _marketViewMode = MarketViewMode.grid;
                      });
                      _savePreferences();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.format_list_bulleted,
                      color: currentViewMode == MarketViewMode.list
                          ? Colors.purpleAccent
                          : (_darkThemeEnabled ? Colors.white54 : Colors.black38),
                    ),
                    onPressed: () {
                      setInnerDialogState(() {
                        currentViewModeNotifier.value = MarketViewMode.list;
                        _marketViewMode = MarketViewMode.list;
                      });
                      _savePreferences();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder( // ListView.builder kullanarak koleksiyonları kaydırılabilir hale getir
            itemCount: collectionTitles.length,
            itemBuilder: (context, collectionIndex) {
              final String collectionName = collectionTitles[collectionIndex];
              final List<ZikirmatikItem> collectionItems = groupedZikirmatiks[collectionName]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                    child: Text(
                      collectionName,
                      style: TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Koleksiyon içindeki zikirmatikleri GridView veya ListView olarak göster
                  currentViewMode == MarketViewMode.grid
                      ? GridView.builder(
                          shrinkWrap: true, // İçeriğine göre boyutlanmasını sağlar
                          physics: const NeverScrollableScrollPhysics(), // Dış ListView ile birlikte kaydırma
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: collectionItems.length,
                          itemBuilder: (context, itemIndex) {
                            final item = collectionItems[itemIndex];
                            final bool isUnlocked = _unlockedZikirmatiks.containsKey(item.id) && _unlockedZikirmatiks[item.id]!;
                            final bool isSelected = _selectedZikirmatikId == item.id;

                            final marketImagePath = marketDarkThemeEnabled
                                ? item.marketImagePath ?? item.imagePath
                                : item.marketLightImagePath ?? item.lightImagePath ?? item.imagePath;

                            return GestureDetector(
                              onTap: () async {
                                if (!isUnlocked) {
                                  bool purchaseSuccessful = await _purchaseZikirmatik(item);
                                  if (purchaseSuccessful) {
                                    setInnerDialogState(() {});
                                  }
                                } else if (!isSelected) {
                                  _selectZikirmatik(item);
                                  setInnerDialogState(() {});
                                }
                              },
                              child: Card(
                                color: _darkThemeEnabled ? Colors.grey[800] : Colors.white,
                                elevation: 5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: BorderSide(
                                    color: isSelected ? Colors.purpleAccent : Colors.transparent,
                                    width: isSelected ? 3.0 : 0.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: isSelected ? Border.all(color: Colors.purpleAccent, width: 3) : null,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.asset(
                                              marketImagePath,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Flexible(
                                        flex: 1,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            item.name,
                                            style: TextStyle(
                                              color: _darkThemeEnabled ? Colors.white : Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Flexible(
                                        flex: 1,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: !item.isDefault && !isUnlocked
                                              ? Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.fiber_smart_record, color: Colors.amber, size: 20),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      '${item.cost} MP',
                                                      style: TextStyle(
                                                        color: _darkThemeEnabled ? Colors.amber : Colors.orange,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : isUnlocked && !isSelected
                                                  ? Text(
                                                      'Kilit Açıldı',
                                                      style: TextStyle(
                                                        color: _darkThemeEnabled ? Colors.greenAccent : Colors.green,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    )
                                                  : isSelected
                                                      ? Text(
                                                          'Seçili',
                                                          style: TextStyle(
                                                            color: Colors.purpleAccent,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        )
                                                      : Container(),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Flexible(
                                        flex: 2,
                                        child: Center(
                                          child: !isUnlocked
                                              ? FittedBox(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      bool purchaseSuccessful = await _purchaseZikirmatik(item);
                                                      if (purchaseSuccessful) {
                                                        setInnerDialogState(() {});
                                                      }
                                                    },
                                                    icon: const Icon(Icons.shopping_cart, size: 20),
                                                    label: const Text('Satın Al', style: TextStyle(fontSize: 14)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.green,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                    ),
                                                  ),
                                                )
                                              : isSelected
                                                  ? const Icon(Icons.check_circle, color: Colors.green, size: 40)
                                                  : FittedBox(
                                                      child: ElevatedButton.icon(
                                                        onPressed: () {
                                                          _selectZikirmatik(item);
                                                          setInnerDialogState(() {});
                                                        },
                                                        icon: const Icon(Icons.touch_app, size: 20),
                                                        label: const Text('Seç', style: TextStyle(fontSize: 14)),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.blueAccent,
                                                          foregroundColor: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : LayoutBuilder(
                          builder: (context, innerConstraints) {
                            int crossAxisCount = innerConstraints.maxWidth > 500 ? 2 : 1;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisExtent: 80,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: collectionItems.length,
                              itemBuilder: (context, itemIndex) {
                                final item = collectionItems[itemIndex];
                                final bool isUnlocked = _unlockedZikirmatiks.containsKey(item.id) && _unlockedZikirmatiks[item.id]!;
                                final bool isSelected = _selectedZikirmatikId == item.id;

                                final marketImagePath = marketDarkThemeEnabled
                                    ? item.marketImagePath ?? item.imagePath
                                    : item.marketLightImagePath ?? item.lightImagePath ?? item.imagePath;

                                return GestureDetector(
                                  onTap: () async {
                                    if (!isUnlocked) {
                                      bool purchaseSuccessful = await _purchaseZikirmatik(item);
                                      if (purchaseSuccessful) {
                                        setInnerDialogState(() {});
                                      }
                                    } else if (!isSelected) {
                                      _selectZikirmatik(item);
                                      setInnerDialogState(() {});
                                    }
                                  },
                                  child: Card(
                                    color: _darkThemeEnabled ? Colors.grey[800] : Colors.grey[100],
                                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(
                                        color: isSelected ? Colors.purpleAccent : Colors.transparent,
                                        width: isSelected ? 3.0 : 0.0,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 60,
                                                  height: 60,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(
                                                        color: isSelected ? Colors.purpleAccent : Colors.transparent,
                                                        width: isSelected ? 3.0 : 0.0,
                                                      ),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(10),
                                                      child: Image.asset(
                                                        marketImagePath,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        item.name,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                          color: _darkThemeEnabled ? Colors.white : Colors.black,
                                                        ),
                                                      ),
                                                      if (!item.isDefault && !isUnlocked)
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.fiber_smart_record, color: Colors.amber, size: 16),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Fiyat: ${item.cost} MP',
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.amber,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      else if (isUnlocked && !isSelected)
                                                        Text(
                                                          'Kilit Açıldı',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: _darkThemeEnabled ? Colors.greenAccent : Colors.green,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        )
                                                      else if (isSelected)
                                                        Text(
                                                          'Seçili',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.purpleAccent,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          FittedBox(
                                            child: !isUnlocked
                                                ? ElevatedButton.icon(
                                                    onPressed: () async {
                                                      bool purchaseSuccessful = await _purchaseZikirmatik(item);
                                                      if (purchaseSuccessful) {
                                                        setInnerDialogState(() {});
                                                      }
                                                    },
                                                    icon: const Icon(Icons.shopping_cart),
                                                    label: const Text('Satın Al'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.lightGreen,
                                                      foregroundColor: Colors.black,
                                                    ),
                                                  )
                                                : isSelected
                                                    ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
                                                    : ElevatedButton.icon(
                                                        onPressed: () {
                                                          _selectZikirmatik(item);
                                                          setInnerDialogState(() {});
                                                        },
                                                        icon: const Icon(Icons.touch_app),
                                                        label: const Text('Seç'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.blueAccent,
                                                          foregroundColor: Colors.white,
                                                        ),
                                                      ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ],
              );
            },
          ),
        ),
      ],
    );
  },
),
                            // Arka Planlar bölümü
                           
                            // Market Puanı bölümü
                            StatefulBuilder(
                              builder: (BuildContext innerDialogContext, StateSetter setInnerDialogState) {
                                return MarketPuanTab(
                                  zikirPuan: _zikirPuan,
                                  dailyAdWatchLimit: _dailyAdWatchLimit,
                                  zikirToMarketController: _zikirToMarketController,
                                  onConvert: (convertedZikir, earnedMarket) {
                                    setState(() {
                                    _zikirPuan -= convertedZikir;
                                    _marketPuan += earnedMarket;
                                    });
                                    setInnerDialogState(() {});
                                    _savePreferences();
                                  },
                                  darkThemeEnabled: _darkThemeEnabled,
                                  buildPuanValueBox: (value, icon, color) => _buildPuanValueBox(value, icon, color),
                                  buildMarketInputPuanBox: (controller, icon, color) => _buildMarketInputPuanBox(controller, icon, color),
                                  buildMarketPuanDisplayWithHeaderContent: (title, content) => _buildMarketPuanDisplayWithHeaderContent(title, content),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: ElevatedButton(
                        onPressed: () {
                          currentViewModeNotifier.dispose();
                          marketThemeNotifier.dispose();
                          Navigator.of(dialogContext).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _darkThemeEnabled ? Colors.white : Colors.black,
                          foregroundColor:
                              _darkThemeEnabled ? Colors.black : Colors.white,
                        ),
                        child: const Text("Kapat"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    Widget _buildTesbihlerBox() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
    decoration: BoxDecoration(
      color: _darkThemeEnabled ? Colors.grey[850] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: (_darkThemeEnabled ? Colors.white : Colors.black).withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tesbihler',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _darkThemeEnabled ? Colors.white : Colors.black,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _yeniTesbihatEkle(context, setState, _addedTesbihats);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.2),
                textStyle: const TextStyle(fontSize: 12),
                foregroundColor: _darkThemeEnabled ? Colors.black : Colors.white,
                backgroundColor: _darkThemeEnabled ? Colors.orangeAccent : Colors.blue,
              ),
              child: const Text('Tesbih Ekle'),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: _addedTesbihats.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 2.0), // üstboşluk
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _addedTesbihats.asMap().entries.map((entry) { // asMap().entries kullanarak index'i al
                        int index = entry.key;
                        TesbihatItem item = entry.value;
                        bool isActive = (_currentTesbihatIndex != -1 && index == _currentTesbihatIndex); // Aktif tesbihatı belirle

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0.0),//listeninboşlukları
                          child: Container(
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (_darkThemeEnabled ? Colors.blueGrey[700] : Colors.blueGrey[100])
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0), //mavikutular
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '• ${item.name} (${item.count})',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _darkThemeEnabled ? Colors.white : Colors.black,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    
                                    overflow: TextOverflow.ellipsis, // Uzun isimler için
                                  ),
                                ),
                                Row(
                                  children: [
                                    
                                    if (item.isCompleted) // Tamamlandıysa tik işareti göster
                                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    if (!item.isCompleted) // Düzenle butonu sadece tamamlanmamışsa göster
                                      IconButton(
                                        padding: EdgeInsets.symmetric(vertical: 0),                                     
                                        constraints: const BoxConstraints(maxWidth: 5),
                                        icon: Icon(Icons.edit, color: Colors.blue[300]),
                                        onPressed: () {
                                          setState(() {
                                            _editingItem = item;
                                            _editNameController.text = item.name;
                                            _editCountController.text = item.count.toString();
                                          });
                                          _yeniTesbihatEkle(context, setState, _addedTesbihats);
                                        },
                                        iconSize: 20,
                                        tooltip: 'Düzenle',
                                      ),                                    
                                    IconButton(
  padding: EdgeInsets.symmetric(vertical: 0),
  constraints: const BoxConstraints(maxWidth: 5),
  icon: Icon(Icons.delete, color: Colors.red[300]),
  onPressed: () {
    final int removedIndex = _addedTesbihats.indexOf(item);
    setState(() {
      _addedTesbihats.remove(item);
      if (_currentTesbihatIndex == removedIndex) {
        if (_addedTesbihats.isEmpty) {
          _currentTesbihatIndex = -1;
        } else {
          _currentTesbihatIndex = removedIndex % _addedTesbihats.length;
        }
      } else if (_currentTesbihatIndex > removedIndex) {
        _currentTesbihatIndex--;
      }
      _count = 0;
    });
    _saveAddedTesbihats();
  },
  iconSize: 20,
  tooltip: 'Sil',
)
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Text(
                      'Henüz eklenmiş tesbihat yok.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: _darkThemeEnabled ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    ),
  );
}

    final currentZikirmatikItem = _allZikirmatiks
        .firstWhere((item) => item.id == _selectedZikirmatikId);

    final zikirmatikImagePath = _darkThemeEnabled
        ? currentZikirmatikItem.imagePath
        : currentZikirmatikItem.lightImagePath ?? currentZikirmatikItem.imagePath;

    // Seçili temaya göre tuş ve sayaç renklerini al
    final Color buttonColor = currentZikirmatikItem.buttonColor;
    final Color countColor = currentZikirmatikItem.countColor;


    return Scaffold(
      backgroundColor: _darkThemeEnabled ? Colors.black : Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          final screenHeight = MediaQuery.of(context).size.height;
          if (details.localPosition.dy > screenHeight * 0.5) {
            _increment();
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            double maxWidth = constraints.maxWidth;
            double maxHeight = constraints.maxHeight;

            double imageSize = maxWidth < maxHeight ? maxWidth : maxHeight;
            double fontSize = imageSize * 0.2;

            double displayTopRatio = 0.16;
            double displayRightRatio = 0.32;

            double resetTopRatio = 0.45;
            double resetLeftRatio = 0.60;

            double countTopRatio = 0.50;
            double countLeftRatio = 0.40;

            const double marketButtonWidth = 80; // Değiştirilmiş değer
            const double marketButtonHeight = 35;


            return Stack(
              children: [                
                Center(
                  child: SizedBox(
                    width: imageSize,
                    height: imageSize,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            zikirmatikImagePath,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          top: imageSize * displayTopRatio,
                          right: imageSize * displayRightRatio,
                          child: Text(
                            '$_count',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontFamily: 'DigitalMono',
                              color: countColor, // Sayaç rengi dinamik
                              shadows: [
                                Shadow(
                                    blurRadius: 25, color: countColor), // Gölge rengi dinamik
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: imageSize * resetTopRatio,
                          left: imageSize * resetLeftRatio,
                          child: GestureDetector(
                            onTap: _reset,
                            child: AnimatedScale(
                              scale: _scaleReset,
                              duration: const Duration(milliseconds: 100),
                              child: Container(
                                width: imageSize * 0.08,
                                height: imageSize * 0.08,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _darkThemeEnabled
                                      ? Colors.black
                                      : Colors.grey[300],
                                  border: Border.all(
                                      color: buttonColor, width: 2), // Çerçeve rengi dinamik
                                  boxShadow: [
                                    BoxShadow(
                                      color: buttonColor
                                          .withAlpha((255 * 0.8).toInt()),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(Icons.refresh,
                                      color: _darkThemeEnabled
                                          ? Colors.white
                                          : Colors.black,
                                      size: imageSize * 0.04),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: imageSize * countTopRatio,
                          left: imageSize * countLeftRatio,
                          child: GestureDetector(
                            onTap: _increment,
                            child: AnimatedScale(
                              scale: _scaleIncrement,
                              duration: const Duration(milliseconds: 100),
                              child: Container(
                                width: imageSize * 0.20,
                                height: imageSize * 0.20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _darkThemeEnabled
                                      ? Colors.black
                                      : Colors.grey[300],
                                  border: Border.all(
                                      color: buttonColor, width: 3), // Çerçeve rengi dinamik
                                  boxShadow: [
                                    BoxShadow(
                                      color: buttonColor
                                          .withAlpha((255 * 0.9).toInt()),
                                      blurRadius: 15,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.pan_tool_alt_rounded,
                                    color: _darkThemeEnabled
                                        ? Colors.white
                                        : Colors.black,
                                    size: imageSize * 0.12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 35,
                  right: 10,
                  child: IconButton(
                    icon: Icon(Icons.settings,
                        color:
                            _darkThemeEnabled ? Colors.white : Colors.black),
                    iconSize: 30,
                    onPressed: _showSettings,
                  ),
                ),
                Positioned(
                  top: 35,
                  left: 5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zikir puanı için yeni widget ve ikon kullanıldı
                      _buildPuanDisplayWithHeader("Zikir Puanı", _zikirPuan, Icons.all_inclusive, Colors.green),
                      const SizedBox(width: 3), // Değiştirilmiş değer
                      // Market puanı için eski ikon kullanıldı
                      _buildPuanDisplayWithHeader("Market Puanı", _marketPuan, Icons.fiber_smart_record, Colors.amber),
                    ],
                  ),
                ),
                Positioned(
                  top: 35,
                  left: (maxWidth / 2) - (marketButtonWidth / 2),
                  child: GestureDetector(
                    onTap: _showMarket,
                    child: Container(
                      width: marketButtonWidth,
                      height: marketButtonHeight,
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withAlpha((255 * 0.3).toInt()),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.purpleAccent,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "Market",
                          style: TextStyle(
                            fontSize: 14,
                            color: _darkThemeEnabled
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: (maxHeight - imageSize) / 2 + imageSize * 0.02,
                  left: (maxWidth / 2) - 70,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _saveZikir,
                    icon: const Icon(Icons.save),
                    label: const Text("Zikiri Kaydet"),
                  ),
                ),
              if (_isBannerAdLoaded)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: _bannerAd.size.width.toDouble(),
                    height: _bannerAd.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd),
                  ),
                ),
                Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only( 
            top: screenHeight *0.10,
            bottom: screenHeight *0.70, 
            right: screenWidth *0.02, 
            left: screenWidth *0.40,
          ),
          child: _buildTesbihlerBox(), // Yeni oluşturduğunuz widget'ı burada çağırın
        ),
      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MarketPuanTab extends StatefulWidget {
  final int zikirPuan;
  final int dailyAdWatchLimit;
  final TextEditingController zikirToMarketController;
  final Function(int convertedZikir, int earnedMarket) onConvert;
  final bool darkThemeEnabled;
  final Widget Function(int value, IconData icon, Color iconColor) buildPuanValueBox;
  final Widget Function(TextEditingController controller, IconData icon, Color iconColor) buildMarketInputPuanBox;
  final Widget Function(String title, Widget contentWidget) buildMarketPuanDisplayWithHeaderContent;


  const MarketPuanTab({
    super.key,
    required this.zikirPuan,
    required this.dailyAdWatchLimit,
    required this.zikirToMarketController,
    required this.onConvert,
    required this.darkThemeEnabled,
    required this.buildPuanValueBox,
    required this.buildMarketInputPuanBox,
    required this.buildMarketPuanDisplayWithHeaderContent,
  });

  @override
  State<MarketPuanTab> createState() => _MarketPuanTabState();
}

class _MarketPuanTabState extends State<MarketPuanTab> {
  late int _localCalculatedMarketPuan;

  bool _isConvertButtonDisabled = false;
  bool _isWatchAdButtonDisabled = false;

  final String _adWatchKey = 'dailyAdWatchCount';
  final String _lastAdWatchDateKey = 'lastAdWatchDate';

  int _adWatchCount = 0;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  @override
  void initState() {
    super.initState();
    _localCalculatedMarketPuan = (int.tryParse(widget.zikirToMarketController.text) ?? 0) ~/ 10;
    widget.zikirToMarketController.addListener(_calculateMarketPuanLocalListener);
    _loadAdWatchCount();
    _loadRewardedAd();
  }

  Future<void> _loadAdWatchCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_lastAdWatchDateKey);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    if (lastDateStr == todayStr) {
      _adWatchCount = prefs.getInt(_adWatchKey) ?? 0;
    } else {
      _adWatchCount = 0;
      await prefs.setInt(_adWatchKey, 0);
      await prefs.setString(_lastAdWatchDateKey, todayStr);
    }
  }

  Future<void> _saveAdWatchCount() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setInt(_adWatchKey, _adWatchCount);
    await prefs.setString(_lastAdWatchDateKey, todayStr);
  }

  void _loadRewardedAd() {
    if (_isRewardedAdLoading) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoading = false;
          });
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          _isRewardedAdLoading = false;
          debugPrint('Rewarded Ad failed to load: $err');
        },
      ),
    );
  }

  void _watchAd() async{
    if (_adWatchCount >= widget.dailyAdWatchLimit) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Günlük reklam izleme limitine ulaştınız.')),
          );
      }
      return;
    }

    if (_rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        setState(() {
          _adWatchCount++;
          // Her reklam izlemede 50 market puanı kazanılsın
          widget.onConvert(0, 10);
        });
        _saveAdWatchCount();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Reklam izlendi ve 10 Market Puanı kazandınız!')),
            );
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Reklam şu anda mevcut değil. Lütfen daha sonra tekrar deneyin.')),
          );
      }
      _loadRewardedAd();
    }
  }

  @override
  void dispose() {
    widget.zikirToMarketController.removeListener(_calculateMarketPuanLocalListener);
    super.dispose();
    _rewardedAd?.dispose();
  }

  void _calculateMarketPuanLocalListener() {
    setState(() {
      _localCalculatedMarketPuan = (int.tryParse(widget.zikirToMarketController.text) ?? 0) ~/ 10;
    });
  }

  void _convertZikirToMarketPuanLocal() {
    int zikirToConvert = int.tryParse(widget.zikirToMarketController.text) ?? 0;

    if (zikirToConvert > 0 && zikirToConvert <= widget.zikirPuan && zikirToConvert % 10 == 0) {
      int marketPuanEarned = zikirToConvert ~/ 10;
      widget.onConvert(zikirToConvert, marketPuanEarned);

      widget.zikirToMarketController.clear();


      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$zikirToConvert Zikir Puanı, $marketPuanEarned Market Puanına dönüştürüldü!')),
        );
    } else if (zikirToConvert == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Dönüştürmek istediğiniz zikir puanını girin.')),
        );
    } else if (zikirToConvert > widget.zikirPuan) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Yeterli zikir puanınız yok.')),
        );
    } else if (zikirToConvert % 10 != 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Dönüştürülecek zikir puanı 10\'un katı olmalıdır.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Zikir Puanı Dönüştür',
              style: TextStyle(
                color: widget.darkThemeEnabled ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '10 Zikir Puanı = 1 Market Puanı',
              style: TextStyle(
                color: widget.darkThemeEnabled ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.buildMarketPuanDisplayWithHeaderContent(
                  "Dönüştürülecek Zikir Puanı",
                  widget.buildMarketInputPuanBox(widget.zikirToMarketController, Icons.all_inclusive, Colors.green),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, color: widget.darkThemeEnabled ? Colors.white70 : Colors.black54, size: 16),
                const SizedBox(width: 4),
                widget.buildMarketPuanDisplayWithHeaderContent(
                  "Edinilecek Market Puanı",
                  widget.buildPuanValueBox(_localCalculatedMarketPuan, Icons.fiber_smart_record, Colors.amber),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Text(
                  'Dönüşebilecek puan: ${widget.zikirPuan}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _isConvertButtonDisabled ? () {} : () { 
                setState(() {
                  _isConvertButtonDisabled = true;
                });
                
                _convertZikirToMarketPuanLocal();

                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    setState(() {
                    _isConvertButtonDisabled = false;
                    });
                  }
                });

              },

              style: ElevatedButton.styleFrom(
                backgroundColor: _isConvertButtonDisabled ? Colors.grey[900]?.withAlpha((255 * 0.8).toInt()) : Colors.lightGreen,
                foregroundColor: _isConvertButtonDisabled ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Dönüştür', style: TextStyle(fontSize: 14)),
            ),
            const Divider(height: 30, thickness: 1, indent: 15, endIndent: 15),
            Text(
              'Reklam izleyerek market puanı kazan',
              style: TextStyle(
                color: widget.darkThemeEnabled ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Günlük kalan reklam hakkı: ${widget.dailyAdWatchLimit - _adWatchCount}',
              style: TextStyle(
                color: widget.darkThemeEnabled ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isWatchAdButtonDisabled ? () {} : () {
                setState(() {
                  _isWatchAdButtonDisabled = true;
                });

                _watchAd();

                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    setState(() {
                      _isWatchAdButtonDisabled = false;
                    });
                  }
                });

              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isWatchAdButtonDisabled ? Colors.grey[900]?.withAlpha((255 * 0.8).toInt()) : Colors.orangeAccent,
                foregroundColor: _isWatchAdButtonDisabled ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Reklam İzle', style: TextStyle(fontSize: 14)),
            ),         
          ],          
        ),
      ),
    );
  }
}