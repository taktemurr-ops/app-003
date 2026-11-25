import 'package:flutter_test/flutter_test.dart';
import 'package:uyg_su_icme_hatirlatici/uyg_su_icme_hatirlatici.dart';

void main() {
  test('33 dilde ad ve açıklama, doğru kimlik', () {
    expect(suIcmeHatirlaticiTool.id, suIcmeHatirlaticiId);
    expect(suIcmeHatirlaticiTool.title.length, 33);
    expect(suIcmeHatirlaticiTool.tagline.length, 33);
  });
}
