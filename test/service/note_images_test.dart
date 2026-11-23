import 'package:flutter_test/flutter_test.dart';
import 'package:modu_reader/service/remote_library/note_images.dart';

void main() {
  test('font tags become text and images stay addressable', () {
    final text = readableRemoteNote(
      '<font style="color:rgb(71, 193, 168);">面向对象的设计</font>\n'
      '<img src="https://cdn.example.com/a.png?x=1&amp;y=2" alt="示意图" />\n'
      '![keep](photo.png)\n',
    );
    expect(text.contains('<font'), isFalse);
    expect(text.contains('<img'), isFalse);
    expect(text, contains('面向对象的设计'));
    expect(text, contains('![示意图](https://cdn.example.com/a.png?x=1&y=2)'));
    expect(text, contains('![keep](photo.png)'));
  });

  test('escaped Yuque HTML becomes headings, links and text', () {
    final text = readableRemoteNote(
      '&lt;h2&gt;工具介绍&lt;/h2&gt;'
      '&lt;p&gt;&lt;font style="color:rgb(71, 193, 168);"&gt;面向对象的设计&lt;/font&gt;&lt;/p&gt;'
      '&lt;p&gt;&lt;a href="https://example.com/java"&gt;官网&lt;/a&gt;&lt;/p&gt;'
      '&lt;ul&gt;&lt;li&gt;&lt;strong&gt;轻量&lt;/strong&gt;&lt;/li&gt;&lt;/ul&gt;',
    );
    expect(text.contains('<'), isFalse);
    expect(text.contains('&lt;'), isFalse);
    expect(text, contains('## 工具介绍'));
    expect(text, contains('面向对象的设计'));
    expect(text, contains('[官网](https://example.com/java)'));
    expect(text, contains('**轻量**'));
  });

  test('a picture next to the note stays on the same server', () {
    final note = Uri.parse('http://139.224.60.166/notes/java.md');
    expect(
      resolveNoteImage(note, 'photo.png'),
      Uri.parse('http://139.224.60.166/notes/photo.png'),
    );
    expect(
      resolveNoteImage(note, 'https://cdn.nlark.com/yuque/a.png'),
      Uri.parse('https://cdn.nlark.com/yuque/a.png'),
    );
    expect(resolveNoteImage(note, 'javascript:alert(1)'), isNull);
  });
}
