/// Escapes LIKE/ILIKE wildcards (`%`, `_`) and the escape character itself
/// so user text is matched literally.
String escapeLike(String input) => input
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');
