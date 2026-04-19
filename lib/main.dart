import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';


// ─────────────────────────────────────────────────────────────────────────────
//  GOOGLE PHOTOS SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class GPhoto {
  final String id, baseUrl, filename;
  final int width, height;
  GPhoto({required this.id, required this.baseUrl,
    required this.filename, this.width = 0, this.height = 0});

  factory GPhoto.fromJson(Map<String, dynamic> j) => GPhoto(
    id: j['id'] ?? '',
    baseUrl: j['baseUrl'] ?? '',
    filename: j['filename'] ?? '',
    width: int.tryParse(j['mediaMetadata']?['width']?.toString() ?? '0') ?? 0,
    height: int.tryParse(j['mediaMetadata']?['height']?.toString() ?? '0') ?? 0,
  );

  String get thumbUrl => '$baseUrl=w256-h256-c';
  String get fullUrl  => '$baseUrl=w1024-h1024';
}

class GooglePhotosService {
  static final _googleSignIn = GoogleSignIn(scopes: [
    'https://www.googleapis.com/auth/photoslibrary.readonly',
  ]);

  static GoogleSignInAccount? _account;
  static String? _accessToken;

  static Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signIn();
      if (_account == null) return false;
      final auth = await _account!.authentication;
      _accessToken = auth.accessToken;
      return _accessToken != null;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return false;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _accessToken = null;
  }

  static bool get isSignedIn => _account != null && _accessToken != null;
  static String get userName => _account?.displayName ?? '';
  static String? get userPhoto => _account?.photoUrl;

  static Future<bool> _refreshToken() async {
    if (_account == null) return false;
    try {
      final auth = await _account!.authentication;
      _accessToken = auth.accessToken;
      return _accessToken != null;
    } catch (_) { return false; }
  }

  static Future<({List<GPhoto> photos, String? nextPageToken})> listPhotos({
    int pageSize = 24,
    String? pageToken,
  }) async {
    if (!await _refreshToken()) return (photos: <GPhoto>[], nextPageToken: null);

    final uri = Uri.parse('https://photoslibrary.googleapis.com/v1/mediaItems'
        '?pageSize=$pageSize${pageToken != null ? '&pageToken=$pageToken' : ''}');

    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    });

    if (resp.statusCode != 200) {
      debugPrint('Photos API error ${resp.statusCode}: ${resp.body}');
      return (photos: <GPhoto>[], nextPageToken: null);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = (data['mediaItems'] as List? ?? [])
        .map((e) => GPhoto.fromJson(e as Map<String, dynamic>))
        .where((p) => p.baseUrl.isNotEmpty)
        .toList();

    return (photos: items, nextPageToken: data['nextPageToken'] as String?);
  }

  static Future<String?> downloadPhoto(GPhoto photo) async {
    try {
      final resp = await http.get(Uri.parse(photo.fullUrl));
      if (resp.statusCode != 200) return null;
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/${photo.filename}');
      await file.writeAsBytes(resp.bodyBytes);
      return file.path;
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BorrowBuddyApp());
}

// ─────────────────────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────────────────────
const kPrimary      = Color(0xFF00897B);
const kPrimaryLight = Color(0xFFE0F2F1);
const kAccent       = Color(0xFF26C6DA);
const kBg           = Color(0xFFF5FFFE);
const kCard         = Color(0xFFFFFFFF);
const kTile         = Color(0xFFE0F7F4);
const kPrice        = Color(0xFF00897B);
const kStar         = Color(0xFFFFC107);
const kErr          = Color(0xFFE53935);
const kWarning      = Color(0xFFFB8C00);
const kText         = Color(0xFF1A1A2E);
const kSub          = Color(0xFF6B7280);
const kLight        = Color(0xFF9CA3AF);
const kDivider      = Color(0xFFE5E7EB);

TextStyle kH1 = const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: kText);
TextStyle kH2 = const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kText);
TextStyle kH3 = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kText);
TextStyle kBody = const TextStyle(fontSize: 14, color: kSub);
TextStyle kPrice$ = const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kPrice);
TextStyle kBtn  = const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white);

// ─────────────────────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────────────────────
class Item {
  final String id, name, category, description, brand, condition;
  final String? size, color;
  final double pricePerDay, deposit;
  final int minDays, maxDays;
  final List<String> imagePaths;
  double rating;
  int reviewCount;
  bool available;
  final DateTime createdAt;
  final List<Review> reviews;
  final List<BookedRange> bookedRanges;

