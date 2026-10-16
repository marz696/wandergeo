// Format tampilan untuk halaman Paspor Digital.

String passportShortHash(String h) =>
    h.length > 14 ? '${h.substring(0, 8)}…${h.substring(h.length - 6)}' : h;

String _two(int n) => n.toString().padLeft(2, '0');

String passportDate(DateTime t) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${t.day} ${m[t.month - 1]} ${t.year}';
}

String passportDateTime(DateTime t) =>
    '${passportDate(t)} · ${_two(t.hour)}:${_two(t.minute)}';
