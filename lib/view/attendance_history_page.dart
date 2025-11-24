// lib/pages/attendance_history_page.dart
import 'package:absensi_san/service/api.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:absensi_san/models/attendance_history.dart';

class AttendanceHistoryPage extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const AttendanceHistoryPage({this.initialStart, this.initialEnd, Key? key})
    : super(key: key);

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  DateTime? _start;
  DateTime? _end;
  late Future<List<AttendanceHistory>> _future;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();

  final DateFormat _displayFmt = DateFormat.yMMMMd(
    'en_US',
  ); // e.g. November 19, 2025
  final DateFormat _queryFmt = DateFormat('yyyy-MM-dd'); // for API

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = AuthAPI.fetchHistory(
        start: _start != null ? _queryFmt.format(_start!) : null,
        end: _end != null ? _queryFmt.format(_end!) : null,
      );
    });
  }

  Future<void> _onRefresh() async {
    _refreshKey.currentState?.show();
    _load();
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final pick = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      builder: (context, child) =>
          Theme(data: Theme.of(context).copyWith(), child: child!),
    );
    if (pick != null) setState(() => _start = pick);
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final pick = await showDatePicker(
      context: context,
      initialDate: _end ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (pick != null) setState(() => _end = pick);
  }

  String _safeTime(String? t) => t ?? '-';

  String _resolveInLocation(AttendanceHistory h) {
    if ((h.checkInAddress ?? '').trim().isNotEmpty) return h.checkInAddress!;
    if ((h.checkInLocation ?? '').trim().isNotEmpty) return h.checkInLocation!;
    if (h.checkInLat != null && h.checkInLng != null)
      return '${h.checkInLat},${h.checkInLng}';
    return '-';
  }

  String _resolveOutLocation(AttendanceHistory h) {
    if ((h.checkOutAddress ?? '').trim().isNotEmpty) return h.checkOutAddress!;
    if ((h.checkOutLocation ?? '').trim().isNotEmpty)
      return h.checkOutLocation!;
    if (h.checkOutLat != null && h.checkOutLng != null)
      return '${h.checkOutLat},${h.checkOutLng}';
    return '-';
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'masuk':
        return Colors.green.shade700;
      case 'izin':
        return Colors.orange.shade700;
      case 'alpha':
      case 'absent':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _statusIcon(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'masuk':
        return Icons.login;
      case 'izin':
        return Icons.note_alt;
      default:
        return Icons.history;
    }
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _pickStart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range,
                      size: 18,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _start == null ? 'Start' : _displayFmt.format(_start!),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _pickEnd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range,
                      size: 18,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _end == null ? 'End' : _displayFmt.format(_end!),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              if (_start == null || _end == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select both start and end dates'),
                  ),
                );
                return;
              }
              if (_start!.isAfter(_end!)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Start must be before or equal to End'),
                  ),
                );
                return;
              }
              _load();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            child: const Icon(Icons.filter_list),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AttendanceHistory item) {
    final date = item.attendanceDate;
    final dateText = _displayFmt.format(date);
    final inTime = _safeTime(item.checkInTime);
    final outTime = _safeTime(item.checkOutTime);
    final inLoc = _resolveInLocation(item);
    final outLoc = _resolveOutLocation(item);
    final status = item.status ?? '-';
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        elevation: 2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // optional: expand detail or open map
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14),
            child: Row(
              children: [
                // left icon + date column
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          _statusIcon(status),
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(fontSize: 11, color: statusColor),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // right details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // times row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Check-in',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  inTime,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Check-out',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  outTime,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // locations
                      const Text(
                        'In Location',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(inLoc, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      const Text(
                        'Out Location',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(outLoc, style: const TextStyle(fontSize: 13)),
                      if ((item.status ?? '').toLowerCase() == 'izin') ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 4),
                        Text(
                          'Reason',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.alasanIzin ?? '-',
                          style: const TextStyle(fontSize: 13),
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
    );
  }

  Widget _buildList(List<AttendanceHistory> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No attendance records',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the date range or refresh',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final item = list[idx];
        return _buildCard(item);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Attendance History'),
        centerTitle: false,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              key: _refreshKey,
              onRefresh: _onRefresh,
              color: primary,
              child: FutureBuilder<List<AttendanceHistory>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'Error: ${snap.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final data = snap.data ?? [];
                  return _buildList(data);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton:
          _scrollController.hasClients && _scrollController.offset > 200
          ? FloatingActionButton(
              onPressed: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              ),
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}