  Item({
    required this.id, required this.name, required this.category,
    required this.description, required this.brand, required this.condition,
    this.size, this.color, required this.pricePerDay, required this.deposit,
    this.minDays = 1, this.maxDays = 7, this.imagePaths = const [],
    this.rating = 0, this.reviewCount = 0, this.available = true,
    DateTime? createdAt, this.reviews = const [], this.bookedRanges = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  String get ownerName => '';

  String get emoji {
    switch (category.toLowerCase()) {
      case 'clothes':     return '👗';
      case 'electronics': return '🎮';
      case 'books':       return '📚';
      case 'accessories': return '🎒';
      case 'sports':      return '⚽';
      case 'tools':       return '🔧';
      case 'music':       return '🎸';
      default:            return '📦';
    }
  }
}

class BookedRange {
  final DateTime start, end;
  BookedRange(this.start, this.end);
}

class Booking {
  final String id;
  final Item item;
  final DateTime startDate, endDate;
  final int durationDays;
  final double subtotal, deposit, total;
  final String pickupLocation;
  String status;
  final List<String> pickupPhotos;
  final DateTime createdAt;

  Booking({
    required this.id, required this.item, required this.startDate,
    required this.endDate, required this.durationDays, required this.subtotal,
    required this.deposit, required this.total, required this.pickupLocation,
    this.status = 'confirmed', this.pickupPhotos = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get statusLabel {
    switch (status) {
      case 'confirmed':  return 'Confirmed';
      case 'active':     return 'Active';
      case 'completed':  return 'Completed';
      case 'cancelled':  return 'Cancelled';
      default:           return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'confirmed':  return Colors.blue;
      case 'active':     return kPrimary;
      case 'completed':  return Colors.green;
      case 'cancelled':  return kErr;
      default:           return kSub;
    }
  }
}

class Review {
  final String id, reviewerName, comment;
  final int rating;
  final DateTime createdAt;
  Review({required this.id, required this.reviewerName, required this.comment,
    required this.rating, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
}

class AppNotification {
  final String id, title, message, type;
  bool read;
  final DateTime createdAt;
  AppNotification({required this.id, required this.title, required this.message,
    required this.type, this.read = false, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
//  APP STATE
// ─────────────────────────────────────────────────────────────────────────────
class AppStore extends ChangeNotifier {
  final List<Item> _myItems = [];
  List<Item> get myItems => List.unmodifiable(_myItems);
  List<Item> get allItems => _myItems;

  final List<Booking> _bookings = [];
  List<Booking> get bookings => List.unmodifiable(_bookings);

  final Set<String> _savedIds = {};
  bool isSaved(String id) => _savedIds.contains(id);

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.read).length;

  String userName = 'You';
  String userEmail = 'you@college.ac.in';
  String userPhone = '+91 00000 00000';
  String userCollege = 'Your College';

  void addItem(Item item) {
    _myItems.add(item);
    _pushNotification('Item Listed!', '"${item.name}" is now live.');
    notifyListeners();
  }

  void removeItem(String id) {
    _myItems.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void updateItem(Item updated) {
    final idx = _myItems.indexWhere((i) => i.id == updated.id);
    if (idx != -1) { _myItems[idx] = updated; notifyListeners(); }
  }

  Booking bookItem({
    required Item item, required DateTime start, required DateTime end,
    required String pickupLocation,
  }) {
    final days = end.difference(start).inDays;
    final sub  = days * item.pricePerDay;
    final b = Booking(
      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
      item: item, startDate: start, endDate: end,
      durationDays: days, subtotal: sub,
      deposit: item.deposit, total: sub + item.deposit,
      pickupLocation: pickupLocation,
    );
    _bookings.add(b);
    item.bookedRanges.add(BookedRange(start, end));
    _pushNotification('Booking Confirmed', 'You booked "${item.name}".');
    notifyListeners();
    return b;
  }

  void cancelBooking(String id) {
    final b = _bookings.firstWhere((x) => x.id == id);
    b.status = 'cancelled';
    notifyListeners();
  }

  void completeBooking(String id) {
    final b = _bookings.firstWhere((x) => x.id == id);
    b.status = 'completed';
    b.item.available = true;
    notifyListeners();
  }

  void toggleSave(String id) {
    _savedIds.contains(id) ? _savedIds.remove(id) : _savedIds.add(id);
    notifyListeners();
  }

  List<Item> get savedItems => _myItems.where((i) => _savedIds.contains(i.id)).toList();

  void _pushNotification(String title, String message) {
    _notifications.insert(0, AppNotification(
      id: 'n_${DateTime.now().millisecondsSinceEpoch}',
      title: title, message: message, type: 'system',
    ));
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  List<Item> search(String q, {String category = 'All'}) {
    return _myItems.where((i) {
      final matchCat = category == 'All' || i.category == category;
      final matchQ   = q.isEmpty ||
          i.name.toLowerCase().contains(q.toLowerCase()) ||
          i.description.toLowerCase().contains(q.toLowerCase());
      return matchCat && matchQ;
    }).toList();
  }
}

class StoreProvider extends InheritedNotifier<AppStore> {
  const StoreProvider({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext ctx) =>
      ctx.dependOnInheritedWidgetOfExactType<StoreProvider>()!.notifier!;
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROOT APP
// ─────────────────────────────────────────────────────────────────────────────
class BorrowBuddyApp extends StatelessWidget {
  const BorrowBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore();
    return StoreProvider(
      store: store,
      child: MaterialApp(
        title: 'BorrowBuddy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: kPrimary,
          scaffoldBackgroundColor: kBg,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: kText,
            elevation: 0,
            centerTitle: false,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        home: const MainShell(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN SHELL
// ─────────────────────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final pages = [
      const HomeScreen(),
      const AddItemScreen(),
      const MyItemsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => setState(() => _tab = 1),
              backgroundColor: kPrimary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, current: _tab, onTap: _setTab),
              _NavItem(icon: Icons.add_circle_outline_rounded, label: 'List', index: 1, current: _tab, onTap: _setTab),
              _NavItem(icon: Icons.inventory_2_outlined, label: 'My Items', index: 2, current: _tab, onTap: _setTab),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', index: 3, current: _tab, onTap: _setTab,
                badge: store.unreadCount),
            ]),
          ),
        ),
      ),
    );
  }

  void _setTab(int i) => setState(() => _tab = i);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final void Function(int) onTap;
  final int badge;
  const _NavItem({required this.icon, required this.label, required this.index,
    required this.current, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, color: sel ? kPrimary : kLight, size: 26),
            if (badge > 0)
              Positioned(
                right: -6, top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: kErr, shape: BoxShape.circle),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9)),
                ),
              ),
          ]),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 11, color: sel ? kPrimary : kLight,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  String _selectedCategory = 'All';

  static const _categories = [
    {'id': 'All',         'icon': '🏠'},
    {'id': 'Clothes',     'icon': '👗'},
    {'id': 'Electronics', 'icon': '🎮'},
    {'id': 'Books',       'icon': '📚'},
    {'id': 'Accessories', 'icon': '🎒'},
    {'id': 'Sports',      'icon': '⚽'},
    {'id': 'Tools',       'icon': '🔧'},
    {'id': 'Music',       'icon': '🎸'},
  ];

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final items = store.search(_search.text, category: _selectedCategory);

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            elevation: 1,
            shadowColor: const Color(0x22000000),
            title: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPrimary, kAccent]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text('BorrowBuddy', style: kH2),
            ]),
            actions: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(clipBehavior: Clip.none, children: [
                    const Icon(Icons.notifications_outlined, color: kText),
                    if (store.unreadCount > 0)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: kErr, shape: BoxShape.circle),
                          child: Center(
                            child: Text('${store.unreadCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 9)),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Hello, ${store.userName} ', style: kH1),
                      const Text('👋', style: TextStyle(fontSize: 26)),
                    ]),
                    Text('Find items from your campus', style: kBody),
                  ]),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search clothes, electronics, books…',
                    prefixIcon: const Icon(Icons.search, color: kSub),
                    suffixIcon: _search.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: kSub),
                            onPressed: () { _search.clear(); setState(() {}); })
                        : null,
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kDivider)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kDivider)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPrimary, width: 2)),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final sel = _selectedCategory == cat['id'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat['id']!),
                      child: Column(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 58, height: 58,
                          decoration: BoxDecoration(
                            color: sel ? kPrimary : kTile,
                            shape: BoxShape.circle,
                            boxShadow: sel ? [const BoxShadow(color: Color(0x3300897B), blurRadius: 8, offset: Offset(0, 4))] : [],
                          ),
                          child: Center(child: Text(cat['icon']!, style: const TextStyle(fontSize: 26))),
                        ),
                        const SizedBox(height: 6),
                        Text(cat['id']!, style: TextStyle(fontSize: 12, color: sel ? kPrimary : kSub, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                      ]),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                    _search.text.isNotEmpty || _selectedCategory != 'All'
                        ? '${items.length} result${items.length == 1 ? '' : 's'}'
                        : 'Featured Items',
                    style: kH2,
                  ),
                  if (items.isNotEmpty) Text('${items.length} items', style: kBody),
                ]),
              ),

              if (items.isEmpty) _EmptyHome(
                onAdd: () {
                  final shell = context.findAncestorStateOfType<_MainShellState>();
                  shell?._setTab(1);
                },
              ),
            ]),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ItemCard(item: items[i]),
                childCount: items.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyHome({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        const Text('📦', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        Text('No items listed yet', style: kH3),
        const SizedBox(height: 8),
        Text('Tap + to list your first item and it will appear here!', style: kBody, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SizedBox(
          width: 180,
          child: ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('List an Item')),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ITEM CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  final Item item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 130, width: double.infinity,
                child: item.imagePaths.isNotEmpty
                    ? _ItemImage(path: item.imagePaths.first, fit: BoxFit.cover)
                    : Container(color: kTile, child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 52)))),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => store.toggleSave(item.id),
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(store.isSaved(item.id) ? Icons.favorite : Icons.favorite_border,
                      color: store.isSaved(item.id) ? kErr : kSub, size: 18),
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: kH3, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('₹${item.pricePerDay.toStringAsFixed(0)}/day', style: kPrice$),
              Text('Deposit ₹${item.deposit.toStringAsFixed(0)}', style: kBody),
              if (item.reviewCount > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.star_rounded, color: kStar, size: 14),
                  const SizedBox(width: 3),
                  Text(item.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: kSub)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ITEM DETAIL
// ─────────────────────────────────────────────────────────────────────────────
class ItemDetailScreen extends StatefulWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});
  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  int _imgIdx = 0;
  int _rentalDays = 1;

  @override
  void initState() { super.initState(); _rentalDays = widget.item.minDays; }

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final item  = widget.item;

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300, pinned: true, backgroundColor: Colors.white,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(padding: EdgeInsets.all(8),
                child: CircleAvatar(backgroundColor: Colors.white,
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: kText, size: 18))),
            ),
            actions: [
              GestureDetector(
                onTap: () => store.toggleSave(item.id),
                child: Padding(padding: const EdgeInsets.all(8),
                  child: CircleAvatar(backgroundColor: Colors.white,
                    child: Icon(store.isSaved(item.id) ? Icons.favorite : Icons.favorite_border,
                        color: store.isSaved(item.id) ? kErr : kSub))),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: item.imagePaths.isNotEmpty
                  ? _ItemImage(path: item.imagePaths[_imgIdx], fit: BoxFit.cover)
                  : Container(color: kTile, child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 80)))),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (item.imagePaths.length > 1)
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12), scrollDirection: Axis.horizontal,
                    itemCount: item.imagePaths.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => setState(() => _imgIdx = i),
                      child: Container(
                        width: 64, height: 64, margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _imgIdx == i ? kPrimary : kDivider, width: _imgIdx == i ? 2.5 : 1.5),
                        ),
                        child: ClipRRect(borderRadius: BorderRadius.circular(8),
                          child: _ItemImage(path: item.imagePaths[i], fit: BoxFit.cover)),
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: kH1),
                  const SizedBox(height: 6),
                  if (item.reviewCount > 0)
                    Row(children: [
                      ...List.generate(5, (i) => Icon(
                        i < item.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: kStar, size: 18)),
                      const SizedBox(width: 6),
                      Text('${item.rating.toStringAsFixed(1)} • ${item.reviewCount} reviews', style: kBody),
                    ]),
                  const SizedBox(height: 10),
                  Text('₹${item.pricePerDay.toStringAsFixed(0)}/day', style: kPrice$.copyWith(fontSize: 22)),
                  Text('Deposit: ₹${item.deposit.toStringAsFixed(0)}', style: kBody),
                ]),
              ),

              const SizedBox(height: 16),
              const Divider(indent: 16, endIndent: 16),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Owner', style: kH3),
                  const SizedBox(height: 10),
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: kPrimary, radius: 22,
                      child: Text(store.userName.isNotEmpty ? store.userName[0].toUpperCase() : 'Y',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(store.userName, style: kH3),
                      const Row(children: [
                        Icon(Icons.verified_rounded, color: kPrimary, size: 14),
                        SizedBox(width: 4),
                        Text('Verified Owner', style: TextStyle(fontSize: 12, color: kPrimary)),
                      ]),
                    ]),
                  ]),
                ]),
              ),

              const Divider(indent: 16, endIndent: 16),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Product Details', style: kH3),
                  const SizedBox(height: 12),
                  if (item.size != null && item.size!.isNotEmpty) _DetailRow('Size', item.size!),
                  if (item.color != null && item.color!.isNotEmpty) _DetailRow('Color', item.color!),
                  _DetailRow('Condition', item.condition),
                  _DetailRow('Category', item.category),
                  _DetailRow('Brand', item.brand),
                ]),
              ),

              const SizedBox(height: 8),
              const Divider(indent: 16, endIndent: 16),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rental Terms', style: kH3),
                  const SizedBox(height: 10),
                  _BulletText('Minimum rental period: ${item.minDays} day'),
                  _BulletText('Maximum rental period: ${item.maxDays} days'),
                  _BulletText('Late return fee: ₹${item.pricePerDay.toStringAsFixed(0)}/day'),
                  const _BulletText('Damage policy: Full deposit forfeiture'),
                ]),
              ),

              const SizedBox(height: 8),
              const Divider(indent: 16, endIndent: 16),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Description', style: kH3),
                  const SizedBox(height: 8),
                  Text(item.description, style: kBody.copyWith(height: 1.6)),
                ]),
              ),

              if (item.reviews.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Customer Reviews', style: kH3),
                    const SizedBox(height: 12),
                    ...item.reviews.map((r) => _ReviewTile(review: r)),
                  ]),
                ),
              ],

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(children: [
                  Text('Select Rental Days:', style: kH3),
                  const Spacer(),
                  _CounterBtn(icon: Icons.remove, onTap: () { if (_rentalDays > item.minDays) setState(() => _rentalDays--); }),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$_rentalDays', style: kH2)),
                  _CounterBtn(icon: Icons.add, onTap: () { if (_rentalDays < item.maxDays) setState(() => _rentalDays++); }),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ConfirmBookingScreen(item: item, initialDays: _rentalDays))),
                  child: const Text('Book Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Text(label, style: kBody), const Spacer(), Text(value, style: kH3.copyWith(color: kPrimary))]),
  );
}

