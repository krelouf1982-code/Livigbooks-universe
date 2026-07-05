
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'story_generator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const LivingBooksUniverse(),
    ),
  );
}


// =================| Data Models |=================

class BookModel {
  final int? id;
  final String title;
  final Color coverColor;
  final List<String> pages;
  final LanguageCode language;

  BookModel({
    this.id,
    required this.title,
    required this.coverColor,
    required this.pages,
    required this.language,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'coverColor': coverColor.value,
      'pages': pages.join('|||'),
      'language': language.index,
    };
  }

  factory BookModel.fromMap(Map<String, dynamic> map) {
    return BookModel(
      id: map['id'],
      title: map['title'],
      coverColor: Color(map['coverColor'] as int),
      pages: (map['pages'] as String).split('|||'),
      language: LanguageCode.values[map['language'] as int],
    );
  }
}

class BookProgress {
  final int bookId;
  int currentPage;
  List<int> bookmarks;
  double progress;
  String? lastTranslation;

  BookProgress({
    required this.bookId,
    this.currentPage = 0,
    this.bookmarks = const [],
    this.progress = 0.0,
    this.lastTranslation,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'currentPage': currentPage,
      'bookmarks': bookmarks.join(','),
      'progress': progress,
      'lastTranslation': lastTranslation,
    };
  }

