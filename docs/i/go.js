// 친구 초대 링크: https://alsdud110.github.io/haru_sari/i/?code=K7QM3XPD
// iPhone·iPad → App Store, Android → Play 스토어(코드를 referrer 로 실어 설치 뒤 앱이 읽는다), 그 밖 → 두 버튼과 코드.
//
// 보안
// - 이동할 곳은 아래 두 스토어 주소로 고정한다. 주소창의 값으로 이동할 곳을 정하지 않는다 (오픈 리다이렉트 방지).
// - 코드는 lib/data/friends.dart InviteCode 와 같은 글자(헷갈리는 0 O 1 I L 제외) 8자만 받고, 화면에는 textContent 로만 넣는다.
(function () {
  'use strict';
  var APP_STORE = 'https://apps.apple.com/app/id6834387060';
  var PLAY = 'https://play.google.com/store/apps/details?id=com.harusari.app';
  var VALID = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$/;

  function readCode() {
    var raw = '';
    try {
      raw = new URLSearchParams(window.location.search).get('code') || '';
    } catch (e) {
      return null;
    }
    if (raw.length > 40) return null;
    var c = raw.replace(/[\s-]/g, '').toUpperCase();
    if (c.length === 12 && c.indexOf('HARU') === 0) c = c.slice(4);
    return VALID.test(c) ? c : null;
  }

  var code = readCode();
  var play = code ? PLAY + '&referrer=' + encodeURIComponent('code=' + code) : PLAY;
  document.getElementById('android').href = play;

  if (code) {
    document.getElementById('code').textContent = 'HARU-' + code.slice(0, 4) + '-' + code.slice(4);
    document.getElementById('codebox').hidden = false;
  }

  var ua = navigator.userAgent || '';
  // iPadOS 13+ 사파리는 데스크톱(Macintosh)으로 보이므로 터치 지원으로 가린다
  var ios = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var android = /Android/.test(ua);
  var target = ios ? APP_STORE : android ? play : null;
  if (target) {
    document.getElementById('moving').hidden = false;
    window.location.replace(target);
  }
})();
