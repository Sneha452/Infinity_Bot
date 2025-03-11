import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({Key? key, required this.child}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<ColorPop> colorPops = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
      setState(() {});
    });

    _controller.forward();

    // Generate color pops
    for (int i = 0; i < 20; i++) {
      colorPops.add(ColorPop(
        position: Offset(Random().nextDouble() * 400, Random().nextDouble() * 800),
        color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
        size: Random().nextDouble() * 20 + 10,
      ));
    }

    // Navigate to main screen after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Stack(
        children: [
          CustomPaint(
            painter: ColorPopPainter(colorPops: colorPops, progress: _controller.value),
            child: Container(),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.5 + (value * 0.5),
                    child: Text(
                      'INFINITY BOT',
                      style: GoogleFonts.roboto( // Updated font style
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.white.withOpacity(0.5),
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ColorPop {
  final Offset position;
  final Color color;
  final double size;

  ColorPop({required this.position, required this.color, required this.size});
}

class ColorPopPainter extends CustomPainter {
  final List<ColorPop> colorPops;
  final double progress;

  ColorPopPainter({required this.colorPops, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var pop in colorPops) {
      final paint = Paint()..color = pop.color.withOpacity(1 - progress);
      canvas.drawCircle(pop.position, pop.size * (1 + progress), paint);
    }
  }

  @override
  bool shouldRepaint(ColorPopPainter oldDelegate) => true;
}