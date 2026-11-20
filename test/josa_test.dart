import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/ui/widgets.dart';

void main() {
  test('받침을 보고 조사를 고른다', () {
    expect(josa('일어나기', '은', '는'), '는');
    expect(josa('물 마시기', '을', '를'), '를');
    expect(josa('점심 챙겨 먹기', '이', '가'), '가');
    expect(josa('출근', '은', '는'), '은');
    expect(josa('둥근 러그', '을', '를'), '를');
    expect(josa('책상', '이', '가'), '이');
    expect(josa('Yoga', '은', '는'), '은(는)'); // 한글이 아니면 둘 다
    expect(josa('', '을', '를'), '을(를)');
  });
}
