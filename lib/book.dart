/// Fachliches Datenmodell fuer ein Buch im Katalog.
/// Das Modell bleibt bewusst klein und gut lesbar, enthaelt aber schon genug
/// Informationen, um typische Microservice-Aufgaben zu zeigen:
/// Identifikation, Metadaten und den aktuellen Ausleihzustand.
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.year,
    required this.available,
    this.borrower,
    this.borrowedAt,
    this.dueDate,
  });

  static const Object _unset = Object();

  final int id;
  final String title;
  final String author;
  final int year;
  final bool available;
  final String? borrower;
  final DateTime? borrowedAt;
  final DateTime? dueDate;

  /// Erstellt eine veraenderte Kopie des Buchs.
  /// Fuer nullable Felder wird ein Sentinel verwendet, damit zwischen
  /// "unveraendert lassen" und "explizit auf null setzen" unterschieden werden
  /// kann.
  Book copyWith({
    int? id,
    String? title,
    String? author,
    int? year,
    bool? available,
    Object? borrower = _unset,
    Object? borrowedAt = _unset,
    Object? dueDate = _unset,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      year: year ?? this.year,
      available: available ?? this.available,
      borrower: identical(borrower, _unset)
          ? this.borrower
          : borrower as String?,
      borrowedAt: identical(borrowedAt, _unset)
          ? this.borrowedAt
          : borrowedAt as DateTime?,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
    );
  }

  /// Markiert das Buch als ausgeliehen und speichert die Leihinformationen.
  Book markBorrowed({
    required String borrower,
    required DateTime borrowedAt,
    required DateTime dueDate,
  }) {
    return copyWith(
      available: false,
      borrower: borrower,
      borrowedAt: borrowedAt.toUtc(),
      dueDate: dueDate.toUtc(),
    );
  }

  /// Legt das Buch wieder ins Regal und entfernt alte Leihinformationen.
  Book markReturned() {
    return copyWith(
      available: true,
      borrower: null,
      borrowedAt: null,
      dueDate: null,
    );
  }

  /// JSON-Format fuer API-Antworten.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'year': year,
      'available': available,
      'borrower': borrower,
      'borrowedAt': borrowedAt?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
    };
  }
}
