/// Generic repository interface for data access operations
/// Repositories should implement this interface to ensure consistency
/// across different implementations (Firestore, in-memory, SQL, etc.)
abstract class IRepository<T, ID> {
  /// Add a new entity
  Future<T> add(T entity);

  /// Get an entity by ID
  Future<T?> get(ID id);

  /// Update an existing entity
  Future<void> update(T entity);

  /// Delete an entity by ID
  Future<void> delete(ID id);

  /// Get all entities
  Future<List<T>> getAll();
}
