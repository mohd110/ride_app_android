import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Registered natively on THIS bubble's own Flutter engine too (see
/// MainActivity.kt) — not just the main app's engine. The plugin's own
/// overlay→main relay (shareData/overlayListener) has proven unreliable
/// (routes through a shared static field that ends up bound to whichever
/// engine attached last, which in practice is this one, so a tap's message
/// loops back to itself instead of reaching the main app). Calling
/// bringToFront directly on this channel sidesteps that entirely.
const _overlayControlChannel = MethodChannel('rider.overlay/control');

/// Rendered in its own Flutter isolate as a TYPE_APPLICATION_OVERLAY window.
/// The native window itself is sized to just this bubble (see
/// `AppState._showOrderOverlay`), not the full screen, so everything outside
/// it always falls through to whatever app is behind — no full-screen block.
/// Dragging and edge-snapping are handled natively by the plugin's
/// `enableDrag` / `positionGravity` flags; this widget only needs to render
/// the bubble and handle taps.
class OverlayBubble extends StatefulWidget {
  const OverlayBubble({Key? key}) : super(key: key);

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  // Starts at 0 — the bubble is now shown any time the rider is online and
  // backgrounded, not just when there's a new order, so it must default to
  // "no badge" until AppState sends the real pending-order count.
  int _orderCount = 0;

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

  Future<void> _onTap() async {
    // Best-effort signal to the main isolate for its own bookkeeping
    // (routing to the New Order screen, clearing the badge, etc) — but
    // opening the app must not depend on this actually arriving.
    unawaited(FlutterOverlayWindow.shareData("open_app"));
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
    try {
      await _overlayControlChannel.invokeMethod('bringToFront');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // No MaterialApp/Scaffold here — those give the window an opaque,
    // hit-testable background the full size of the (now small) overlay
    // window. A bare Material with a transparent color keeps only the
    // circle itself tappable/draggable, matching the plugin's chat-head
    // example.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: _onTap,
            child: ScaleTransition(
              scale: _scale,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
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
    );
  }
}
