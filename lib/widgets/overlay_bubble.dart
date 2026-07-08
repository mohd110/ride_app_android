import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Rendered in its own Flutter isolate as a TYPE_APPLICATION_OVERLAY window.
/// The window is full-screen but only the 62×62 circle has hit targets —
/// everything else passes through to the app below (FLAG_NOT_TOUCH_MODAL).
class OverlayBubble extends StatefulWidget {
  const OverlayBubble({Key? key}) : super(key: key);

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  int _orderCount = 1;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    // Receive order-count badge updates from the main app.
    // The main app sends via FlutterOverlayWindow.shareData(count) which
    // arrives here as a num via the JSONMessageCodec.
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted) return;
      if (data is num) {
        setState(() => _orderCount = data.toInt());
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 18, bottom: 110),
            child: GestureDetector(
              onTap: () => FlutterOverlayWindow.shareData("open_app"),
              child: ScaleTransition(
                scale: _scale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main bubble body
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD32F2F),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD32F2F).withOpacity(0.55),
                            blurRadius: 14,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    // Order-count badge
                    if (_orderCount > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _orderCount > 9 ? '9+' : '$_orderCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
