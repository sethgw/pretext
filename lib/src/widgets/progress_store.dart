import 'package:pretext/src/document/document_cursor.dart';

/// Abstract interface for persisting reading progress.
abstract class ProgressStore {
  /// Load the saved cursor for [bookId]. Returns null if no saved position.
  Future<DocumentCursor?> load(String bookId);

  /// Save the current cursor for [bookId].
  Future<void> save(String bookId, DocumentCursor cursor);

  /// Clear saved progress for [bookId].
  Future<void> clear(String bookId);
}

/// A [ProgressStore] backed by user-provided callbacks.
///
/// This avoids requiring any specific persistence dependency (shared_preferences,
/// Hive, etc.) — the consumer provides the storage mechanism.
class CallbackProgressStore implements ProgressStore {
  final Future<String?> Function(String bookId) onLoad;
  final Future<void> Function(String bookId, String serialized) onSave;
  final Future<void> Function(String bookId) onClear;

  const CallbackProgressStore({
    required this.onLoad,
    required this.onSave,
    required this.onClear,
  });

  @override
  Future<DocumentCursor?> load(String bookId) async {
    final serialized = await onLoad(bookId);
    if (serialized == null) return null;
    return DocumentCursor.deserialize(serialized);
  }

  @override
  Future<void> save(String bookId, DocumentCursor cursor) async {
    await onSave(bookId, cursor.serialize());
  }

  @override
  Future<void> clear(String bookId) async {
    await onClear(bookId);
  }
}