class _BulletText extends StatelessWidget {
  final String text;
  const _BulletText(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
      Expanded(child: Text(text, style: kBody)),
    ]),
  );
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(review.reviewerName, style: kH3),
        const SizedBox(width: 8),
        Row(children: List.generate(review.rating, (_) => const Icon(Icons.star_rounded, color: kStar, size: 14))),
      ]),
      const SizedBox(height: 4),
      Text(review.comment, style: kBody),
    ]),
  );
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONFIRM BOOKING SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ConfirmBookingScreen extends StatefulWidget {
  final Item item;
  final int initialDays;
  const ConfirmBookingScreen({super.key, required this.item, required this.initialDays});
  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  DateTime? _start, _end;
  final _locationCtrl = TextEditingController();

  @override
  void dispose() { _locationCtrl.dispose(); super.dispose(); }

  int get _days => (_start != null && _end != null) ? _end!.difference(_start!).inDays : widget.initialDays;
  double get _subtotal => _days * widget.item.pricePerDay;
  double get _total    => _subtotal + widget.item.deposit;

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final item  = widget.item;
    final fmt   = DateFormat('dd-MM-yyyy');
    final bookedDates = item.bookedRanges;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true, title: const Text('Confirm Booking'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [kPrimary, kAccent]))),
            ),
            foregroundColor: Colors.white, backgroundColor: kPrimary,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: item.imagePaths.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(10),
                              child: _ItemImage(path: item.imagePaths.first, fit: BoxFit.cover))
                          : Center(child: Text(item.emoji, style: const TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.name, style: kH3),
                      Text('Owner: ${store.userName}', style: kBody),
                      Text('₹${item.pricePerDay.toStringAsFixed(0)} / day', style: kPrice$.copyWith(fontSize: 16)),
                    ])),
                  ]),
                ),

                const SizedBox(height: 20),

                if (bookedDates.isNotEmpty) ...[
                  const Row(children: [
                    Icon(Icons.calendar_month, color: kErr, size: 20),
                    SizedBox(width: 8),
                    Text('Booked Dates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kErr)),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F3), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.block, color: kErr, size: 16), SizedBox(width: 6),
                        Text('Item is unavailable on these dates', style: TextStyle(color: kErr, fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: bookedDates.map((bd) =>
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFFCDD2))),
                          child: Text('${DateFormat('MMM d').format(bd.start)} – ${DateFormat('MMM d, yyyy').format(bd.end)}',
                              style: const TextStyle(color: kErr, fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ).toList()),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                const Row(children: [
                  Icon(Icons.calendar_today_outlined, color: kPrimary, size: 20), SizedBox(width: 8),
                  Text('Select Booking Dates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kPrimary)),
                ]),
                const SizedBox(height: 12),

                _DatePickerField(
                  label: 'Start Date', value: _start != null ? fmt.format(_start!) : null,
                  onTap: () async {
                    final d = await _pickDate(context, first: DateTime.now());
                    if (d != null) setState(() { _start = d; if (_end != null && _end!.isBefore(d)) _end = null; });
                  },
                ),
                const SizedBox(height: 12),
                _DatePickerField(
                  label: 'End Date', value: _end != null ? fmt.format(_end!) : null,
                  onTap: () async {
                    final d = await _pickDate(context,
                        first: _start != null ? _start!.add(Duration(days: item.minDays)) : DateTime.now().add(const Duration(days: 1)));
                    if (d != null) setState(() => _end = d);
                  },
                ),

                if (_start != null && _end != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Duration: $_days Days', style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w600)),
                  ),

                const SizedBox(height: 20),

                const Row(children: [
                  Icon(Icons.location_on_outlined, color: kPrimary, size: 20), SizedBox(width: 8),
                  Text('Pickup Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kPrimary)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationCtrl, maxLines: 3,
                  decoration: const InputDecoration(hintText: 'e.g., Block B, Girls Hostel, ABES Engineering College'),
                ),
                const SizedBox(height: 6),
                const Row(children: [
                  Text('💡 ', style: TextStyle(fontSize: 12)),
                  Text('Include building, hostel block, or room number', style: TextStyle(color: kSub, fontSize: 12)),
                ]),

                const SizedBox(height: 20),

                const Row(children: [
                  Text('💰 ', style: TextStyle(fontSize: 18)),
                  Text('Payment Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    _PayRow('Price per day:', '₹${item.pricePerDay.toStringAsFixed(0)}'),
                    _PayRow('Duration:', '$_days Days'),
                    const Divider(),
                    _PayRow('Subtotal:', '₹${_subtotal.toStringAsFixed(0)}'),
                    _PayRow('Security Deposit:', '₹${item.deposit.toStringAsFixed(0)}'),
                    const Divider(),
                    _PayRow('Total Amount:', '₹${_total.toStringAsFixed(0)}', bold: true),
                  ]),
                ),

                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _canConfirm ? () {
                    final booking = store.bookItem(item: item, start: _start!, end: _end!, pickupLocation: _locationCtrl.text.trim());
                    Navigator.pushAndRemoveUntil(context,
                        MaterialPageRoute(builder: (_) => BookingSuccessScreen(booking: booking)), (r) => r.isFirst);
                  } : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _canConfirm ? kPrimary : kLight),
                  child: const Text('Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canConfirm => _start != null && _end != null && _locationCtrl.text.trim().isNotEmpty;

  Future<DateTime?> _pickDate(BuildContext ctx, {required DateTime first}) async {
    return showDatePicker(
      context: ctx, initialDate: first, firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
        child: child!,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _DatePickerField({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kDivider)),
      child: Row(children: [
        Expanded(child: Text(value ?? 'dd-mm-yyyy', style: value != null ? kH3 : kBody)),
        const Icon(Icons.calendar_today_outlined, color: kSub, size: 20),
      ]),
    ),
  );
}

class _PayRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _PayRow(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(label, style: bold ? kH3 : kBody),
      const Spacer(),
      Text(value, style: bold ? kPrice$.copyWith(fontSize: 18) : kH3),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOOKING SUCCESS
// ─────────────────────────────────────────────────────────────────────────────
class BookingSuccessScreen extends StatelessWidget {
  final Booking booking;
  const BookingSuccessScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: kPrimary, size: 60),
            ),
            const SizedBox(height: 24),
            Text('Booking Confirmed!', style: kH1),
            const SizedBox(height: 10),
            Text('Your booking for "${booking.item.name}" is confirmed.', style: kBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _BookingInfoRow('Item', booking.item.name),
                _BookingInfoRow('From', fmt.format(booking.startDate)),
                _BookingInfoRow('To', fmt.format(booking.endDate)),
                _BookingInfoRow('Duration', '${booking.durationDays} days'),
                _BookingInfoRow('Pickup', booking.pickupLocation),
                _BookingInfoRow('Total', '₹${booking.total.toStringAsFixed(0)}'),
              ]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const MainShell()), (r) => false),
              child: const Text('Back to Home'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BookingInfoRow extends StatelessWidget {
  final String label, value;
  const _BookingInfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(label, style: kBody), const Spacer(),
      Text(value, style: kH3.copyWith(color: kText, fontSize: 14)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ADD ITEM SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});
  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name    = TextEditingController();
  final _desc    = TextEditingController();
  final _brand   = TextEditingController();
  final _size    = TextEditingController();
  final _color   = TextEditingController();
  final _price   = TextEditingController();
  final _deposit = TextEditingController();
  final _minDays = TextEditingController(text: '1');
  final _maxDays = TextEditingController(text: '7');

  String _category  = 'Clothes';
  String _condition = 'Excellent';
  final List<XFile> _pickedImages = [];
  bool _loading = false;

  static const _categories = ['Clothes','Electronics','Books','Accessories','Sports','Tools','Music','Other'];
  static const _conditions = ['Brand New','Excellent','Good','Fair','Poor'];

  @override
  void dispose() {
    for (final c in [_name,_desc,_brand,_size,_color,_price,_deposit,_minDays,_maxDays]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFromDevice() async {
    final imgs = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (imgs.isNotEmpty) setState(() => _pickedImages.addAll(imgs));
  }

  Future<void> _pickFromGooglePhotos() async {
    if (!GooglePhotosService.isSignedIn) {
      final ok = await GooglePhotosService.signIn();
      if (!ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google sign-in failed or cancelled.'), backgroundColor: kErr));
        return;
      }
    }

    final selected = await showModalBottomSheet<List<GPhoto>>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => const _GooglePhotosPicker(),
    );

    if (selected == null || selected.isEmpty) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          const SizedBox(width: 12),
          Text('Downloading ${selected.length} photo${selected.length > 1 ? 's' : ''}…'),
        ]),
        backgroundColor: kPrimary, duration: const Duration(seconds: 10),
      ));
    }

    final paths = <String>[];
    for (final p in selected) {
      final path = await GooglePhotosService.downloadPhoto(p);
      if (path != null) paths.add(path);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => _pickedImages.addAll(paths.map((p) => XFile(p))));
      if (paths.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${paths.length} photo${paths.length > 1 ? 's' : ''} added!'),
          backgroundColor: kPrimary, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kDivider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Add Photos', style: kH2),
            const SizedBox(height: 20),
            _PhotoSourceTile(
              icon: Icons.image_search_rounded, color: const Color(0xFF4285F4), label: 'Google Photos',
              subtitle: GooglePhotosService.isSignedIn ? 'Signed in as ${GooglePhotosService.userName}' : 'Pick from your Google Photos library',
              onTap: () { Navigator.pop(ctx); _pickFromGooglePhotos(); },
            ),
            const SizedBox(height: 12),
            _PhotoSourceTile(
              icon: Icons.photo_library_outlined, color: kPrimary, label: 'Device Gallery',
              subtitle: 'Pick from your phone storage',
              onTap: () { Navigator.pop(ctx); _pickFromDevice(); },
            ),
            const SizedBox(height: 12),
            _PhotoSourceTile(
              icon: Icons.camera_alt_outlined, color: const Color(0xFFFF7043), label: 'Camera',
              subtitle: 'Take a new photo right now',
              onTap: () async {
                Navigator.pop(ctx);
                final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
                if (img != null) setState(() => _pickedImages.add(img));
              },
            ),
            if (GooglePhotosService.isSignedIn) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.logout, color: kErr, size: 18),
                label: const Text('Sign out of Google Photos', style: TextStyle(color: kErr)),
                onPressed: () async { await GooglePhotosService.signOut(); if (mounted) setState(() {}); Navigator.pop(ctx); },
              ),
            ],
          ]),
        ),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    final store = StoreProvider.of(context);
    final item = Item(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim(), category: _category,
      description: _desc.text.trim(), brand: _brand.text.trim(), condition: _condition,
      size: _size.text.trim().isEmpty ? null : _size.text.trim(),
      color: _color.text.trim().isEmpty ? null : _color.text.trim(),
      pricePerDay: double.tryParse(_price.text) ?? 0,
      deposit: double.tryParse(_deposit.text) ?? 0,
      minDays: int.tryParse(_minDays.text) ?? 1,
      maxDays: int.tryParse(_maxDays.text) ?? 7,
      imagePaths: _pickedImages.map((x) => x.path).toList(),
    );

    store.addItem(item);
    setState(() => _loading = false);
    for (final c in [_name,_desc,_brand,_size,_color,_price,_deposit]) {
      c.clear();
    }
    _minDays.text = '1'; _maxDays.text = '7';
    setState(() { _pickedImages.clear(); _category = 'Clothes'; _condition = 'Excellent'; });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Text('"${item.name}" listed successfully!')]),
        backgroundColor: kPrimary, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      final shell = context.findAncestorStateOfType<_MainShellState>();
      shell?._setTab(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        automaticallyImplyLeading: false, title: Text('List an Item', style: kH2),
        backgroundColor: Colors.white,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: kDivider)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Upload Photos *'),
            GestureDetector(
              onTap: _showPhotoSourceSheet,
              child: Container(
                height: 120,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kPrimary, width: 1.5)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: const Color(0xFF4285F4).withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.image_search_rounded, color: Color(0xFF4285F4), size: 20)),
                    const SizedBox(width: 10),
                    const Icon(Icons.photo_library_outlined, color: kPrimary, size: 22),
                    const SizedBox(width: 10),
                    const Icon(Icons.camera_alt_outlined, color: Color(0xFFFF7043), size: 22),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Tap to add photos', style: TextStyle(color: kText, fontWeight: FontWeight.w600)),
                  const Text('Google Photos · Gallery · Camera', style: TextStyle(color: kLight, fontSize: 12)),
                ]),
              ),
            ),

            if (_pickedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 10, runSpacing: 10,
                  children: _pickedImages.asMap().entries.map((e) {
                    final i = e.key; final img = e.value;
                    return Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(img.path), width: 80, height: 80, fit: BoxFit.cover)),
                      Positioned(top: -4, right: -4,
                        child: GestureDetector(
                          onTap: () => setState(() => _pickedImages.removeAt(i)),
                          child: Container(width: 22, height: 22,
                            decoration: const BoxDecoration(color: kErr, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14)),
                        )),
                    ]);
                  }).toList(),
                ),
              ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const _SectionHeader('Item Details'),
            Row(children: [
              Expanded(child: _LabelField(label: 'Item Name *', controller: _name,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Category *', style: TextStyle(fontSize: 13, color: kSub, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kDivider)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _category, isExpanded: true,
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: kH3.copyWith(fontSize: 14)))).toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                ),
              ])),
            ]),
            const SizedBox(height: 14),
            _LabelField(label: 'Description *', controller: _desc, maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 14),
            _LabelField(label: 'Brand *', controller: _brand, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _LabelField(label: 'Size (optional)', controller: _size)),
              const SizedBox(width: 12),
              Expanded(child: _LabelField(label: 'Color (optional)', controller: _color)),
            ]),
            const SizedBox(height: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Condition *', style: TextStyle(fontSize: 13, color: kSub, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: _conditions.map((c) {
                final sel = c == _condition;
                return GestureDetector(
                  onTap: () => setState(() => _condition = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? kPrimary : Colors.white, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? kPrimary : kDivider),
                    ),
                    child: Text(c, style: TextStyle(color: sel ? Colors.white : kSub, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, fontSize: 13)),
                  ),
                );
              }).toList()),
            ]),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const _SectionHeader('Pricing'),
            Row(children: [
              Expanded(child: _LabelField(label: 'Price per Day ₹ *', controller: _price, keyboardType: TextInputType.number,
                  validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid price' : null)),
              const SizedBox(width: 12),
              Expanded(child: _LabelField(label: 'Deposit ₹ *', controller: _deposit, keyboardType: TextInputType.number,
                  validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid deposit' : null)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _LabelField(label: 'Min Days', controller: _minDays, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _LabelField(label: 'Max Days', controller: _maxDays, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('List Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PHOTO SOURCE TILE
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoSourceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, subtitle;
  final VoidCallback onTap;
  const _PhotoSourceTile({required this.icon, required this.color, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.25))),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: kH3.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: kBody.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Icon(Icons.chevron_right_rounded, color: color),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  GOOGLE PHOTOS PICKER
// ─────────────────────────────────────────────────────────────────────────────
class _GooglePhotosPicker extends StatefulWidget {
  const _GooglePhotosPicker();
  @override
  State<_GooglePhotosPicker> createState() => _GooglePhotosPickerState();
}

class _GooglePhotosPickerState extends State<_GooglePhotosPicker> {
  List<GPhoto> _photos = [];
  String? _nextPageToken;
  bool _loading = false;
  bool _loadingMore = false;
  final Set<String> _selectedIds = {};
  final Map<String, GPhoto> _photoMap = {};
  final ScrollController _scroll = ScrollController();

  @override
  void initState() { super.initState(); _loadPhotos(); _scroll.addListener(_onScroll); }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _loadMore();
  }

  Future<void> _loadPhotos() async {
    setState(() => _loading = true);
    final result = await GooglePhotosService.listPhotos(pageSize: 24);
    setState(() {
      _photos = result.photos; _nextPageToken = result.nextPageToken;
      for (final p in _photos) {
        _photoMap[p.id] = p;
      }
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextPageToken == null) return;
    setState(() => _loadingMore = true);
    final result = await GooglePhotosService.listPhotos(pageSize: 24, pageToken: _nextPageToken);
    setState(() {
      _photos.addAll(result.photos); _nextPageToken = result.nextPageToken;
      for (final p in result.photos) {
        _photoMap[p.id] = p;
      }
      _loadingMore = false;
    });
  }

  void _toggle(String id) => setState(() => _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id));

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: kDivider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Row(children: [
                Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFFE8F0FE), shape: BoxShape.circle),
                  child: const Icon(Icons.image_search_rounded, color: Color(0xFF4285F4), size: 16)),
                const SizedBox(width: 8),
                Text('Google Photos', style: kH2),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selectedIds.map((id) => _photoMap[id]!).toList()),
                    style: TextButton.styleFrom(backgroundColor: kPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    child: Text('Add ${_selectedIds.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.close, color: kSub), onPressed: () => Navigator.pop(context, null)),
              ]),
              if (_selectedIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(alignment: Alignment.centerLeft,
                    child: Text('${_selectedIds.length} photo${_selectedIds.length > 1 ? 's' : ''} selected',
                        style: const TextStyle(color: kPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: kPrimary), SizedBox(height: 16),
                    Text('Loading your Google Photos…', style: TextStyle(color: kSub))]))
                : _photos.isEmpty
                    ? const Center(child: Text('No photos found in your library.', style: TextStyle(color: kSub)))
                    : GridView.builder(
                        controller: _scroll, padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                        itemCount: _photos.length + (_loadingMore ? 3 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _photos.length) return Container(color: kTile, child: const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)));
                          final photo = _photos[i];
                          final sel = _selectedIds.contains(photo.id);
                          return GestureDetector(
                            onTap: () => _toggle(photo.id),
                            child: Stack(fit: StackFit.expand, children: [
                              Image.network(photo.thumbUrl, fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) => progress == null ? child : Container(color: kTile, child: const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))),
                                errorBuilder: (_, __, ___) => Container(color: kTile, child: const Icon(Icons.broken_image_outlined, color: kLight))),
                              AnimatedContainer(duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(color: sel ? kPrimary.withOpacity(0.35) : Colors.transparent)),
                              if (sel) Positioned(top: 6, right: 6,
                                child: Container(width: 24, height: 24,
                                  decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                                  child: const Icon(Icons.check, color: Colors.white, size: 14))),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: kH3));
}

