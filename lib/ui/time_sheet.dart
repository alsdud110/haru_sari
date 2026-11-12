import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// [showTimeSheet]에서 "시간 없이 할게요"를 골랐을 때 돌려주는 값.
const timeSheetAnytime = -1;

/// 시간 고르기: 아래에서 올라오는 창에서 오전/오후 · 시 · 분을 굴려서 고른다.
///
/// 고른 시각을 "자정부터 몇 분"으로 돌려준다. 그냥 닫으면 null.
/// [anytimeLabel]을 주면 시간을 비우는 버튼도 보이고, 그걸 누르면 [timeSheetAnytime]을 돌려준다.
Future<int?> showTimeSheet(BuildContext context, {required int initialMinute, String? anytimeLabel}) {
  var picked = initialMinute;
  return showAppSheet<int>(
    context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Brightness.light,
                  primaryColor: AppColors.primary,
                  textTheme: CupertinoTextThemeData(
                    // 휠의 글자: 본문 글꼴 + 영문·숫자 글꼴
                    dateTimePickerTextStyle: TextStyle(
                      fontFamily: AppFonts.latin,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 22,
                      color: AppColors.text,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(2000, 1, 1, initialMinute ~/ 60, initialMinute % 60),
                  use24hFormat: false,
                  backgroundColor: AppColors.background,
                  onDateTimeChanged: (d) => picked = d.hour * 60 + d.minute,
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            FilledButton(onPressed: () => Navigator.pop(ctx, picked), child: const Text('정하기')),
            if (anytimeLabel != null) ...[
              const SizedBox(height: Space.xs),
              TextButton(onPressed: () => Navigator.pop(ctx, timeSheetAnytime), child: Text(anytimeLabel)),
            ],
          ],
        ),
      ),
    ),
  );
}
