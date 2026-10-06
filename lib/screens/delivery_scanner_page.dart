import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/delivery_bloc.dart';

class DeliveryScannerPage extends StatefulWidget {
  final List<String> activeOrderIds;

  const DeliveryScannerPage({
    super.key,
    required this.activeOrderIds,
  });

  @override
  State<DeliveryScannerPage> createState() => _DeliveryScannerPageState();
}

class _DeliveryScannerPageState extends State<DeliveryScannerPage> {
  bool _isProcessing = false;
  bool _isDelivering = false; // Tracks the API loading state
  bool _isSuccess = false;    // Tracks the successful completion
  
  late List<String> _currentActiveIds;

  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void initState() {
    super.initState();
    _currentActiveIds = List.from(widget.activeOrderIds);
  }

  void _onDetect(BarcodeCapture capture) async {
    // Prevent scanning if we are already loading or showing success
    if (_isProcessing || _isDelivering || _isSuccess) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      setState(() => _isProcessing = true);

      final String scannedId = barcodes.first.rawValue!.replaceAll('"', '').trim();

      if (_currentActiveIds.contains(scannedId)) {
        HapticFeedback.heavyImpact();
        
        // 1. Freeze the camera
        cameraController.stop();
        
        // 2. Show the loading spinner
        setState(() => _isDelivering = true);
        
        // 3. Trigger the backend API
        context.read<DeliveryBloc>().add(MarkOrderDelivered(scannedId));
      } else {
        _showErrorDialog("This QR code does not match any of your active deliveries.", isNetworkError: false);
      }
    }
  }

  void _showErrorDialog(String message, {required bool isNetworkError}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(isNetworkError ? Icons.wifi_off_rounded : Icons.gpp_bad_rounded, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 16),
            Text(isNetworkError ? "Network Error" : "Invalid QR Code", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Try Again", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      )
    );

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    // 4. Listen for the backend API to finish
    return BlocListener<DeliveryBloc, DeliveryState>(
      listener: (context, state) {
        if (state is DeliveryLoaded) {
          // Update the local list so the agent doesn't scan the same order twice
          _currentActiveIds = state.activeOrders.map((o) => o.id.toString()).toList();
          
          if (_isDelivering) {
            HapticFeedback.mediumImpact();
            
            // 5. Change UI from Loading to Success!
            setState(() {
              _isDelivering = false;
              _isSuccess = true;
            });
            
            // 6. Hold the success screen for 1.5 seconds so they can read it, then close
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.pop(context, true);
              }
            });
          }
        } else if (state is DeliveryError && _isDelivering) {
          // If API fails, stop loading and restart the camera
          setState(() {
            _isDelivering = false;
            _isProcessing = false;
          });
          cameraController.start();
          _showErrorDialog(state.message, isNetworkError: true);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
            ),
            
            ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.8), BlendMode.srcOut),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut),
                  ),
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.white, 
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ),
            ),

            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isSuccess ? Colors.green : const Color(0xFF00897B), 
                    width: 4
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            
            Positioned(
              top: 100, left: 0, right: 0,
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  const Text("Scan Handoff QR", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF00897B).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text("YOU HAVE ${_currentActiveIds.length} ACTIVE ORDERS", style: const TextStyle(color: Color(0xFF00897B), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 80, left: 0, right: 0,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isSuccess
                    ? Container(
                        key: const ValueKey('success'),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(100)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 8),
                            Text("Delivered Successfully!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : _isDelivering 
                      ? Container(
                          key: const ValueKey('loading'),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF0F172A), strokeWidth: 2.5)),
                              SizedBox(width: 12),
                              Text("Marking as Delivered...", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('idle'),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(100)),
                          child: const Text("Align student's order QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}