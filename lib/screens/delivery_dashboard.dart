// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../blocs/delivery_bloc.dart';
import '../models/order_model.dart';
import '../models/delivery_model.dart';
import 'delivery_profile_screen.dart';
import 'delivery_login_screen.dart';
import '../services/agent_fcm_service.dart';
import 'delivery_scanner_page.dart'; 

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  final Color primaryTeal = const Color(0xFF00897B);
  int _currentIndex = 0;

  StreamSubscription<String>? _deliverySubscription;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // 5-second cooldown state
  bool _isNotifyCooldown = false;
  int _cooldownKey = 0;

  // Local Data Cache
  bool _hasInitialData = false;
  List<Order> _cachedActiveOrders = [];
  List<Order> _cachedHistoryOrders = [];
  DeliveryProfile? _cachedProfileData;
  Map<String, dynamic>? _cachedRestaurantData;

  String? _processingOrderId;
  String? _processingAction;

  @override
  void initState() {
    super.initState();
    AgentFCMService.isViewingActiveDeliveries = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This fixes the infinite spinner when SplashScreen navigates here directly
      final bloc = context.read<DeliveryBloc>();
      if (bloc.state is! DeliveryLoaded && bloc.state is! DeliveryLoading) {
        bloc.add(LoadDeliveryDashboard());
      }
      _setupNotificationListeners(); 
      _checkPendingReload();         
    });
  }

  void _setupNotificationListeners() {
    _deliverySubscription = AgentFCMService.onNewDelivery.listen((orderId) {
      if (!mounted) return;
      context.read<DeliveryBloc>().add(LoadDeliveryDashboard());

      if (!AgentFCMService.isViewingActiveDeliveries) {
        _showTopNotificationToast(
          title: 'New Delivery Assigned! ',
          subtitle: 'Orders list has been refreshed!',
          icon: Icons.moped_rounded,
          color: Colors.blue,
        );
      }
    });
  }

  void _checkPendingReload() {
    if (!AgentFCMService.hasPendingReload()) return;
    if (!mounted) return;

    context.read<DeliveryBloc>().add(LoadDeliveryDashboard());
    _showTopNotificationToast(
      title: 'New Delivery Assigned! ',
      subtitle: 'Orders list has been refreshed!',
      icon: Icons.moped_rounded,
      color: Colors.blue,
    );
    AgentFCMService.clearPendingReload();
  }

  void _showTopNotificationToast({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16, 
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0), 
                child: Transform.translate(
                  offset: Offset(0, -30 * (1 - value)), 
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Future<void> _handleRefresh() async {
    context.read<DeliveryBloc>().add(LoadDeliveryDashboard());
  }

  void _showQRDialog(String qrUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 340, width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                ),
                child: qrUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          qrUrl,
                          fit: BoxFit.contain, 
                          loadingBuilder: (ctx, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(child: CircularProgressIndicator(color: primaryTeal, strokeWidth: 2.5));
                          },
                          errorBuilder: (ctx, error, stack) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('Could not load QR', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_2_rounded, size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'No QR Code uploaded',
                            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ask the partner to upload one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Order> _filterOrders(List<Order> orders) {
    if (_searchController.text.isEmpty) return orders;
    return orders.where((order) {
      final orderNum = order.orderNumber.toString().toLowerCase();
      return orderNum.contains(_searchController.text.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose(); 
    _deliverySubscription?.cancel();
    AgentFCMService.isViewingActiveDeliveries = false;
    super.dispose();
  }

  void _callStudent(String phoneNumber) async {
    final Uri url = Uri.parse('tel:$phoneNumber');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch dialer for $phoneNumber');
    }
  }

  void _showCancelOrderDialog(BuildContext context, Order order, VoidCallback resetSwipe) {
    String selectedReason = '';
    final TextEditingController otherReasonController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final List<String> commonReasons = [
      'Student not answering calls',
      'Student unavailable at location',
      'Hostel gates locked / Restricted entry',
      'Other (Type below)'
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 10),
                Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Why are you cancelling this delivery?',
                      style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...commonReasons.map((reason) => RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(reason, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          value: reason,
                          groupValue: selectedReason,
                          activeColor: Colors.red,
                          onChanged: (value) => setState(() => selectedReason = value!),
                        )),
                    if (selectedReason == 'Other (Type below)') ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: otherReasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Type your exact reason here...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (selectedReason == 'Other (Type below)' && (value == null || value.trim().length < 5)) {
                            return 'Please provide a detailed reason.';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (selectedReason.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('* Please select a reason to continue.', style: TextStyle(color: Colors.red, fontSize: 12)),
                      )
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
            actions: [
              TextButton(
                onPressed: () {
                  resetSwipe();
                  Navigator.pop(ctx);
                },
                child: const Text('Go Back', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (selectedReason.isEmpty) {
                    setState(() {});
                    return;
                  }
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx);
                    this.setState(() {
                      _processingOrderId = order.id.toString();
                      _processingAction = 'cancel';
                    });
                    final finalReason = selectedReason == 'Other (Type below)' ? otherReasonController.text.trim() : selectedReason;
                    context.read<DeliveryBloc>().add(MarkOrderNotPickedUp(order.id.toString(), finalReason));
                  }
                },
                child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    ),
  );
}

  Future<void> _handleGlobalScan() async {
    if (_cachedActiveOrders.isEmpty) {
      _showTopNotificationToast(
        title: 'No Active Orders',
        subtitle: 'You do not have any active orders to deliver right now.',
        icon: Icons.info_outline_rounded,
        color: Colors.orange,
      );
      return;
    }

    final List<String> activeIds = _cachedActiveOrders.map((o) => o.id.toString()).toList();
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DeliveryBloc>(),
          child: DeliveryScannerPage(activeOrderIds: activeIds),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: isKeyboardOpen 
          ? null 
          : FloatingActionButton(
              backgroundColor: primaryTeal,
              elevation: 6,
              shape: const CircleBorder(),
              onPressed: _handleGlobalScan,
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
            ),

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentIndex = 0;
                        _isSearching = false; 
                        _searchController.clear();
                      });
                      AgentFCMService.isViewingActiveDeliveries = true;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.moped, color: _currentIndex == 0 ? primaryTeal : Colors.grey.shade400, size: 26),
                        const SizedBox(height: 2),
                        Text('Active', style: TextStyle(color: _currentIndex == 0 ? primaryTeal : Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentIndex = 1;
                        _isSearching = false; 
                        _searchController.clear();
                      });
                      AgentFCMService.isViewingActiveDeliveries = false;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, color: _currentIndex == 1 ? primaryTeal : Colors.grey.shade400, size: 26),
                        const SizedBox(height: 2),
                        Text('History', style: TextStyle(color: _currentIndex == 1 ? primaryTeal : Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search Order ID...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() {}), 
            )
          : Text(
              _currentIndex == 0 ? 'Active Deliveries' : 'Delivery History',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 26),
            onPressed: () {
              final imagesRaw = _cachedRestaurantData?['images'];
              List<dynamic> images = [];
              if (imagesRaw is List) {
                images = imagesRaw;
              } else if (imagesRaw is String) {
                try { images = jsonDecode(imagesRaw) as List; } catch(_) {}
              }
              final String qrUrl = images.length > 1 ? (images[1]?.toString() ?? '') : '';
              _showQRDialog(qrUrl);
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white, size: 28),
            onPressed: () {
              if (_hasInitialData && _cachedProfileData != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryProfileScreen(profileData: _cachedProfileData!),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocConsumer<DeliveryBloc, DeliveryState>(
        listener: (context, state) {
          if (state is DeliveryError) {
            _showTopNotificationToast(
              title: 'Whoops!',
              subtitle: state.message,
              icon: Icons.error_outline_rounded,
              color: Colors.red,
            );
            setState(() {
              _processingOrderId = null;
              _processingAction = null;
            });
          }
          if (state is DeliveryLoaded) {
            setState(() {
              _processingOrderId = null;
              _processingAction = null;
            });
          }
          if (state is DeliverySessionExpired) {
            _showTopNotificationToast(
              title: 'Session Expired',
              subtitle: 'Please log in again.',
              icon: Icons.lock_outline_rounded,
              color: Colors.orange,
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const DeliveryLoginScreen()),
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          
          if (state is DeliveryLoaded) {
            _cachedActiveOrders = state.activeOrders;
            _cachedHistoryOrders = state.historyOrders;
            _cachedProfileData = state.profileData;
            _cachedRestaurantData = state.restaurantData; 
            _hasInitialData = true;
          }

          if (!_hasInitialData) {
            return Center(child: CircularProgressIndicator(color: primaryTeal));
          }

          final filteredActive = _filterOrders(_cachedActiveOrders);
          final filteredHistory = _filterOrders(_cachedHistoryOrders);

          Widget content;
          if (_currentIndex == 0) {
            content = _buildActiveList(filteredActive);
          } else {
            content = _buildHistoryTabs(filteredHistory);
          }
          return content;
        },
      ),
    );
  }

  Widget _buildActiveList(List<Order> orders) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        color: primaryTeal,
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            _buildEmptyState(
              _isSearching ? 'Order ID not found.' : 'No active deliveries right now.', 
              _isSearching ? Icons.search_off : Icons.check_circle_outline
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: primaryTeal,
            onRefresh: _handleRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: orders.length,
              itemBuilder: (context, index) => _buildOrderCard(orders[index], isActive: true),
            ),
          ),
        ),

        if (!_isSearching)
          Container(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      color: _isNotifyCooldown ? Colors.orange.shade200 : Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  
                  if (_isNotifyCooldown)
                    TweenAnimationBuilder<double>(
                      key: ValueKey(_cooldownKey), 
                      tween: Tween(begin: 1.0, end: 0.0), 
                      duration: const Duration(seconds: 5),
                      builder: (context, value, child) {
                        return FractionallySizedBox(
                          widthFactor: value,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 55,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),

                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isNotifyCooldown ? null : () {
                          setState(() {
                            _isNotifyCooldown = true;
                            _cooldownKey++; 
                          });
                          
                          Future.delayed(const Duration(seconds: 5), () {
                            if (mounted) setState(() => _isNotifyCooldown = false);
                          });

                          final orderIds = orders.map((o) => o.id.toString()).toList();
                          context.read<DeliveryBloc>().add(MarkAtGateRequested(orderIds));

                          _showTopNotificationToast(
                            title: 'Students Notified! ',
                            subtitle: 'Pinging students for ${orders.length} orders.',
                            icon: Icons.notifications_active,
                            color: Colors.orange,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isNotifyCooldown ? Icons.timer : Icons.notifications_active, 
                              color: Colors.white
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isNotifyCooldown 
                                  ? 'WAIT A MOMENT...' 
                                  : 'NOTIFY STUDENTS (${orders.length})',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTabs(List<Order> historyOrders) {
    final todayOrders = <Order>[];
    final previousOrders = <Order>[];

    for (var order in historyOrders) {
      todayOrders.add(order);
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: primaryTeal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryTeal,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'Previous'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildHistoryListPage(todayOrders, _isSearching ? 'Order ID not found.' : 'No deliveries completed today.'),
                _buildHistoryListPage(previousOrders, _isSearching ? 'Order ID not found.' : 'No previous deliveries found.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryListPage(List<Order> orders, String emptyMessage) {
    return RefreshIndicator(
      color: primaryTeal,
      onRefresh: _handleRefresh,
      child: orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                _buildEmptyState(emptyMessage, _isSearching ? Icons.search_off : Icons.history_toggle_off),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), 
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: orders.length,
              itemBuilder: (context, index) =>
                  _buildOrderCard(orders[index], isActive: false),
            ),
    );
  }

  Widget _buildOrderCard(Order order, {required bool isActive}) {
    final items = order.items;
    final status = order.status;
    final double totalAmount = order.totalAmount;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Order ID + Total Amount (active) OR Status badge (history) ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? primaryTeal.withValues(alpha: 0.1) : Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isActive ? primaryTeal : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.studentName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // History: status badge | Active: total amount
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'delivered' ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: status == 'delivered' ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (order.discountAmount > 0)
                          Text('₹${(totalAmount + order.discountAmount).toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        Text(order.discountAmount > 0 ? 'Final Total' : 'Total Amount', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(
                          '₹${totalAmount.toInt()}',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryTeal),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // ── Body: Menu items with quantity + price ──
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  'View Order Items (${items.length})',
                  style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                children: items.map((item) {
                  final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                  final int qty = item['quantity'] ?? 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$qty×',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: primaryTeal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['name'] ?? 'Item',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '₹${(price * qty).toInt()}',
                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            // ── Coupon Info ──
            if (order.discountAmount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.local_offer_rounded, size: 14, color: primaryTeal),
                    const SizedBox(width: 4),
                    Text(
                      order.couponCode != null && order.couponCode!.isNotEmpty
                          ? "Coupon '${order.couponCode}' applied"
                          : "Coupon applied by user",
                      style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // ── History footer: Total Amount ──
            if (!isActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (order.discountAmount > 0) ...[
                      const Text('Original:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text('₹${(totalAmount + order.discountAmount).toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 12),
                    ],
                    Text(order.discountAmount > 0 ? 'Final Total:' : 'Total Amount:', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(
                      '₹${totalAmount.toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),

            // ── Active footer: Call Student + Cancel buttons ──
            if (isActive) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryTeal,
                          side: BorderSide(color: primaryTeal),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.call, size: 20),
                        label: const Text('Call Student'),
                        onPressed: () => _callStudent(order.studentPhone),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SwipeActionButton(
                        key: ValueKey('cancel_swipe_${order.id}'),
                        label: 'Swipe Cancel',
                        loadingLabel: 'Canceling...',
                        color: const Color.fromARGB(255, 220, 97, 88),
                        isLoading: _processingOrderId == order.id.toString() && _processingAction == 'cancel',
                        onSwipe: (reset) => _processingOrderId != null ? null : _showCancelOrderDialog(context, order, reset),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionButton extends StatefulWidget {
  final String label;
  final String loadingLabel;
  final Color color;
  final void Function(VoidCallback resetSwipe)? onSwipe;
  final bool isLoading;

  const _SwipeActionButton({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.color,
    required this.onSwipe,
    this.isLoading = false,
  });

  @override
  State<_SwipeActionButton> createState() => _SwipeActionButtonState();
}

class _SwipeActionButtonState extends State<_SwipeActionButton> {
  double _dragPosition = 0.0;
  bool _isAccepted = false;

  @override
  void didUpdateWidget(_SwipeActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLoading && oldWidget.isLoading) {
      setState(() {
        _isAccepted = false;
        _dragPosition = 0.0;
      });
    } else if (widget.isLoading) {
      _isAccepted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 56;
        final currentPosition = widget.isLoading ? maxDrag : _dragPosition;

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    widget.isLoading ? widget.loadingLabel : widget.label,
                    style: TextStyle(
                      color: widget.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: 56,
                width: currentPosition + 56,
                decoration: BoxDecoration(
                  color: widget.isLoading ? widget.color : widget.color.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: widget.isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white30,
                            color: Colors.white,
                            minHeight: 4,
                          ),
                        ),
                      ),
                    )
                  : null,
              ),
              if (!widget.isLoading)
                Positioned(
                  left: currentPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: widget.onSwipe == null ? null : (details) {
                      setState(() {
                        _dragPosition += details.delta.dx;
                        if (_dragPosition < 0) _dragPosition = 0;
                        if (_dragPosition > maxDrag) {
                          _dragPosition = maxDrag;
                          if (!_isAccepted) {
                            _isAccepted = true;
                            widget.onSwipe?.call(() {
                              if (mounted) {
                                setState(() {
                                  _isAccepted = false;
                                  _dragPosition = 0.0;
                                });
                              }
                            });
                          }
                        }
                      });
                    },
                    onHorizontalDragEnd: widget.onSwipe == null ? null : (details) {
                      if (!_isAccepted) {
                        setState(() {
                          _dragPosition = 0.0;
                        });
                      }
                    },
                    child: Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.double_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}