class _LabelField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _LabelField({required this.label, required this.controller, this.maxLines = 1, this.keyboardType, this.validator});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: kSub, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextFormField(controller: controller, maxLines: maxLines, keyboardType: keyboardType,
          validator: validator, style: kH3.copyWith(fontSize: 14), decoration: const InputDecoration()),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  MY ITEMS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class MyItemsScreen extends StatelessWidget {
  const MyItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final items = store.myItems;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        automaticallyImplyLeading: false, title: Text('My Items', style: kH2), backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: kPrimary), tooltip: 'List New Item',
            onPressed: () { final shell = context.findAncestorStateOfType<_MainShellState>(); shell?._setTab(1); },
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🗂️', style: TextStyle(fontSize: 56)), const SizedBox(height: 16),
              Text('No items listed', style: kH3), const SizedBox(height: 8),
              Text('Tap + to list your first item.', style: kBody), const SizedBox(height: 20),
              SizedBox(width: 180, child: ElevatedButton.icon(
                onPressed: () { final shell = context.findAncestorStateOfType<_MainShellState>(); shell?._setTab(1); },
                icon: const Icon(Icons.add), label: const Text('List Item'))),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16), itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _MyItemTile(item: items[i]),
            ),
    );
  }
}

class _MyItemTile extends StatelessWidget {
  final Item item;
  const _MyItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2))]),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 70, height: 70,
              child: item.imagePaths.isNotEmpty
                  ? _ItemImage(path: item.imagePaths.first, fit: BoxFit.cover)
                  : Container(color: kTile, child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 30)))))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: kH3, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(item.category, style: kBody),
            const SizedBox(height: 4),
            Text('₹${item.pricePerDay.toStringAsFixed(0)}/day  •  Deposit ₹${item.deposit.toStringAsFixed(0)}', style: kPrice$.copyWith(fontSize: 13)),
          ])),
          Column(children: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: kPrimary), tooltip: 'Edit',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditItemScreen(item: item)))),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: kErr), tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, store)),
          ]),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppStore store) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Item?'),
      content: Text('Remove "${item.name}" from your listings?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: kSub))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kErr, minimumSize: const Size(80, 40)),
          onPressed: () { store.removeItem(item.id); Navigator.pop(context); },
          child: const Text('Delete')),
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EDIT ITEM SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EditItemScreen extends StatefulWidget {
  final Item item;
  const EditItemScreen({super.key, required this.item});
  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late final TextEditingController _name, _desc, _brand, _size, _color, _price, _deposit, _minDays, _maxDays;
  late String _category, _condition;
  late List<String> _existingImages;
  final List<XFile> _newImages = [];
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  static const _categories = ['Clothes','Electronics','Books','Accessories','Sports','Tools','Music','Other'];
  static const _conditions = ['Brand New','Excellent','Good','Fair','Poor'];

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _name = TextEditingController(text: i.name); _desc = TextEditingController(text: i.description);
    _brand = TextEditingController(text: i.brand); _size = TextEditingController(text: i.size ?? '');
    _color = TextEditingController(text: i.color ?? ''); _price = TextEditingController(text: i.pricePerDay.toStringAsFixed(0));
    _deposit = TextEditingController(text: i.deposit.toStringAsFixed(0)); _minDays = TextEditingController(text: i.minDays.toString());
    _maxDays = TextEditingController(text: i.maxDays.toString()); _category = i.category; _condition = i.condition;
    _existingImages = List.from(i.imagePaths);
  }

  @override
  void dispose() {
    for (final c in [_name,_desc,_brand,_size,_color,_price,_deposit,_minDays,_maxDays]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final imgs = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (imgs.isNotEmpty) setState(() => _newImages.addAll(imgs));
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final updated = Item(
      id: widget.item.id, name: _name.text.trim(), category: _category,
      description: _desc.text.trim(), brand: _brand.text.trim(), condition: _condition,
      size: _size.text.trim().isEmpty ? null : _size.text.trim(),
      color: _color.text.trim().isEmpty ? null : _color.text.trim(),
      pricePerDay: double.tryParse(_price.text) ?? 0, deposit: double.tryParse(_deposit.text) ?? 0,
      minDays: int.tryParse(_minDays.text) ?? 1, maxDays: int.tryParse(_maxDays.text) ?? 7,
      imagePaths: [..._existingImages, ..._newImages.map((x) => x.path)],
      rating: widget.item.rating, reviewCount: widget.item.reviewCount, available: widget.item.available,
      createdAt: widget.item.createdAt, reviews: widget.item.reviews, bookedRanges: widget.item.bookedRanges,
    );
    StoreProvider.of(context).updateItem(updated);
    setState(() => _loading = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text('Edit Item', style: kH2), backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                : const Text('Save', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 16))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const _SectionHeader('Photos'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            ..._existingImages.asMap().entries.map((e) => Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10),
                child: _ItemImage(path: e.value, width: 80, height: 80, fit: BoxFit.cover)),
              Positioned(top: -4, right: -4, child: GestureDetector(
                onTap: () => setState(() => _existingImages.removeAt(e.key)),
                child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: kErr, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14)))),
            ])),
            ..._newImages.asMap().entries.map((e) => Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10),
                child: Image.file(File(e.value.path), width: 80, height: 80, fit: BoxFit.cover)),
              Positioned(top: -4, right: -4, child: GestureDetector(
                onTap: () => setState(() => _newImages.removeAt(e.key)),
                child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: kErr, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14)))),
            ])),
            GestureDetector(
              onTap: _pickImages,
              child: Container(width: 80, height: 80,
                decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(10), border: Border.all(color: kPrimary)),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, color: kPrimary),
                  Text('Add', style: TextStyle(color: kPrimary, fontSize: 11)),
                ]))),
          ]),
          const SizedBox(height: 20), const Divider(), const SizedBox(height: 12),
          const _SectionHeader('Item Details'),
          Row(children: [
            Expanded(child: _LabelField(label: 'Item Name *', controller: _name, validator: (v) => v!.isEmpty ? 'Required' : null)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Category *', style: TextStyle(fontSize: 13, color: kSub, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kDivider)),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _category, isExpanded: true,
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: kH3.copyWith(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _category = v!)))),
            ])),
          ]),
          const SizedBox(height: 14),
          _LabelField(label: 'Description *', controller: _desc, maxLines: 3, validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          _LabelField(label: 'Brand *', controller: _brand, validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _LabelField(label: 'Size', controller: _size)),
            const SizedBox(width: 12),
            Expanded(child: _LabelField(label: 'Color', controller: _color)),
          ]),
          const SizedBox(height: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Condition *', style: TextStyle(fontSize: 13, color: kSub, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: _conditions.map((c) {
              final sel = c == _condition;
              return GestureDetector(onTap: () => setState(() => _condition = c),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: sel ? kPrimary : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? kPrimary : kDivider)),
                  child: Text(c, style: TextStyle(color: sel ? Colors.white : kSub, fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400))));
            }).toList()),
          ]),
          const SizedBox(height: 20), const Divider(), const SizedBox(height: 12),
          const _SectionHeader('Pricing'),
          Row(children: [
            Expanded(child: _LabelField(label: 'Price/Day ₹ *', controller: _price, keyboardType: TextInputType.number,
                validator: (v) => double.tryParse(v!) == null ? 'Invalid' : null)),
            const SizedBox(width: 12),
            Expanded(child: _LabelField(label: 'Deposit ₹ *', controller: _deposit, keyboardType: TextInputType.number,
                validator: (v) => double.tryParse(v!) == null ? 'Invalid' : null)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _LabelField(label: 'Min Days', controller: _minDays, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _LabelField(label: 'Max Days', controller: _maxDays, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false, expandedHeight: 200, pinned: true, backgroundColor: kPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [kPrimary, kAccent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 20),
                  CircleAvatar(radius: 40, backgroundColor: Colors.white,
                    child: Text(store.userName.isNotEmpty ? store.userName[0].toUpperCase() : 'Y',
                        style: const TextStyle(color: kPrimary, fontSize: 32, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Text(store.userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 14), SizedBox(width: 4),
                    Text('Verified Member', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ])),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(children: [
              Container(color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(children: [
                  _StatCol('${store.myItems.length}', 'Listed'), _StatDivider(),
                  _StatCol('${store.bookings.length}', 'Bookings'), _StatDivider(),
                  _StatCol('${store.savedItems.length}', 'Saved'),
                ])),
              const SizedBox(height: 16),
              _MenuSection(title: 'My Activity', items: [
                _MenuItem(Icons.inventory_2_outlined, 'My Items', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyItemsScreen()))),
                _MenuItem(Icons.calendar_today_outlined, 'My Bookings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()))),
                _MenuItem(Icons.favorite_border_rounded, 'Saved Items', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedItemsScreen()))),
                _MenuItem(Icons.notifications_outlined, 'Notifications', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
              ]),
              const SizedBox(height: 16),
              _MenuSection(title: 'Account Details', items: [
                _MenuItem(Icons.person_outline_rounded, 'Edit Profile', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
              ]),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)]),
                child: Column(children: [
                  _AccountInfoRow(Icons.person_outline_rounded, 'Name', store.userName), const Divider(),
                  _AccountInfoRow(Icons.email_outlined, 'Email', store.userEmail), const Divider(),
                  _AccountInfoRow(Icons.phone_outlined, 'Phone', store.userPhone), const Divider(),
                  _AccountInfoRow(Icons.school_outlined, 'College', store.userCollege),
                ]),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String value, label;
  const _StatCol(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [Text(value, style: kH2), Text(label, style: kBody)]));
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 36, color: kDivider);
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(children: [const Icon(Icons.calendar_month_outlined, color: kPrimary, size: 18), const SizedBox(width: 6), Text(title, style: kH3)])),
      ...items,
    ]),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap, leading: Icon(icon, color: kSub),
    title: Text(label, style: kH3.copyWith(fontSize: 15)),
    trailing: const Icon(Icons.chevron_right_rounded, color: kLight),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
  );
}