  factory BookProgress.fromMap(Map<String, dynamic> map) {
    return BookProgress(
      bookId: map['bookId'],
      currentPage: map['currentPage'],
      bookmarks: (map['bookmarks'] as String).split(',').where((e) => e.isNotEmpty).map(int.parse).toList(),
      progress: map['progress'],
      lastTranslation: map['lastTranslation'],
    );
  }
}
// =================| SQLite Database |=================

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'books.db');
    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
        await _insertDefaultBooks(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE progress ADD COLUMN lastTranslation TEXT');
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        coverColor INTEGER,
        pages TEXT,
        language INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS progress (
        bookId INTEGER PRIMARY KEY,
        currentPage INTEGER,
        bookmarks TEXT,
        progress REAL,
        lastTranslation TEXT
      )
    ''');
  }

  Future<void> _insertDefaultBooks(Database db) async {
    final defaults = [
      BookModel(
        title: "Alaa and the Dragon",
        coverColor: const Color(0xFF4A1521),
        language: LanguageCode.ar,
        pages: ["Alaa woke up one morning...", "She decided to climb the mountain.", "And found the dragon sleeping.", "She gently woke him up.", "They flew together in the sky."],
      ),
      BookModel(
        title: "Space Voyager",
        coverColor: const Color(0xFF1A2E40),
        language: LanguageCode.en,
        pages: ["The rocket blasted off...", "Stars twinkled like diamonds.", "They reached a new galaxy.", "Aliens greeted them warmly.", "They shared knowledge and returned home."],
      ),
      BookModel(
        title: "The Lost Legend",
        coverColor: const Color(0xFF2E4A62),
        language: LanguageCode.ar,
        pages: ["In ancient times...", "There was a hidden kingdom.", "Guarded by an old dragon.", "The golden key was lost.", "The search journey began."],
      ),
      BookModel(
        title: "The Future Traveler",
        coverColor: const Color(0xFF3A7A3A),
        language: LanguageCode.en,
        pages: ["A time machine was invented.", "The traveler went to 3025.", "Cities floated in the sky.", "Robots and humans lived in peace.", "He brought back a message of hope."],
      ),
    ];

    for (final book in defaults) {
      await db.insert('books', book.toMap());
    }
  }

  Future<List<BookModel>> getBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return maps.map((map) => BookModel.fromMap(map)).toList();
  }

  Future<BookProgress?> getProgress(int bookId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'progress',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    if (maps.isEmpty) return null;
    return BookProgress.fromMap(maps.first);
  }

  Future<void> saveProgress(BookProgress progress) async {
    final db = await database;
    await db.insert(
      'progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProgress(int bookId) async {
    final db = await database;
    await db.delete('progress', where: 'bookId = ?', whereArgs: [bookId]);
  }

  Future<void> insertBook(BookModel book) async {
    final db = await database;
    await db.insert('books', book.toMap());
  }
}

// =================| Audio Engine |=================

class AudioEngine {
  static final AudioEngine _instance = AudioEngine._internal();
  factory AudioEngine() => _instance;
  AudioEngine._internal();

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _isPlayingMusic = false;
  bool _isNarrating = false;
  VoidCallback? _onCompleteCallback;

  Future<void> init() async {
    _tts.setCompletionHandler(() {
      _isNarrating = false;
      _onCompleteCallback?.call();
      _onCompleteCallback = null;
    });
    _tts.setCancelHandler(() {
      _isNarrating = false;
    });
  }

  Future<void> playBackgroundMusic() async {
    if (!_isPlayingMusic) {
      try {
        await _player.play(AssetSource('music/ambient.mp3'));
        _isPlayingMusic = true;
        debugPrint("Background music started.");
      } catch (e) {
        debugPrint("Music error: $e");
      }
    }
  }

  Future<void> playPageFlipSound(bool isFast) async {
    try {
      final source = AssetSource(isFast ? 'sounds/page_flip_fast.mp3' : 'sounds/page_flip.mp3');
      await _player.play(source);
      debugPrint("Page flip ${isFast ? 'fast' : 'slow'}.");
    } catch (e) {
      debugPrint("Sound error: $e");
    }
  }

  Future<void> speakText(String text, String langCode, {VoidCallback? onComplete}) async {
    await _tts.setLanguage(langCode);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);
    
    _onCompleteCallback = onComplete;
    
    await _tts.speak(text);
    _isNarrating = true;
    debugPrint("TTS speaking: $text");
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isNarrating = false;
    _onCompleteCallback = null;
  }

  Future<void> toggleNarration(String text, String langCode, {VoidCallback? onComplete}) async {
    if (_isNarrating) {
      await stopSpeaking();
    } else {
      await speakText(text, langCode, onComplete: onComplete);
    }
  }

  Future<void> stopAllSounds() async {
    await _player.stop();
    await stopSpeaking();
    _isPlayingMusic = false;
  }

  void dispose() {
    _player.dispose();
    _tts.stop();
  }
}
// =================| Translation Service |=================

class TranslationService {
  final Map<String, String> _cache = {};

  Future<String> translate(String text, String targetLang) async {
    try {
      final response = await http.post(
        Uri.parse('https://libretranslate.de/translate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'q': text,
          'source': 'auto',
          'target': targetLang,
          'format': 'text',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['translatedText'] ?? text;
      }
      return text;
    } catch (e) {
      debugPrint("Translation error: $e");
      return text;
    }
  }

  Future<String> translateCached(String text, String targetLang) async {
    final key = '$text|$targetLang';
    _cache[key] ??= await translate(text, targetLang);
    return _cache[key]!;
  }
}

// =================| Language System |=================

enum LanguageCode { ar, en, fr, es, zh, hi, pt, ru, de, ja, ko, it, tr, ur }

extension LangExt on LanguageCode {
  String get name {
    switch (this) {
      case LanguageCode.ar: return 'Arabic';
      case LanguageCode.en: return 'English';
      case LanguageCode.fr: return 'French';
      case LanguageCode.es: return 'Spanish';
      case LanguageCode.zh: return 'Chinese';
      case LanguageCode.hi: return 'Hindi';
      case LanguageCode.pt: return 'Portuguese';
      case LanguageCode.ru: return 'Russian';
      case LanguageCode.de: return 'German';
      case LanguageCode.ja: return 'Japanese';
      case LanguageCode.ko: return 'Korean';
      case LanguageCode.it: return 'Italian';
      case LanguageCode.tr: return 'Turkish';
      case LanguageCode.ur: return 'Urdu';
    }
  }

  String get ttsCode {
    switch (this) {
      case LanguageCode.ar: return 'ar-SA';
      case LanguageCode.en: return 'en-US';
      case LanguageCode.fr: return 'fr-FR';
      case LanguageCode.es: return 'es-ES';
      case LanguageCode.zh: return 'zh-CN';
      case LanguageCode.hi: return 'hi-IN';
      case LanguageCode.pt: return 'pt-PT';
      case LanguageCode.ru: return 'ru-RU';
      case LanguageCode.de: return 'de-DE';
      case LanguageCode.ja: return 'ja-JP';
      case LanguageCode.ko: return 'ko-KR';
      case LanguageCode.it: return 'it-IT';
      case LanguageCode.tr: return 'tr-TR';
      case LanguageCode.ur: return 'ur-PK';
    }
  }

  String get googleTranslateCode {
    switch (this) {
      case LanguageCode.ar: return 'ar';
      case LanguageCode.en: return 'en';
      case LanguageCode.fr: return 'fr';
      case LanguageCode.es: return 'es';
      case LanguageCode.zh: return 'zh';
      case LanguageCode.hi: return 'hi';
      case LanguageCode.pt: return 'pt';
      case LanguageCode.ru: return 'ru';
      case LanguageCode.de: return 'de';
      case LanguageCode.ja: return 'ja';
      case LanguageCode.ko: return 'ko';
      case LanguageCode.it: return 'it';
      case LanguageCode.tr: return 'tr';
      case LanguageCode.ur: return 'ur';
    }
  }
}


// =================| App State |=================

class AppState extends ChangeNotifier {
  bool isNightMode = false;
  RoomType currentRoom = RoomType.royalLibrary;
  LanguageCode bookLang = LanguageCode.ar;
  LanguageCode transLang = LanguageCode.en;
  double fontSize = 20.0;
  bool slowNarration = false;
  bool isNarrating = false;
  bool isFullScreen = false;

  void toggleNightMode() {
    isNightMode = !isNightMode;
    notifyListeners();
  }

  void setRoom(RoomType room) {
    currentRoom = room;
    notifyListeners();
  }

  void setBookLang(LanguageCode lang) {
    bookLang = lang;
    notifyListeners();
  }

  void setTransLang(LanguageCode lang) {
    transLang = lang;
    notifyListeners();
  }

  void setFontSize(double size) {
    fontSize = size;
    notifyListeners();
  }

  void toggleSlowNarration() {
    slowNarration = !slowNarration;
    notifyListeners();
  }

  void setNarrating(bool value) {
    isNarrating = value;
    notifyListeners();
  }

  void toggleFullScreen() {
    isFullScreen = !isFullScreen;
    notifyListeners();
  }

  Future<void> checkAutoNightMode() async {
    final prefs = await SharedPreferences.getInstance();
    final autoNight = prefs.getBool('autoNight') ?? false;
    if (autoNight) {
      final hour = DateTime.now().hour;
      final shouldBeNight = hour < 6 || hour > 18;
      if (shouldBeNight != isNightMode) {
        isNightMode = shouldBeNight;
        notifyListeners();
      }
    }
  }
}

// =================| Main App |=================

class LivingBooksUniverse extends StatelessWidget {
  const LivingBooksUniverse({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Living Books Universe',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1610),
      ),
      home: const UniverseController(),
    );
  }
}

// =================| Main Controller |=================

enum RoomType { royalLibrary, spaceStation, snowyCabin }

class UniverseController extends StatefulWidget {
  const UniverseController({super.key});
  @override
  State<UniverseController> createState() => _UniverseControllerState();
}

class _UniverseControllerState extends State<UniverseController> {
  final DatabaseHelper _db = DatabaseHelper();
  final AudioEngine _audio = AudioEngine();

  List<BookModel> _libraryBooks = [];
  bool _isLoadingBooks = true;
  BookModel? _activeBook;

  @override
  void initState() {
    super.initState();
    _audio.init();
    _audio.playBackgroundMusic();
    _loadLibrary();
    Provider.of<AppState>(context, listen: false).checkAutoNightMode();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final books = await _db.getBooks();
    if (mounted) {
      setState(() {
        _libraryBooks = books;
        _isLoadingBooks = false;
      });
    }
  }

  void _navigateToStoryGenerator() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StoryGeneratorScreen()));
  }

  Future<void> _uploadBook() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );
      if (result == null || !mounted) return;

      final file = result.files.first;
      final fileName = p.basename(file.name);
      final bytes = file.bytes;
      if (bytes == null) return;

      if (!fileName.toLowerCase().endsWith('.txt')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsupported file type. Please upload TXT only.')),
        );
        return;
      }

      String fullText = utf8.decode(bytes);
      final words = fullText.split(RegExp(r'\s+'));
      const wordsPerPage = 300;
      List<String> pages = [];
      for (int i = 0; i < words.length; i += wordsPerPage) {
        final end = (i + wordsPerPage < words.length) ? i + wordsPerPage : words.length;
        pages.add(words.sublist(i, end).join(' '));
      }
      if (pages.isEmpty) pages = ['Empty content'];

      final random = math.Random();
      final coverColor = Color.fromRGBO(
        50 + random.nextInt(100),
        30 + random.nextInt(80),
        20 + random.nextInt(60),
        1.0,
      );
      final newBook = BookModel(
        title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
        coverColor: coverColor,
        language: LanguageCode.en,
        pages: pages,
      );

      await _db.insertBook(newBook);
      final updatedBooks = await _db.getBooks();
      if (mounted) {
        setState(() => _libraryBooks = updatedBooks);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Book "${newBook.title}" uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading book: $e')),
        );
      }
    }
  }

  void _navigateToSimulator() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BookSimulatorScreen()));
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: WoodenDeskPainter(roomType: appState.currentRoom)),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: LivingParticlesPainter(roomType: appState.currentRoom),
            ),
          ),
          Positioned.fill(
            child: AmbientLightingOverlay(roomType: appState.currentRoom),
          ),
          if (appState.isNightMode)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.5,
                    colors: [Colors.transparent, Colors.black.withAlpha(217)],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),
          if (_activeBook == null)
            MuseumLibraryView(
              books: _libraryBooks,
              isLoading: _isLoadingBooks,
              onOpenBook: (b) async {
                setState(() => _activeBook = b);
              },
              onDreamBook: _navigateToStoryGenerator,
              onUploadBook: _uploadBook,
            )
          else
            ImmersiveReaderView(
              book: _activeBook!,
              onClose: () => setState(() => _activeBook = null),
              audioEngine: _audio,
              translationService: TranslationService(),
              databaseHelper: _db,
            ),
          Positioned(
            top: 40,
            right: 40,
            child: BrassLampToggle(
              isNightMode: appState.isNightMode,
              onToggle: appState.toggleNightMode,
            ),
          ),
          if (_activeBook == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SettingsRibbon(
                onTap: _navigateToSimulator,
                onLongPress: _showSettingsDialog,
              ),
            ),
          Positioned(
            bottom: 40,
            left: 40,
            child: RoomSwitcher(
              currentRoom: appState.currentRoom,
              onChanged: appState.setRoom,
            ),
          ),
          if (_activeBook != null)
            Positioned(
              bottom: 120,
              right: 40,
              child: IconButton(
                icon: Icon(appState.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                color: const Color(0xFFD4AF37),
                onPressed: appState.toggleFullScreen,
              ),
            ),
        ],
      ),
    );
  }
}
// =================| Library View |=================

class MuseumLibraryView extends StatelessWidget {
  final List<BookModel> books;
  final bool isLoading;
  final Function(BookModel) onOpenBook;
  final VoidCallback onDreamBook;
  final VoidCallback onUploadBook;

  const MuseumLibraryView({
    super.key,
    required this.books,
    required this.isLoading,
    required this.onOpenBook,
    required this.onDreamBook,
    required this.onUploadBook,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 300,
          child: CustomPaint(painter: LibraryShelfPainter()),
        ),
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          height: 200,
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: books.map((b) => _buildBook(b, () => onOpenBook(b))).toList(),
                ),
        ),
        Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Text(
                "Library of Ages",
                style: TextStyle(fontSize: 40, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onUploadBook,
                    icon: const Icon(Icons.upload_file, color: Color(0xFFD4AF37)),
                    label: const Text("Upload Book", style: TextStyle(color: Color(0xFFD4AF37))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black54,
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: onDreamBook,
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37)),
                    label: const Text("Create with AI", style: TextStyle(color: Color(0xFFD4AF37))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black54,
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const LanguageCompass(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBook(BookModel book, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: book.title,
        child: Container(
          width: 80,
          height: 200,
          decoration: BoxDecoration(
            color: book.coverColor,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(5), bottomRight: Radius.circular(5)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(153), blurRadius: 10, offset: const Offset(5, 5))],
          ),
          child: RotatedBox(
            quarterTurns: 3,
            child: Center(
              child: Text(
                book.title,
                style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// =================| Language Compass |=================

class LanguageCompass extends StatelessWidget {
  const LanguageCompass({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(102),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withAlpha(128)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDropdown("Book Language", appState.bookLang, (l) => Provider.of<AppState>(context, listen: false).setBookLang(l)),
          const Icon(Icons.swap_horiz, color: Color(0xFFD4AF37)),
          _buildDropdown("Translation", appState.transLang, (l) => Provider.of<AppState>(context, listen: false).setTransLang(l)),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, LanguageCode current, ValueChanged<LanguageCode> onChanged) {
    return PopupMenuButton<LanguageCode>(
      color: const Color(0xFF2E1E14),
      onSelected: onChanged,
      itemBuilder: (context) => LanguageCode.values.map((l) {
        return PopupMenuItem(
          value: l,
          child: Text(
            l.name,
            style: TextStyle(color: l == current ? const Color(0xFFD4AF37) : Colors.white),
          ),
        );
      }).toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          Text(current.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
        ],
      ),
    );
  }
}
// =================| Immersive Reader |=================

class ImmersiveReaderView extends StatefulWidget {
  final BookModel book;
  final VoidCallback onClose;
  final AudioEngine audioEngine;
  final TranslationService translationService;
  final DatabaseHelper databaseHelper;

  const ImmersiveReaderView({
    super.key,
    required this.book,
    required this.onClose,
    required this.audioEngine,
    required this.translationService,
    required this.databaseHelper,
  });

  @override
  State<ImmersiveReaderView> createState() => _ImmersiveReaderViewState();
}

class _ImmersiveReaderViewState extends State<ImmersiveReaderView>
    with TickerProviderStateMixin {
  late AnimationController _popUpController;
  late AnimationController _dragController;
  double _dragValue = 0.0;
  bool _isDragging = false;
  int _currentPage = 0;
  bool _isRecording = false;
  bool _isTranslating = false;
  String _translatedText = '';
  BookProgress? _progress;
  bool _isBookmarked = false;

  final List<Color> _pageColors = [
    const Color(0xFFFFFDD0),
    const Color(0xFFFAF0E6),
    const Color(0xFFFFE4B5),
    const Color(0xFFFAF0E6),
  ];

  @override
  void initState() {
    super.initState();
    _popUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dragController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadProgress();
  }

  @override
  void dispose() {
    _popUpController.dispose();
    _dragController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    if (widget.book.id == null) return;
    final progress = await widget.databaseHelper.getProgress(widget.book.id!);
    setState(() {
      _progress = progress;
      if (progress != null) {
        _currentPage = progress.currentPage;
        _isBookmarked = progress.bookmarks.contains(_currentPage);
        _translatedText = progress.lastTranslation ?? '';
      }
    });
  }

  Future<void> _saveProgress() async {
    if (widget.book.id == null) return;
    final progress = BookProgress(
      bookId: widget.book.id!,
      currentPage: _currentPage,
      bookmarks: _progress?.bookmarks ?? [],
      progress: _currentPage / widget.book.pages.length,
      lastTranslation: _translatedText.isNotEmpty ? _translatedText : null,
    );
    await widget.databaseHelper.saveProgress(progress);
    setState(() => _progress = progress);
  }

  void _toggleBookmark() {
    if (_progress == null) {
      _progress = BookProgress(bookId: widget.book.id!);
    }
    final bookmarks = List<int>.from(_progress!.bookmarks);
    if (_isBookmarked) {
      bookmarks.remove(_currentPage);
    } else {
      bookmarks.add(_currentPage);
    }
    _progress!.bookmarks = bookmarks;
    _isBookmarked = !_isBookmarked;
    widget.databaseHelper.saveProgress(_progress!);
    setState(() {});
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragValue += (details.delta.dx / 300) * -1;
      _dragValue = _dragValue.clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) async {
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_dragValue > 0.5 || velocity.abs() > 300) {
      if (velocity < 0 && _currentPage > 0) {
        _currentPage--;
        await widget.audioEngine.playPageFlipSound(true);
        _popUpController.reset();
        _popUpController.forward();
        _translatedText = '';
        await _saveProgress();
      } else if (velocity >= 0 && _currentPage < widget.book.pages.length - 1) {
        _currentPage++;
        await widget.audioEngine.playPageFlipSound(true);
        _popUpController.reset();
        _popUpController.forward();
        _translatedText = '';
        await _saveProgress();
      }
      _dragController.forward(from: _dragValue);
    } else {
      _dragController.reverse(from: _dragValue);
    }
    setState(() => _isDragging = false);
  }

  Future<void> _toggleTranslation() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (_translatedText.isEmpty) {
      setState(() => _isTranslating = true);
      final text = widget.book.pages[_currentPage];
      final targetLang = appState.transLang.googleTranslateCode;
      final translated = await widget.translationService.translateCached(text, targetLang);
      if (mounted) {
        setState(() {
          _translatedText = translated;
          _isTranslating = false;
        });
        await _saveProgress();
      }
    } else {
      setState(() => _translatedText = '');
      await _saveProgress();
    }
  }
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    double angle = _isDragging ? _dragValue * math.pi : _dragController.value * math.pi;
    bool isArabic = appState.bookLang == LanguageCode.ar;
    double bookWidth = MediaQuery.of(context).size.width * 0.8;
    double bookHeight = bookWidth * 0.65;

    if (appState.isFullScreen) {
      bookWidth = MediaQuery.of(context).size.width * 0.95;
      bookHeight = MediaQuery.of(context).size.height * 0.85;
    }

    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      bookWidth = MediaQuery.of(context).size.width * 0.6;
      bookHeight = bookWidth * 0.7;
    }

    final displayText = _translatedText.isNotEmpty ? _translatedText : widget.book.pages[_currentPage];
    final hasNextPage = _currentPage < widget.book.pages.length - 1;
    final nextPageText = hasNextPage ? widget.book.pages[_currentPage + 1] : '';

    return Stack(
      children: [
        Center(
          child: GestureDetector(
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            child: Container(
              width: bookWidth,
              height: bookHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF4A1521),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(204), blurRadius: 30, offset: const Offset(0, 15))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: bookWidth / 2,
                      child: Container(
                        color: _pageColors[_currentPage % 4],
                        child: _PageText(
                          text: displayText,
                          isArabic: isArabic && _translatedText.isEmpty,
                          fontSize: appState.fontSize,
                        ),
                      ),
                    ),
                    if (hasNextPage)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: bookWidth / 2,
                        child: Container(
                          color: _pageColors[(_currentPage + 1) % 4],
                          child: _PageText(
                            text: nextPageText,
                            isArabic: isArabic,
                            fontSize: appState.fontSize,
                          ),
                        ),
                      ),
                    if (angle > 0.01 && angle < math.pi - 0.01)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Transform(
                          alignment: Alignment.centerLeft,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.002)
                            ..rotateY(-angle),
                          child: Container(
                            width: bookWidth / 2,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: _pageColors[_currentPage % 4],
                              border: const Border(left: BorderSide(color: Colors.grey, width: 1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((102 * (angle / math.pi)).toInt()),
                                  blurRadius: 20,
                                  offset: const Offset(-5, 0),
                                ),
                              ],
                            ),
                            child: _isTranslating
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                                : _PageText(
                                    text: displayText,
                                    isArabic: isArabic && _translatedText.isEmpty,
                                    fontSize: appState.fontSize,
                                  ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: bookWidth / 2 - 10,
                      top: 0,
                      bottom: 0,
                      width: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withAlpha(102),
                              Colors.transparent,
                              Colors.black.withAlpha(102),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: AnimatedBuilder(
                        animation: _popUpController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 0.5 + (_popUpController.value * 0.5),
                            child: Opacity(
                              opacity: _popUpController.value,
                              child: const Icon(Icons.local_fire_department, size: 80, color: Colors.deepOrange),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: LeatherCoverPainter()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 4,
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / widget.book.pages.length,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
            ),
          ),
        ),
        Positioned(
          top: 50,
          right: 50,
          child: GestureDetector(
            onTap: _toggleTranslation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _translatedText.isNotEmpty ? const Color(0xFFD4AF37) : Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD4AF37)),
              ),
              child: Row(
                children: [
                  Icon(Icons.translate, color: _translatedText.isNotEmpty ? Colors.black : Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _translatedText.isNotEmpty ? appState.transLang.name : 'Translate',
                    style: TextStyle(color: _translatedText.isNotEmpty ? Colors.black : Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: 50,
          child: GestureDetector(
            onTap: _toggleBookmark,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isBookmarked ? const Color(0xFFD4AF37) : Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37)),
              ),
              child: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          top: 50,
          left: 50,
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 120,
          bottom: 120,
          child: IndexTabRail(
            currentPage: _currentPage,
            totalPages: widget.book.pages.length,
            onPageSelected: (page) {
              setState(() {
                _currentPage = page;
                _translatedText = '';
              });
              _saveProgress();
            },
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _isRecording = !_isRecording);
                  if (_isRecording && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recording is under development...')),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : const Color(0xFF8B7355),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isRecording)
                        BoxShadow(
                          color: Colors.red.withAlpha(128),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                    ],
                  ),
                  child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white),
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () async {
                  if (!mounted) return;
                  final appState = Provider.of<AppState>(context, listen: false);
                  if (appState.isNarrating) {
                    await widget.audioEngine.stopSpeaking();
                    appState.setNarrating(false);
                  } else {
                    final text = _translatedText.isNotEmpty ? _translatedText : widget.book.pages[_currentPage];
                    await widget.audioEngine.speakText(
                      text,
                      appState.bookLang.ttsCode,
                      onComplete: () {
                        if (mounted) appState.setNarrating(false);
                      },
                    );
                    appState.setNarrating(true);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: appState.isNarrating ? 200 : 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: appState.isNarrating ? const Color(0xFF1B5E20) : Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFD4AF37)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(
                        appState.isNarrating ? Icons.stop : Icons.record_voice_over,
                        color: Colors.white,
                      ),
                      if (appState.isNarrating)
                        ...List.generate(
                          5,
                          (index) => _AudioBar(
                            index: index,
                            isSlow: appState.slowNarration,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => Provider.of<AppState>(context, listen: false).toggleSlowNarration(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: appState.slowNarration ? const Color(0xFF1B5E20) : Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: appState.slowNarration ? Colors.green : const Color(0xFFD4AF37),
                    ),
                  ),
                  child: Icon(
                    Icons.slow_motion_video,
                    color: appState.slowNarration ? Colors.green[100] : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
// =================| Helper Components |=================

class _PageText extends StatelessWidget {
  final String text;
  final bool isArabic;
  final double fontSize;

  const _PageText({
    required this.text,
    required this.isArabic,
    this.fontSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Align(
        alignment: isArabic ? Alignment.topRight : Alignment.topLeft,
        child: Text(
          text,
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.brown[900],
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _AudioBar extends StatefulWidget {
  final int index;
  final bool isSlow;
  const _AudioBar({required this.index, required this.isSlow});

  @override
  State<_AudioBar> createState() => _AudioBarState();
}

class _AudioBarState extends State<_AudioBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isSlow ? 1000 : 300 + (widget.index * 50)),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AudioBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.isSlow != oldWidget.isSlow) {
      _controller.duration = Duration(milliseconds: widget.isSlow ? 1000 : 300 + (widget.index * 50));
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (c, w) => Container(
        width: 4,
        height: 10 + (20 * _controller.value),
        color: const Color(0xFFD4AF37),
      ),
    );
  }
}
// =================| Book Simulator Screen |=================

class BookSimulatorScreen extends StatelessWidget {
  const BookSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: WoodenDeskPainter(roomType: appState.currentRoom)),
          ),
          if (appState.isNightMode)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.5,
                    colors: [Colors.transparent, Colors.black.withAlpha(217)],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),
          const Center(child: SimpleBookViewport()),
          Positioned(
            top: 40,
            right: 40,
            child: BrassLampToggle(
              isNightMode: appState.isNightMode,
              onToggle: appState.toggleNightMode,
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SettingsRibbon(onTap: null),
          ),
          const Positioned(
            right: 0,
            top: 120,
            bottom: 120,
            child: IndexTabRail(
              currentPage: 0,
              totalPages: 6,
              onPageSelected: null,
            ),
          ),
          Positioned(
            top: 40,
            left: 40,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SimpleBookViewport extends StatefulWidget {
  const SimpleBookViewport({super.key});

  @override
  State<SimpleBookViewport> createState() => _SimpleBookViewportState();
}

class _SimpleBookViewportState extends State<SimpleBookViewport>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragValue = 0.0;
  bool _isDragging = false;
  int _currentPage = 0;

  final List<Color> _pageColors = [
    const Color(0xFFFFFDD0),
    const Color(0xFFFAF0E6),
    const Color(0xFFFFE4B5),
    const Color(0xFFFAF0E6),
    const Color(0xFFFFFDD0),
    const Color(0xFFFAF0E6),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragValue += (details.delta.dx / 300) * -1;
      _dragValue = _dragValue.clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_dragValue > 0.5 || velocity.abs() > 300) {
      if (velocity < 0 && _currentPage > 0) {
        _currentPage--;
      } else if (velocity >= 0 && _currentPage < _pageColors.length - 1) {
        _currentPage++;
      }
      _controller.forward(from: _dragValue);
    } else {
      _controller.reverse(from: _dragValue);
    }
    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    double angle = _isDragging ? _dragValue * math.pi : _controller.value * math.pi;
    double bookWidth = MediaQuery.of(context).size.width * 0.7;
    double bookHeight = bookWidth * 0.65;

    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      bookWidth = MediaQuery.of(context).size.width * 0.5;
      bookHeight = bookWidth * 0.7;
    }

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Container(
        width: bookWidth,
        height: bookHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF4A1521),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(204),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: bookWidth / 2,
                child: Container(
                  color: _pageColors[_currentPage],
                  child: Center(
                    child: Text(
                      "Page ${_currentPage + 1}",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: bookWidth / 2,
                child: Container(
                  color: _currentPage + 1 < _pageColors.length ? _pageColors[_currentPage + 1] : Colors.white,
                  child: Center(
                    child: Text(
                      _currentPage + 1 < _pageColors.length ? "Page ${_currentPage + 2}" : '',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                  ),
                ),
              ),
              if (angle > 0.01 && angle < math.pi - 0.01)
                Align(
                  alignment: Alignment.centerRight,
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateY(-angle),
                    child: Container(
                      width: bookWidth / 2,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: _pageColors[_currentPage],
                        border: const Border(left: BorderSide(color: Colors.grey, width: 1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((102 * (angle / math.pi)).toInt()),
                            blurRadius: 20,
                            offset: const Offset(-5, 0),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "Page ${_currentPage + 1}",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: bookWidth / 2 - 10,
                top: 0,
                bottom: 0,
                width: 20,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withAlpha(102),
                        Colors.transparent,
                        Colors.black.withAlpha(102),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// =================| Shared Components |=================

class BrassLampToggle extends StatelessWidget {
  final bool isNightMode;
  final VoidCallback onToggle;
  const BrassLampToggle({super.key, required this.isNightMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isNightMode ? const Color(0xFFD4AF37) : const Color(0xFF8B7355),
          boxShadow: [
            if (isNightMode)
              BoxShadow(
                color: const Color(0xFFFFD180).withAlpha(153),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            BoxShadow(
              color: Colors.black.withAlpha(128),
              blurRadius: 5,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Icon(
          isNightMode ? Icons.lightbulb : Icons.lightbulb_outline,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class SettingsRibbon extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const SettingsRibbon({super.key, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 40,
          height: 80,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF8B0000),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(102),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.drag_handle, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }
}

class IndexTabRail extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int>? onPageSelected;

  const IndexTabRail({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  static const List<Color> _tabColors = [
    Color(0xFFD32F2F),
    Color(0xFFE64A19),
    Color(0xFF1976D2),
    Color(0xFF388E3C),
    Color(0xFFFBC02D),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(math.min(5, totalPages), (index) {
        final pageIndex = (currentPage ~/ 5) * 5 + index;
        if (pageIndex >= totalPages) return const SizedBox.shrink();

        final isActive = pageIndex == currentPage;
        return GestureDetector(
          onTap: () => onPageSelected?.call(pageIndex),
          child: Container(
            width: 30,
            height: 50,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : _tabColors[index],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(-1, 1)),
              ],
            ),
            child: Center(
              child: Text(
                '${pageIndex + 1}',
                style: TextStyle(
                  color: isActive ? _tabColors[index] : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class RoomSwitcher extends StatelessWidget {
  final RoomType currentRoom;
  final ValueChanged<RoomType> onChanged;
  const RoomSwitcher({
    super.key,
    required this.currentRoom,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(Icons.menu_book, RoomType.royalLibrary),
          _buildButton(Icons.rocket_launch, RoomType.spaceStation),
          _buildButton(Icons.ac_unit, RoomType.snowyCabin),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, RoomType room) {
    bool isActive = currentRoom == room;
    return GestureDetector(
      onTap: () => onChanged(room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD4AF37) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? Colors.black : Colors.white),
      ),
    );
  }
}
// =================| Settings Dialog |=================

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return AlertDialog(
      backgroundColor: const Color(0xFF2E1E14),
      title: const Text(
        'Settings',
        style: TextStyle(color: Color(0xFFD4AF37)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Font Size:', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: appState.fontSize,
                  min: 12,
                  max: 36,
                  divisions: 12,
                  onChanged: (value) => Provider.of<AppState>(context, listen: false).setFontSize(value),
                  activeColor: const Color(0xFFD4AF37),
                ),
              ),
              Text(appState.fontSize.toStringAsFixed(0), style: const TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Slow Narration:', style: TextStyle(color: Colors.white)),
              Switch(
                value: appState.slowNarration,
                onChanged: (_) => Provider.of<AppState>(context, listen: false).toggleSlowNarration(),
                activeColor: const Color(0xFFD4AF37),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatefulBuilder(
            builder: (context, setState) {
              return FutureBuilder<bool>(
                future: SharedPreferences.getInstance().then((prefs) => prefs.getBool('autoNight') ?? false),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return Row(
                    children: [
                      const Text('Auto Night Mode:', style: TextStyle(color: Colors.white)),
                      Switch(
                        value: snapshot.data!,
                        onChanged: (value) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('autoNight', value);
                          setState(() {});
                           if(context.mounted){
                             Provider.of<AppState>(context, listen: false).checkAutoNightMode();
                          }
                        },
                        activeColor: const Color(0xFFD4AF37),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Color(0xFFD4AF37))),
        ),
      ],
    );
  }
}

// =================| Custom Painters |=================

class WoodenDeskPainter extends CustomPainter {
  final RoomType roomType;
  WoodenDeskPainter({required this.roomType});

  @override
  void paint(Canvas canvas, Size size) {
    Color baseColor = roomType == RoomType.royalLibrary
        ? const Color(0xFF2E1E14)
        : roomType == RoomType.spaceStation
            ? const Color(0xFF0A192F)
            : const Color(0xFF1A1510);
    final Paint paint = Paint()..color = baseColor;
    canvas.drawRect(Offset.zero & size, paint);

    final Paint linePaint = Paint()
      ..color = Colors.black.withAlpha(77)
      ..strokeWidth = 2;
    for (double i = 0; i < size.height; i += 20) {
      double curve = math.Random(i.toInt()).nextDouble() * 10;
      canvas.drawLine(Offset(0, i + curve), Offset(size.width, i - curve), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LeatherCoverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFF4A1521)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16,
    );
    canvas.drawRect(
      const Offset(8, 8) & Size(size.width - 16, size.height - 16),
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 12, height: size.height),
      Paint()..color = Colors.black.withAlpha(153),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LivingParticlesPainter extends StatefulWidget {
  final RoomType roomType;
  const LivingParticlesPainter({super.key, required this.roomType});

  @override
  State<LivingParticlesPainter> createState() => _LivingParticlesPainterState();
}

class _LivingParticlesPainterState extends State<LivingParticlesPainter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat()..addListener(() => setState(() {}));
    int count = widget.roomType == RoomType.spaceStation ? 100 : 50;
    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.001 + _random.nextDouble() * 0.002,
        size: 1 + _random.nextDouble() * 3,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticleCustomPainter(
          particles: _particles,
          progress: _controller.value,
          roomType: widget.roomType,
        ),
      ),
    );
  }
}

class Particle {
  final double x;
  final double y;
  final double speed;
  final double size;
  Particle({required this.x, required this.y, required this.speed, required this.size});
}

class _ParticleCustomPainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final RoomType roomType;

  _ParticleCustomPainter({
    required this.particles,
    required this.progress,
    required this.roomType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();
    for (var p in particles) {
      double dx = p.x * size.width;
      double dy = (p.y + (p.speed * progress * 5)) * size.height;
      if (roomType == RoomType.spaceStation) {
        paint.color = Colors.white.withAlpha(204);
        canvas.drawCircle(Offset(dx, dy % size.height), p.size, paint);
      } else if (roomType == RoomType.snowyCabin) {
        paint.color = Colors.white.withAlpha(153);
        canvas.drawCircle(Offset(dx, dy % size.height), p.size, paint);
      } else {
        paint.color = const Color(0xFFD4AF37).withAlpha(102);
        canvas.drawCircle(
          Offset(dx + math.sin(progress * 2 * math.pi) * 10, dy % size.height),
          p.size,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AmbientLightingOverlay extends StatelessWidget {
  final RoomType roomType;
  const AmbientLightingOverlay({super.key, required this.roomType});

  @override
  Widget build(BuildContext context) {
    Color color = roomType == RoomType.royalLibrary
        ? const Color(0xFFD4AF37).withAlpha(13) // 0.05
        : roomType == RoomType.spaceStation
            ? const Color(0xFF0A192F).withAlpha(51) // 0.2
            : const Color(0xFFBBDEFB).withAlpha(13); // 0.05
    return Container(color: color);
  }
}

class LibraryShelfPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint woodPaint = Paint()..color = const Color(0xFF3E2723);
    Paint linePaint = Paint()
      ..color = Colors.black.withAlpha(128)
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 80) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 10), woodPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
