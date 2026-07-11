/// 動詞分類。
enum VerbGroup {
  godan('五段（I 類）'),
  ichidan('一段（II 類）'),
  irregular('不規則（III 類）');

  final String label;
  const VerbGroup(this.label);
}

/// 變化形。
enum VerbForm {
  masu('ます形'),
  te('て形'),
  nai('ない形'),
  ta('た形');

  final String label;
  const VerbForm(this.label);
}

/// N5 動詞：辭書形 + 四個變化形。
class Verb {
  final String dict; // 辞書形（顯示字）
  final String reading; // 假名讀音
  final String zh;
  final VerbGroup group;
  final String masu;
  final String te;
  final String nai;
  final String ta;

  const Verb({
    required this.dict,
    required this.reading,
    required this.zh,
    required this.group,
    required this.masu,
    required this.te,
    required this.nai,
    required this.ta,
  });

  String get key => 'vb_$dict';

  String formOf(VerbForm form) => switch (form) {
        VerbForm.masu => masu,
        VerbForm.te => te,
        VerbForm.nai => nai,
        VerbForm.ta => ta,
      };
}