class _AccountInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _AccountInfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Icon(icon, color: kPrimary, size: 20), const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: kPrimary, fontWeight: FontWeight.w600)),
        Text(value, style: kH3.copyWith(fontSize: 14)),
      ]),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _name, _phone, _college, _email;

  @override
  void initState() {
    super.initState();
    final store = StoreProvider.of(context);
    _name = TextEditingController(text: store.userName); _phone = TextEditingController(text: store.userPhone);
    _college = TextEditingController(text: store.userCollege); _email = TextEditingController(text: store.userEmail);
  }

  @override
  void dispose() { for (final c in [_name,_phone,_college,_email]) {
    c.dispose();
  } super.dispose(); }

  void _save(BuildContext context) {
    final store = StoreProvider.of(context);
    store.userName = _name.text.trim(); store.userPhone = _phone.text.trim();
    store.userCollege = _college.text.trim(); store.userEmail = _email.text.trim();
    store.notifyListeners(); Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Profile', style: kH2), backgroundColor: Colors.white,
        actions: [TextButton(onPressed: () => _save(context), child: const Text('Save', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 16)))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _LabelField(label: 'Name', controller: _name), const SizedBox(height: 14),
        _LabelField(label: 'Email', controller: _email), const SizedBox(height: 14),
        _LabelField(label: 'Phone', controller: _phone), const SizedBox(height: 14),
        _LabelField(label: 'College', controller: _college), const SizedBox(height: 32),
        ElevatedButton(onPressed: () => _save(context), child: const Text('Save Changes')),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MY BOOKINGS SCREEN  (Upcoming / Returns / History)
// ─────────────────────────────────────────────────────────────────────────────
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});
  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 3, vsync: this); }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  List<Booking> _upcoming(List<Booking> all) {
    final now = DateTime.now();
    return all.where((b) => b.status == 'confirmed' && b.startDate.isAfter(now)).toList();
  }

  List<Booking> _returns(List<Booking> all) {
    final now = DateTime.now();
    return all.where((b) =>
        b.status == 'active' ||
        (b.status == 'confirmed' && !b.startDate.isAfter(now) && b.endDate.isAfter(now))).toList();
  }

  List<Booking> _history(List<Booking> all) =>
      all.where((b) => b.status == 'completed' || b.status == 'cancelled').toList();

  @override
  Widget build(BuildContext context) {
    final store    = StoreProvider.of(context);
    final bookings = store.bookings;
    final upcoming = _upcoming(bookings);
    final returns  = _returns(bookings);
    final history  = _history(bookings);

    return Scaffold(
      backgroundColor: kBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 130, pinned: true,
            backgroundColor: kPrimary, foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [kPrimary, kAccent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('My Bookings', style: kH1.copyWith(color: Colors.white, fontSize: 24)),
                    const SizedBox(height: 4),
                    Text('Manage your rental items', style: kBody.copyWith(color: Colors.white70)),
                  ]),
                )),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white, indicatorWeight: 3,
              labelColor: Colors.white, unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              tabs: [
                Tab(text: upcoming.isNotEmpty ? 'Upcoming (${upcoming.length})' : 'Upcoming'),
                Tab(text: returns.isNotEmpty  ? 'Returns (${returns.length})'   : 'Returns'),
                const Tab(text: 'History'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _BookingList(bookings: upcoming, emptyIcon: '📅', emptyTitle: 'No upcoming bookings',
                emptySubtitle: 'Browse items and book something!', tabType: _BookingTabType.upcoming),
            _BookingList(bookings: returns, emptyIcon: '📦', emptyTitle: 'Nothing to return yet',
                emptySubtitle: 'Active rentals will appear here.', tabType: _BookingTabType.returns),
            _BookingList(bookings: history, emptyIcon: '🗂️', emptyTitle: 'No history yet',
                emptySubtitle: 'Completed and cancelled bookings will appear here.', tabType: _BookingTabType.history),
          ],
        ),
      ),
    );
  }
}

