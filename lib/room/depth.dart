/// 깊이 정렬 대상 (점유 직사각형)
class DepthItem {
  const DepthItem(this.id, this.x, this.y, this.w, this.d);
  final String id;
  final int x;
  final int y;
  final int w;
  final int d;

  /// 이 물체를 [o]보다 나중에(앞에) 그려야 하는가
  bool inFrontOf(DepthItem o) => x >= o.x + o.w || y >= o.y + o.d;
}

/// 아이소메트릭 깊이 순서 (뒤 → 앞). docs/asset-system/02 §8.
/// 점유가 겹치지 않는 직사각형끼리는 '앞에 있다' 관계에 순환이 없다.
List<DepthItem> depthSort(Iterable<DepthItem> items) {
  final rest = [...items];
  final out = <DepthItem>[];
  int tie(DepthItem a, DepthItem b) {
    final s = (a.x + a.y).compareTo(b.x + b.y);
    return s != 0 ? s : a.id.compareTo(b.id);
  }

  while (rest.isNotEmpty) {
    // 남은 것 중 '확실히 앞'인 상대가 없는 것(=가장 뒤)부터 꺼낸다
    final cand = rest
        .where((a) => !rest.any((b) => !identical(a, b) && a.inFrontOf(b) && !b.inFrontOf(a)))
        .toList()
      ..sort(tie);
    final pick = cand.isNotEmpty ? cand.first : (rest..sort(tie)).first;
    out.add(pick);
    rest.remove(pick);
  }
  return out;
}
