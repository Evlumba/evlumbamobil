class SearchIntentService {
  const SearchIntentService._();

  static const _professionalTerms = {
    'mimar',
    'mimarlar',
    'mimari',
    'mimarlik',
    'tasarimci',
    'tasarimcisi',
    'dekorator',
    'dekorasyoncu',
    'profesyonel',
    'uzman',
    'usta',
    'ustasi',
    'boya',
    'boyaci',
    'elektrikci',
    'tesisatci',
    'marangoz',
    'mobilyaci',
    'insaat',
    'peyzaj',
    'architect',
    'designer',
  };

  static const _projectTerms = {
    'mutfak',
    'banyo',
    'salon',
    'oda',
    'yatak',
    'cocuk',
    'ofis',
    'antre',
    'bahce',
    'balkon',
    'teras',
    'japandi',
    'modern',
    'minimal',
    'minimalist',
    'bohem',
    'rustik',
    'klasik',
    'ahsap',
    'mermer',
    'renovasyon',
    'tadilat',
  };

  static const _stopWords = {
    've',
    'ile',
    'icin',
    'bir',
    'en',
    'olan',
    'ariyorum',
    'ara',
  };

  static bool isProfessionalQuery(String query) {
    final tokens = queryTokens(query);
    if (tokens.isEmpty) return false;

    final hasProfessionalTerm = tokens.any(_professionalTerms.contains);
    if (!hasProfessionalTerm) return false;

    final hasProjectTerm = tokens.any(_projectTerms.contains);
    final professionalCount = tokens.where(_professionalTerms.contains).length;
    final projectCount = tokens.where(_projectTerms.contains).length;

    return !hasProjectTerm || professionalCount >= projectCount;
  }

  static List<String> queryTokens(String value) {
    return normalize(value)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length > 1 && !_stopWords.contains(token))
        .toList();
  }

  static String normalize(String value) {
    return value
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .toLowerCase()
        .replaceAll('\u0307', '')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }
}
