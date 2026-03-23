import 'dart:io';

import 'package:catalog_service/catalog_service.dart';
import 'package:test/test.dart';

void main() {
  group('CatalogService', () {
    test('legt ein neues verfuegbares Buch an', () {
      final service = CatalogService(seedBooks: {});

      final created = service.createBook({
        'title': 'Patterns of Enterprise Application Architecture',
        'author': 'Martin Fowler',
        'year': 2002,
      });

      expect(created.id, equals(1));
      expect(created.available, isTrue);
      expect(
        created.title,
        equals('Patterns of Enterprise Application Architecture'),
      );
    });

    test('filtert Buecher nach Verfuegbarkeit und Suchbegriff', () {
      final service = CatalogService(
        seedBooks: {
          1: const Book(
            id: 1,
            title: 'Clean Code',
            author: 'Robert C. Martin',
            year: 2008,
            available: true,
          ),
          2: const Book(
            id: 2,
            title: 'Clean Architecture',
            author: 'Robert C. Martin',
            year: 2017,
            available: false,
          ),
          3: const Book(
            id: 3,
            title: 'Refactoring',
            author: 'Martin Fowler',
            year: 1999,
            available: true,
          ),
        },
      );

      final filtered = service.listBooks(available: true, search: 'clean');

      expect(filtered.map((book) => book.id), equals([1]));
    });

    test('wirft Bad Request bei leerem Titel', () {
      final service = CatalogService(seedBooks: {});

      expect(
        () => service.createBook({
          'title': '   ',
          'author': 'Martin Fowler',
          'year': 2002,
        }),
        throwsA(
          isA<ApiException>()
              .having(
                (error) => error.statusCode,
                'statusCode',
                HttpStatus.badRequest,
              )
              .having((error) => error.code, 'code', 'invalid_title'),
        ),
      );
    });

    test('markiert ein verfuegbares Buch als ausgeliehen', () {
      final service = CatalogService(
        seedBooks: {
          1: const Book(
            id: 1,
            title: 'Clean Architecture',
            author: 'Robert C. Martin',
            year: 2017,
            available: true,
          ),
        },
      );

      final updated = service.borrowBook(1);

      expect(updated.available, isFalse);
      expect(service.findBook(1).available, isFalse);
    });

    test('speichert Ausleihinformationen beim Borrow-Vorgang', () {
      final service = CatalogService(
        seedBooks: {
          1: const Book(
            id: 1,
            title: 'Team Topologies',
            author: 'Matthew Skelton',
            year: 2019,
            available: true,
          ),
        },
        clock: () => DateTime.utc(2026, 3, 22, 10, 30),
      );

      final updated = service.borrowBook(
        1,
        payload: {'borrower': 'Anna Becker', 'loanDays': 21},
      );

      expect(updated.available, isFalse);
      expect(updated.borrower, equals('Anna Becker'));
      expect(updated.borrowedAt, equals(DateTime.utc(2026, 3, 22, 10, 30)));
      expect(updated.dueDate, equals(DateTime.utc(2026, 4, 12, 10, 30)));
    });

    test('wirft Conflict wenn ein Buch bereits ausgeliehen ist', () {
      final service = CatalogService(
        seedBooks: {
          1: const Book(
            id: 1,
            title: 'Domain-Driven Design',
            author: 'Eric Evans',
            year: 2003,
            available: false,
          ),
        },
      );

      expect(
        () => service.borrowBook(1),
        throwsA(
          isA<ApiException>()
              .having(
                (error) => error.statusCode,
                'statusCode',
                HttpStatus.conflict,
              )
              .having((error) => error.code, 'code', 'book_unavailable'),
        ),
      );
    });

    test('patcht vorhandene Felder eines Buchs', () {
      final service = CatalogService(
        seedBooks: {
          1: const Book(
            id: 1,
            title: 'Working Effectively with Legacy Code',
            author: 'Michael Feathers',
            year: 2004,
            available: true,
          ),
        },
      );

      final updated = service.updateBook(1, {
        'title': 'Working Effectively with Legacy Code (2. Auflage)',
        'year': 2026,
      });

      expect(updated.title, contains('2. Auflage'));
      expect(updated.author, equals('Michael Feathers'));
      expect(updated.year, equals(2026));
    });

    test('loescht ein Buch aus dem Katalog', () {
      final service = CatalogService(
        seedBooks: {
          1: const Book(
            id: 1,
            title: 'Accelerate',
            author: 'Nicole Forsgren',
            year: 2018,
            available: true,
          ),
        },
      );

      final deleted = service.deleteBook(1);

      expect(deleted.id, equals(1));
      expect(() => service.findBook(1), throwsA(isA<ApiException>()));
    });

    test('liefert Statistik ueber den aktuellen Katalog', () {
      final service = CatalogService(
        seedBooks: {
          1: const Book(
            id: 1,
            title: 'Clean Code',
            author: 'Robert C. Martin',
            year: 2008,
            available: true,
          ),
          2: Book(
            id: 2,
            title: 'Domain-Driven Design',
            author: 'Eric Evans',
            year: 2003,
            available: false,
            borrower: 'Max',
            borrowedAt: DateTime.utc(2026, 3, 20),
            dueDate: DateTime.utc(2026, 4, 3),
          ),
        },
      );

      final stats = service.statistics();

      expect(stats['totalBooks'], equals(2));
      expect(stats['availableBooks'], equals(1));
      expect(stats['borrowedBooks'], equals(1));
      expect(stats['oldestPublicationYear'], equals(2003));
      expect(stats['newestPublicationYear'], equals(2008));
    });
  });
}
