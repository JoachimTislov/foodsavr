/// Generic service interface for CRUD operations
/// Services should implement this interface to ensure consistency
abstract class IService<T, ID> {
  /// Get an entity by ID
  Future<T?> get(ID id);
  
  /// Get all entities
  Future<List<T>> getAll();
  
  /// Add a new entity
  Future<T> add(T entity);
  
  /// Update an existing entity
  Future<void> update(T entity);
  
  /// Delete an entity by ID
  Future<void> delete(ID id);
}
