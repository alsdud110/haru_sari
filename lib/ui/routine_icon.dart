import 'package:flutter/material.dart';

/// 루틴·카테고리 아이콘.
///
/// 저장하는 값은 예전 그대로 이모지 한 글자다 (알림 문구처럼 그림을 못 쓰는 곳에서는 이모지가 그대로 보인다).
/// 화면에서는 그 이모지에 해당하는 앱 전용 그림(assets/icons)을 보여 주고, 짝이 없는 이모지는 글자로 그린다.
/// 그림은 `dart run tool/make_icons.dart` 로 만든다.
const routineIconAssets = <String, String>{
  // 하루의 흐름 순서 (아이콘 고르기 화면에 이 순서로 나온다)
  '🌤': 'sun',
  '🌙': 'moon',
  '🛏': 'bed',
  '🪥': 'toothbrush',
  '🧼': 'soap',
  '🛁': 'bath',
  '👔': 'shirt',
  '🥛': 'glass',
  '💧': 'drop',
  '💊': 'pill',
  '🍚': 'rice',
  '🍴': 'cutlery',
  '☕': 'mug',
  '🏃': 'shoe',
  '🏋': 'dumbbell',
  '🩺': 'heart',
  '🚇': 'train',
  '🚌': 'bus',
  '🏠': 'house',
  '💼': 'briefcase',
  '📚': 'book_open',
  '📖': 'book',
  '✍': 'note',
  '🧹': 'broom',
  '🪴': 'plant',
  '🐶': 'dog',
  '🧘': 'lotus',
  '🎵': 'music',
  '🎧': 'headphones',
  '💬': 'chat',
  '💰': 'coin',
  '✨': 'sparkle',
};

/// 배지·빈 화면 안내에 쓰는 그림 (루틴 아이콘 고르기에는 나오지 않는다).
const _otherIcons = <String, String>{
  '🌱': 'sprout',
  '🌕': 'full_moon',
  '🌈': 'rainbow',
  '🍀': 'clover',
  '🌳': 'tree',
  '🏡': 'home_tree',
  '🛋': 'sofa',
  '👕': 'tshirt',
  '⭐': 'star',
  '🌟': 'star_sparkle',
  '📭': 'mailbox',
  '📦': 'box',
  '💌': 'letter',
  '🪙': 'coin',
  '🏆': 'trophy',
};

/// 같은 그림으로 이어 주는 이모지 (예전에 저장된 값 등)
const _aliases = <String, String>{'🌅': 'sun', '☀': 'sun', '👟': 'shoe', '❤': 'heart', '📝': 'note', '🎶': 'music'};

/// 아이콘 고르기에 보여 줄 이모지 목록.
final routineIconChoices = routineIconAssets.keys.toList(growable: false);

/// 이모지 뒤에 붙는 꾸밈 문자(U+FE0F)를 떼고 짝을 찾는다.
String? routineIconAsset(String emoji) {
  final key = String.fromCharCodes(emoji.runes.where((r) => r != 0xFE0F)).trim();
  final name = routineIconAssets[key] ?? _otherIcons[key] ?? _aliases[key];
  return name == null ? null : 'assets/icons/$name.png';
}

class RoutineIcon extends StatelessWidget {
  const RoutineIcon(this.emoji, {super.key, this.size = 28});
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = routineIconAsset(emoji);
    if (asset == null) return Text(emoji, style: TextStyle(fontSize: size * 0.86));
    return Image.asset(
      asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Text(emoji, style: TextStyle(fontSize: size * 0.86)),
    );
  }
}

/// '🌤️ 일어나기'처럼 이모지와 이름이 붙어 저장된 글을 아이콘 + 이름으로 보여 준다.
class RoutineLabel extends StatelessWidget {
  const RoutineLabel(this.label, {super.key, this.style, this.iconSize = 22});
  final String label;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final i = label.indexOf(' ');
    if (i <= 0 || routineIconAsset(label.substring(0, i)) == null) {
      return Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Row(
      children: [
        RoutineIcon(label.substring(0, i), size: iconSize),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label.substring(i + 1), style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
