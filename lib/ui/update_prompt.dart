import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import '../data/app_update.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import 'motion.dart';

/// [child] 를 그린 뒤 업데이트 안내가 있으면 팝업을 띄운다.
/// [take] 는 앱을 켤 때 한 번 물어본 결과를 처음 한 번만 넘겨준다 (로그인 화면이 바뀌어도 다시 뜨지 않게).
class UpdatePrompt extends StatefulWidget {
  const UpdatePrompt({super.key, required this.take, required this.kv, required this.child});
  final Future<AppUpdate?>? Function() take;
  final KeyValue kv;
  final Widget child;

  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<UpdatePrompt> {
  @override
  void initState() {
    super.initState();
    widget.take()?.then((u) {
      if (u != null && mounted) _show(u);
    });
  }

  Future<void> _show(AppUpdate u) async {
    void open() => launchUrl(Uri.parse(u.storeUrl), mode: LaunchMode.externalApplication);
    final later = await showAppDialog<bool>(
      context,
      dismissible: !u.force,
      builder: (ctx) => PopScope(
        canPop: !u.force,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('새 버전이 나왔어요'),
          content: Text(u.message.isNotEmpty ? u.message : '더 편해진 하루살이를 만나 보세요.'),
          actions: [
            if (!u.force) TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('나중에')),
            TextButton(
              // 꼭 해야 하는 업데이트는 스토어에 다녀와도 팝업이 남아 있다.
              onPressed: () {
                open();
                if (!u.force) Navigator.pop(ctx, false);
              },
              child: const Text('업데이트', style: TextStyle(color: AppColors.primaryInk)),
            ),
          ],
        ),
      ),
    );
    if (later == true) await widget.kv.write(AppUpdate.dismissedKey, '${u.latest}');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
