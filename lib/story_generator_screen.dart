
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'gemini_service.dart';

class StoryGeneratorScreen extends StatefulWidget {
  const StoryGeneratorScreen({super.key});

  @override
  State<StoryGeneratorScreen> createState() => _StoryGeneratorScreenState();
}

class _StoryGeneratorScreenState extends State<StoryGeneratorScreen> {
  final _promptController = TextEditingController();
  final _geminiService = GeminiService();

  bool _isLoading = false;
  String? _generatedStory;
  List<Uint8List> _generatedImages = [];
  String? _error;

  // 1. Add state variable for Kids/Adults Mode
  bool isKidsMode = true;
  bool _isLampOn = true; // For the interactive lamp

  Future<void> _generate() async {
    if (_promptController.text.isEmpty) {
      setState(() => _error = 'Please enter an idea for the story.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _generatedStory = null;
      _generatedImages = [];
    });

    try {
      final story = await _geminiService.generateStory(_promptController.text);
      if (!mounted) return;

      setState(() {
        _generatedStory = story;
      });

      final images = await _geminiService.generateStoryboardImages(story);
      if (!mounted) return;

      setState(() {
        _generatedImages = images;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 4. Mock pop-up modal for the Language Learning Tool
  void _showLanguageTool(BuildContext context, LongPressStartDetails details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Language Tool'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selected: "placeholder"\n(Long-press a word)'), // Placeholder text
            const SizedBox(height: 20),
            TextButton.icon(
              icon: const Icon(Icons.translate),
              label: const Text('Translate'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton.icon(
              icon: const Icon(Icons.volume_up),
              label: const Text('Pronounce'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {

    // 2. Conditionally set background for Adults Mode
    final backgroundColor = isKidsMode ? Colors.transparent : const Color(0xFFFDFBF7); // Soft Sepia
    
    final kidsBackgroundGradient = isKidsMode
        ? const RadialGradient(
            center: Alignment(0.0, -0.7),
            radius: 1.2,
            colors: [
              Color(0xFFFFA726), // Bright Amber
              Color(0xFFF57C00), // Honey Oak
            ],
          )
        : null;

    final kidsDeskGradient = isKidsMode
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD2691E), // Chocolate Brown
              Color(0xFF8B4513), // Saddle Brown
            ],
          )
        : null;
        
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isKidsMode ? 'Create a Story with AI' : 'Modern Minimalist Writer',
          style: TextStyle(
            color: isKidsMode ? Colors.white : const Color(0xFF333333),
            fontWeight: FontWeight.bold,
            shadows: isKidsMode ? [
              Shadow(
                blurRadius: 8.0,
                color: Colors.black.withAlpha(128),
                offset: const Offset(2.0, 2.0),
              ),
            ] : [],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isKidsMode ? Colors.white : const Color(0xFF333333)),
        actions: [
          Tooltip(
            message: isKidsMode ? "Switch to Adults Mode" : "Switch to Kids Mode",
            child: Switch(
              value: isKidsMode,
              onChanged: (value) {
                setState(() {
                  isKidsMode = value;
                });
              },
              activeTrackColor: Colors.amber.shade200,
              activeColor: Colors.amber.shade700,
              inactiveThumbColor: Colors.grey.shade700,
              inactiveTrackColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Kids mode specific background
          if (isKidsMode)
            Container(
              decoration: BoxDecoration(
                gradient: kidsBackgroundGradient,
              ),
            ),
          if (isKidsMode)
            Positioned.fill(
              child: CustomPaint(painter: WoodenDeskPainter(isKidsMode: isKidsMode, kidsModeGradient: kidsDeskGradient)),
            ),
          if (_isLampOn && isKidsMode)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.8, -0.85),
                    radius: 0.4,
                    colors: [
                      Colors.amber.withAlpha(128),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPromptInput(),
                        const SizedBox(height: 24),
                        _buildGenerateButton(),
                        const SizedBox(height: 24),
                        _buildResultArea(),
                      ],
                    ),
                  ),
                ),
                // Conditionally show Kids bookshelves or Adults glassmorphism library
                isKidsMode ? _buildBookshelves() : _buildGlassmorphismLibrary(),
              ],
            ),
          ),
          if (isKidsMode) _buildMagicLamp(),
        ],
      ),
    );
  }

  Widget _buildMagicLamp() {
    return Positioned(
      top: 50,
      right: 20,
      child: GestureDetector(
        onTap: () => setState(() => _isLampOn = !_isLampOn),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.yellow[700],
            boxShadow: _isLampOn
                ? [
                    BoxShadow(
                      color: Colors.amber.withAlpha(204),
                      blurRadius: 40.0,
                      spreadRadius: 10.0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(102),
                      blurRadius: 5.0,
                      offset: const Offset(2, 2),
                    ),
                  ],
          ),
          child: Icon(
            Icons.lightbulb,
            color: _isLampOn ? Colors.white : Colors.grey[300],
            size: 30,
          ),
        ),
      ),
    );
  }
  
  // 3. Glassmorphism library view for Adults Mode
  Widget _buildGlassmorphismLibrary() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: CarouselSlider(
        options: CarouselOptions(
          height: 120.0,
          viewportFraction: 0.3,
          enlargeCenterPage: true,
          autoPlay: true,
        ),
        items: List.generate(8, (i) {
          return Builder(
            builder: (BuildContext context) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(51)),
                      ),
                      child: Center(
                        child: Text(
                          'Book ${i + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withAlpha(153),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBookshelves() {
    return Container(
      color: const Color(0xFF6F4E37),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: 120.0,
              viewportFraction: 0.25,
              enlargeCenterPage: true,
              autoPlay: true,
            ),
            items: [1, 2, 3, 4, 5, 6, 7, 8].map((i) {
              return Builder(
                builder: (BuildContext context) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5.0),
                    decoration: BoxDecoration(
                      color: Colors.primaries[i % Colors.primaries.length].shade300,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black.withAlpha(128),
                          blurRadius: 4,
                          offset: const Offset(2,2),
                         )
                      ]
                    ),
                    child: Center(child: Text('Book $i', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),)),
                  );
                },
              );
            }).toList(),
          ),
           const SizedBox(height: 8),
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF5C3A21),
                boxShadow: [ BoxShadow(color: Colors.black.withAlpha(153), blurRadius: 6, offset: const Offset(0, 4)) ]
              ),
          )
        ],
      ),
    );
  }
  
  Widget _buildPromptInput() {
    return Container(
      decoration: BoxDecoration(
        color: isKidsMode ? Colors.white.withAlpha(204) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isKidsMode ? Colors.brown.shade700 : Colors.grey.shade300)),
         boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isKidsMode ? 51 : 13),
            blurRadius: 8,
            offset: const Offset(0, 4)
          )
        ]
      ),
      child: TextField(
        controller: _promptController,
        style: TextStyle(color: isKidsMode ? Colors.brown.shade900 : Colors.black87),
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'A story about a brave little squirrel...',
          hintStyle: TextStyle(color: (isKidsMode ? Colors.brown.shade700 : Colors.grey.shade500)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _generate,
      icon: Icon(Icons.auto_awesome, color: isKidsMode ? Colors.brown.shade900 : Colors.white),
      label: Text(_isLoading ? 'Dreaming...' : 'Create Story'),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) return Colors.grey;
          return isKidsMode ? Colors.amber.shade300 : Colors.black87;
        }),
        foregroundColor: WidgetStateProperty.all(isKidsMode ? Colors.brown.shade900 : Colors.white),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        elevation: WidgetStateProperty.all(isKidsMode ? 8 : 4),
        shadowColor: WidgetStateProperty.all(Colors.black.withAlpha(102)),
        textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildResultArea() {
    final textColor = isKidsMode ? Colors.white : Colors.black54;
    
    if (_isLoading) {
      return Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: isKidsMode ? Colors.amber.shade300 : Colors.black54),
            const SizedBox(height: 16),
            Text('The AI is dreaming up your story...', style: TextStyle(color: textColor)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 16));
    }

    if (_generatedStory == null) {
      return Center(
        child: Text(
          'Your magical story will appear here.',
          style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStoryDisplay(),
        const SizedBox(height: 24),
        _buildImageGallery(),
      ],
    );
  }
  
  Widget _buildStoryDisplay() {
    if (!isKidsMode) {
      // 4. E-Reader layout for Adults with interactive text selection
      return GestureDetector(
        onLongPressStart: (details) => _showLanguageTool(context, details),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(38),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: SelectableText(
            _generatedStory ?? "",
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 16,
              height: 1.7,
              fontFamily: 'Georgia', // A more literary font
            ),
          ),
        ),
      );
    }

    // Kids Mode open book layout
    final storyText = _generatedStory ?? "";
    final middle = (storyText.length / 2).floor();
    final leftPageText = storyText.substring(0, middle);
    final rightPageText = storyText.substring(middle);

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(102), blurRadius: 15, offset: const Offset(0, 8),)],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 24, 20),
                  child: Text(leftPageText, style: TextStyle(color: Colors.brown.shade800, fontSize: 15, height: 1.6, fontFamily: 'serif')),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                  child: Text(rightPageText, style: TextStyle(color: Colors.brown.shade800, fontSize: 15, height: 1.6, fontFamily: 'serif')),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withAlpha(26), Colors.black.withAlpha(26), Colors.transparent],
                  stops: const [0.0, 0.45, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    final textColor = isKidsMode ? Colors.white : Colors.black87;

    if (_generatedImages.isEmpty && _generatedStory != null) {
       return Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: isKidsMode ? Colors.amber.shade300 : Colors.black54),
            const SizedBox(height: 16),
            Text('Illustrating the pages...', style: TextStyle(color: textColor)),
          ],
        ),
      );
    }

    if (_generatedImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
          'Story Illustrations',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _generatedImages.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_generatedImages[index], width: 150, height: 150, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class WoodenDeskPainter extends CustomPainter {
  final bool isKidsMode;
  final Gradient? kidsModeGradient;

  WoodenDeskPainter({required this.isKidsMode, this.kidsModeGradient});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isKidsMode) return; // Don't paint for adults mode

    final Paint paint = Paint();
    final Path path = Path();

    path.moveTo(0, size.height * 0.65);
    path.lineTo(size.width, size.height * 0.65);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    final Rect deskRect = Rect.fromLTWH(0, size.height * 0.65, size.width, size.height * 0.35);
    if (kidsModeGradient != null) {
      paint.shader = kidsModeGradient!.createShader(deskRect);
    }

    canvas.drawPath(path, paint);

    final Paint grainPaint = Paint()
      ..color = Colors.white.withAlpha(13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double i = 0.66; i < 1.0; i += 0.02) {
      canvas.drawLine(Offset(0, size.height * i), Offset(size.width, size.height * i), grainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
