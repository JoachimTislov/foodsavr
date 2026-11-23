abstract class IAccountDataRepository {
  Future<void> deleteForUser(String userId);
}
