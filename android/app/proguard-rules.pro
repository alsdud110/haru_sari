# WorkManager / Room: Room 은 생성된 *_Impl 클래스를 리플렉션(no-arg 생성자)으로 만든다.
# R8 full mode 가 생성자를 지우면 앱 시작 시 WorkManager 초기화가 실패하므로 남겨 둔다.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
