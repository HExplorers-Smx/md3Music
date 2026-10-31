enum VisualStyleMode {
  material3('Material 3', '标准 Material 3'),
  expressive('Material 3 Expressive', '更鲜明的形状与动态'),
  miuixGlass('MIUIX + 液态玻璃', '连续圆角、柔和表面及玻璃材质');

  const VisualStyleMode(this.label, this.description);
  final String label;
  final String description;

  static VisualStyleMode parse(String? saved) {
    for (final style in values) {
      if (style.name == saved) return style;
    }
    return VisualStyleMode.expressive;
  }
}
