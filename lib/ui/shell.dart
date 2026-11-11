import 'package:flutter/material.dart';

import 'records.dart';
import 'room/room_screen.dart';
import 'settings.dart';
import 'today.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const today = 0, room = 1, records = 2, me = 3;

  static _HomeShellState? _of(BuildContext context) => context.findAncestorStateOfType<_HomeShellState>();

  /// 다른 화면에서 탭을 바꿀 때 쓴다.
  static void goTo(BuildContext context, int index) => _of(context)?._select(index);

  /// 기록 탭을 특정 기간으로 연다.
  static void openRecords(BuildContext context, RecordRange range) {
    final s = _of(context);
    if (s == null) return;
    s._recordRange.value = range;
    s._recordAnchor.value = null;
    s._select(records);
  }

  /// 내 방 탭에서 가구 상점을 연다.
  static void openShop(BuildContext context) {
    final s = _of(context);
    if (s == null) return;
    s._select(room);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _recordRange = ValueNotifier(RecordRange.week);
  final _recordAnchor = ValueNotifier<DateTime?>(null);

  void _select(int i) => setState(() => _index = i);

  @override
  void dispose() {
    _recordRange.dispose();
    _recordAnchor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TodayScreen(),
      const RoomScreen(),
      RecordsScreen(range: _recordRange, anchor: _recordAnchor),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < pages.length; i++) TickerMode(enabled: i == _index, child: pages[i])],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: '오늘',
          ),
          NavigationDestination(
            icon: Icon(Icons.chair_outlined),
            selectedIcon: Icon(Icons.chair_rounded),
            label: '내 방',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: '기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '나',
          ),
        ],
      ),
    );
  }
}
