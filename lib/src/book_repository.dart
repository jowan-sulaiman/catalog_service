import '../book.dart';

/// Minimales Repository-Interface.
/// Fuer den Unterricht reicht eine In-Memory-Implementierung. Durch das
/// Interface sieht man aber bereits die saubere Trennung zwischen
/// Fachlogik und Persistenz.
abstract class BookRepository {
  List<Book> list();
  Book? findById(int id);
  Book save(Book book);
  Book? delete(int id);
  int nextId();
}

/// Einfache In-Memory-Datenhaltung fuer lokale Tests und Demos.
class InMemoryBookRepository implements BookRepository {
  InMemoryBookRepository({Map<int, Book>? seedBooks})
    : _books = seedBooks != null
          ? Map<int, Book>.from(seedBooks)
          : buildDefaultCatalogSeedBooks(),
      _nextId = _calculateNextId(seedBooks ?? buildDefaultCatalogSeedBooks());

  final Map<int, Book> _books;
  int _nextId;

  @override
  List<Book> list() {
    final books = _books.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return books;
  }

  @override
  Book? findById(int id) {
    return _books[id];
  }

  @override
  Book save(Book book) {
    _books[book.id] = book;
    return book;
  }

  @override
  Book? delete(int id) {
    return _books.remove(id);
  }

  @override
  int nextId() {
    final nextId = _nextId;
    _nextId += 1;
    return nextId;
  }
}

/// Standarddaten fuer den Unterricht.
Map<int, Book> buildDefaultCatalogSeedBooks() {
  return {
    1: const Book(
      id: 1,
      title: 'Clean Code',
      author: 'Robert C. Martin',
      year: 2008,
      available: true,
    ),
    2: const Book(
      id: 2,
      title: 'Design Patterns',
      author: 'Erich Gamma',
      year: 1994,
      available: true,
    ),
    3: Book(
      id: 3,
      title: 'Domain-Driven Design',
      author: 'Eric Evans',
      year: 2003,
      available: false,
      borrower: 'Lea Schulz',
      borrowedAt: DateTime.utc(2026, 3, 15, 9, 0),
      dueDate: DateTime.utc(2026, 3, 29, 9, 0),
    ),
  };
}

int _calculateNextId(Map<int, Book> books) {
  if (books.isEmpty) {
    return 1;
  }

  final highestId = books.keys.reduce(
    (left, right) => left > right ? left : right,
  );
  return highestId + 1;
}