enum _BookingTabType { upcoming, returns, history }

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyIcon, emptyTitle, emptySubtitle;
  final _BookingTabType tabType;

  const _BookingList({required this.bookings, required this.emptyIcon,
      required this.emptyTitle, required this.emptySubtitle, required this.tabType});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emptyIcon, style: const TextStyle(fontSize: 56)), const SizedBox(height: 16),
          Text(emptyTitle, style: kH3, textAlign: TextAlign.center), const SizedBox(height: 8),
          Text(emptySubtitle, style: kBody, textAlign: TextAlign.center),
        ])));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _BookingCard(booking: bookings[i], tabType: tabType),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final _BookingTabType tabType;
  const _BookingCard({required this.booking, required this.tabType});

  @override
  Widget build(BuildContext context) {
    final store    = StoreProvider.of(context);
    final b        = booking;
    final fmt      = DateFormat('dd MMM yyyy');
    final now      = DateTime.now();
    final daysLeft = b.endDate.difference(now).inDays;
    final isOverdue = now.isAfter(b.endDate) && tabType == _BookingTabType.returns;

    return Container(
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3))],
        border: isOverdue
            ? Border.all(color: kErr.withOpacity(0.5), width: 1.5)
            : tabType == _BookingTabType.returns
                ? Border.all(color: kPrimary.withOpacity(0.3), width: 1.5)
                : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 72, height: 72,
                child: b.item.imagePaths.isNotEmpty
                    ? _ItemImage(path: b.item.imagePaths.first, fit: BoxFit.cover)
                    : Container(color: kTile, child: Center(child: Text(b.item.emoji, style: const TextStyle(fontSize: 30)))))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(b.item.name, style: kH3, maxLines: 1, overflow: TextOverflow.ellipsis)),
                _StatusBadge(b),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.person_outline_rounded, color: kPrimary, size: 14), const SizedBox(width: 4),
                Text(b.item.ownerName.isNotEmpty ? b.item.ownerName : 'You', style: kBody.copyWith(fontSize: 13)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.calendar_today_outlined, color: kPrimary, size: 14), const SizedBox(width: 4),
                Text(
                  tabType == _BookingTabType.upcoming ? 'Pickup: ${fmt.format(b.startDate)}'
                      : tabType == _BookingTabType.returns ? 'Return by: ${fmt.format(b.endDate)}'
                      : '${fmt.format(b.startDate)} → ${fmt.format(b.endDate)}',
                  style: kBody.copyWith(fontSize: 13)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined, color: kPrimary, size: 14), const SizedBox(width: 4),
                Expanded(child: Text(b.pickupLocation, style: kBody.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ])),
          ]),
        ),

        if (tabType == _BookingTabType.returns) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOverdue ? kErr.withOpacity(0.08) : daysLeft <= 1 ? kWarning.withOpacity(0.1) : kPrimary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                  color: isOverdue ? kErr : daysLeft <= 1 ? kWarning : kPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                isOverdue ? 'Overdue! Return immediately to avoid extra charges'
                    : daysLeft == 0 ? 'Due today — please return the item'
                    : daysLeft == 1 ? 'Due tomorrow — return by ${fmt.format(b.endDate)}'
                    : '$daysLeft days left — return by ${fmt.format(b.endDate)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isOverdue ? kErr : daysLeft <= 1 ? kWarning : kPrimary))),
            ]),
          ),
          const SizedBox(height: 10),
        ],

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: Row(children: [
            Text('${b.durationDays} days', style: kBody.copyWith(fontSize: 13)),
            const Spacer(),
            Text('Total: ', style: kBody.copyWith(fontSize: 13)),
            Text('₹${b.total.toStringAsFixed(0)}', style: kPrice$.copyWith(fontSize: 15)),
          ]),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1, indent: 14, endIndent: 14),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: _ActionButtons(booking: b, tabType: tabType, store: store),
        ),
      ]),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Booking booking;
  final _BookingTabType tabType;
  final AppStore store;
  const _ActionButtons({required this.booking, required this.tabType, required this.store});

  @override
  Widget build(BuildContext context) {
    switch (tabType) {
      case _BookingTabType.upcoming:
        return Row(children: [
          Expanded(child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: kErr), foregroundColor: kErr,
                minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => store.cancelBooking(booking.id),
            child: const Text('Cancel'))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { booking.status = 'active'; store.notifyListeners(); },
            child: const Text('Confirm Pickup'))),
        ]);

      case _BookingTabType.returns:
        return SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.assignment_return_outlined, size: 18),
            label: const Text('Mark as Returned'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => store.completeBooking(booking.id)));

      case _BookingTabType.history:
        return Row(children: [
          Icon(booking.status == 'completed' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
              color: booking.status == 'completed' ? Colors.green : kErr, size: 16),
          const SizedBox(width: 6),
          Text(
            booking.status == 'completed' ? 'Returned on ${DateFormat('dd MMM yyyy').format(booking.endDate)}' : 'Cancelled',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: booking.status == 'completed' ? Colors.green : kErr)),
        ]);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final Booking booking;
  const _StatusBadge(this.booking);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: booking.statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(booking.statusLabel, style: TextStyle(color: booking.statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SAVED ITEMS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SavedItemsScreen extends StatelessWidget {
  const SavedItemsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final saved = store.savedItems;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text('Saved Items', style: kH2), backgroundColor: Colors.white),
      body: saved.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('❤️', style: TextStyle(fontSize: 56)), const SizedBox(height: 16),
              Text('No saved items yet', style: kH3), const SizedBox(height: 8),
              Text('Tap ♡ on any item to save it.', style: kBody)]))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
              itemCount: saved.length,
              itemBuilder: (_, i) => _ItemCard(item: saved[i])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATIONS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store  = StoreProvider.of(context);
    final notifs = store.notifications;
    final fmt    = DateFormat('dd MMM • hh:mm a');
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text('Notifications', style: kH2), backgroundColor: Colors.white,
        actions: [if (store.unreadCount > 0) TextButton(onPressed: store.markAllRead, child: const Text('Mark all read', style: TextStyle(color: kPrimary)))]),
      body: notifs.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔔', style: TextStyle(fontSize: 56)), const SizedBox(height: 16),
              Text('No notifications', style: kH3)]))
          : ListView.separated(
              padding: const EdgeInsets.all(16), itemCount: notifs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = notifs[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.read ? Colors.white : kTile, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: n.read ? kDivider : kPrimary.withOpacity(0.3))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 40, height: 40, decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_outlined, color: kPrimary, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.title, style: kH3.copyWith(fontSize: 14)), const SizedBox(height: 3),
                      Text(n.message, style: kBody), const SizedBox(height: 4),
                      Text(fmt.format(n.createdAt), style: const TextStyle(fontSize: 11, color: kLight)),
                    ])),
                    if (!n.read) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle)),
                  ]),
                );
              }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPER: Image renderer
// ─────────────────────────────────────────────────────────────────────────────
class _ItemImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width, height;
  const _ItemImage({required this.path, this.fit = BoxFit.cover, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (path.startsWith('/') || path.startsWith('file://')) {
      img = Image.file(File(path.replaceFirst('file://', '')), fit: fit, width: width, height: height,
          errorBuilder: (_, __, ___) => _placeholder());
    } else if (path.startsWith('http')) {
      img = Image.network(path, fit: fit, width: width, height: height,
          errorBuilder: (_, __, ___) => _placeholder());
    } else {
      img = _placeholder();
    }
    return SizedBox(width: width, height: height, child: img);
  }

  Widget _placeholder() => Container(color: kTile, child: const Center(child: Icon(Icons.image_outlined, color: kLight, size: 32)));
}