import '../book.dart';
import 'api_exception.dart';
import 'book_repository.dart';

/// Fachlogik fuer den Bibliothekskatalog.
/// Diese Klasse enthaelt bewusst keine HTTP-spezifischen Typen. Dadurch kann
/// sie direkt in Unit-Tests verwendet und spaeter auch aus anderen
/// Transport-Schichten angesprochen werden.
class CatalogService {
  CatalogService({
    BookRepository? repository,
    Map<int, Book>? seedBooks,
    DateTime Function()? clock,
  }) : assert(
         repository == null || seedBooks == null,
         'repository und seedBooks duerfen nicht gleichzeitig gesetzt werden',
       ),
       _repository = repository ?? InMemoryBookRepository(seedBooks: seedBooks),
       _clock = clock ?? DateTime.now;

  final BookRepository _repository;
  final DateTime Function() _clock;

  List<Book> listBooks({bool? available, String? search, String? author}) {
    final normalizedSearch = _normalize(search);
    final normalizedAuthor = _normalize(author);

    return _repository.list().where((book) {
      if (available != null && book.available != available) {
        return false;
      }

      if (normalizedSearch != null) {
        final haystack = '${book.title} ${book.author}'.toLowerCase();
        if (!haystack.contains(normalizedSearch)) {
          return false;
        }
      }

      if (normalizedAuthor != null &&
          !book.author.toLowerCase().contains(normalizedAuthor)) {
        return false;
      }

      return true;
    }).toList();
  }

  Book findBook(int id) {
    final book = _repository.findById(id);
    if (book == null) {
      throw ApiException.notFound(
        'Buch $id wurde nicht gefunden',
        code: 'book_not_found',
      );
    }

    return book;
  }

  Book createBook(Map<String, dynamic> payload) {
    _ensureAllowedKeys(payload, const {'title', 'author', 'year'});

    final book = Book(
      id: _repository.nextId(),
      title: _readRequiredString(payload, 'title'),
      author: _readRequiredString(payload, 'author'),
      year: _readRequiredYear(payload, 'year'),
      available: true,
    );

    return _repository.save(book);
  }

  Book updateBook(int id, Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      throw ApiException.badRequest(
        'PATCH benoetigt mindestens ein Feld',
        code: 'empty_patch',
      );
    }

    _ensureAllowedKeys(payload, const {'title', 'author', 'year'});

    final current = findBook(id);
    final updated = current.copyWith(
      title: payload.containsKey('title')
          ? _readRequiredString(payload, 'title')
          : current.title,
      author: payload.containsKey('author')
          ? _readRequiredString(payload, 'author')
          : current.author,
      year: payload.containsKey('year')
          ? _readRequiredYear(payload, 'year')
          : current.year,
    );

    return _repository.save(updated);
  }

  Book deleteBook(int id) {
    final deleted = _repository.delete(id);
    if (deleted == null) {
      throw ApiException.notFound(
        'Buch $id wurde nicht gefunden',
        code: 'book_not_found',
      );
    }

    return deleted;
  }

  Book borrowBook(int id, {Map<String, dynamic> payload = const {}}) {
    _ensureAllowedKeys(payload, const {'borrower', 'loanDays'});

    final current = findBook(id);
    if (!current.available) {
      throw ApiException.conflict(
        'Buch $id ist bereits ausgeliehen',
        code: 'book_unavailable',
      );
    }

    final borrower =
        _readOptionalString(payload, 'borrower') ?? 'Unbekannter Nutzer';
    final loanDays = _readOptionalLoanDays(payload, 'loanDays') ?? 14;
    final borrowedAt = _clock().toUtc();
    final dueDate = borrowedAt.add(Duration(days: loanDays));

    final updated = current.markBorrowed(
      borrower: borrower,
      borrowedAt: borrowedAt,
      dueDate: dueDate,
    );

    return _repository.save(updated);
  }

  Book returnBook(int id) {
    final current = findBook(id);
    if (current.available) {
      throw ApiException.conflict(
        'Buch $id ist bereits verfuegbar',
        code: 'book_already_available',
      );
    }

    final updated = current.markReturned();
    return _repository.save(updated);
  }

  Map<String, dynamic> statistics() {
    final books = _repository.list();
    final totalBooks = books.length;
    final availableBooks = books.where((book) => book.available).length;
    final borrowedBooks = totalBooks - availableBooks;

    final years = books.map((book) => book.year).toList();
    final oldestPublicationYear = years.isEmpty ? null : years.reduce(_min);
    final newestPublicationYear = years.isEmpty ? null : years.reduce(_max);

    return {
      'totalBooks': totalBooks,
      'availableBooks': availableBooks,
      'borrowedBooks': borrowedBooks,
      'oldestPublicationYear': oldestPublicationYear,
      'newestPublicationYear': newestPublicationYear,
    };
  }

  void _ensureAllowedKeys(
    Map<String, dynamic> payload,
    Set<String> allowedKeys,
  ) {
    for (final key in payload.keys) {
      if (!allowedKeys.contains(key)) {
        throw ApiException.badRequest(
          'Feld "$key" wird von dieser Operation nicht unterstuetzt',
          code: 'unknown_field',
        );
      }
    }
  }

  String _readRequiredString(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      throw ApiException.badRequest(
        'Feld "$key" fehlt oder ist leer',
        code: 'invalid_$key',
      );
    }

    return value.trim();
  }

  String? _readOptionalString(Map<String, dynamic> payload, String key) {
    if (!payload.containsKey(key)) {
      return null;
    }

    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      throw ApiException.badRequest(
        'Feld "$key" muss ein nicht-leerer Text sein',
        code: 'invalid_$key',
      );
    }

    return value.trim();
  }

  int _readRequiredYear(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is! int) {
      throw ApiException.badRequest(
        'Feld "$key" muss eine ganze Zahl sein',
        code: 'invalid_$key',
      );
    }

    final maxYear = _clock().year + 1;
    if (value < 1450 || value > maxYear) {
      throw ApiException.badRequest(
        'Feld "$key" liegt ausserhalb des erlaubten Bereichs',
        code: 'invalid_$key',
      );
    }

    return value;
  }

  int? _readOptionalLoanDays(Map<String, dynamic> payload, String key) {
    if (!payload.containsKey(key)) {
      return null;
    }

    final value = payload[key];
    if (value is! int || value <= 0 || value > 90) {
      throw ApiException.badRequest(
        'Feld "$key" muss eine ganze Zahl zwischen 1 und 90 sein',
        code: 'invalid_$key',
      );
    }

    return value;
  }
}

String? _normalize(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return trimmed.toLowerCase();
}

int _min(int left, int right) => left < right ? left : right;
int _max(int left, int right) => left > right ? left : right;
