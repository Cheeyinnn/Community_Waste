import 'ipoh_data.dart';
import 'kampar_data.dart';

/// One entry point for syncing the built-in Perak collection coverage.
///
/// Kampar is updated non-destructively. Ipoh is rebuilt only inside the MBI
/// authority scope so an older location-only Ipoh seed cannot leave obsolete
/// schedule documents behind. Data belonging to other authorities is never
/// deleted by this sync.
class PerakCollectionData {
  PerakCollectionData._();

  static Future<void> sync() async {
    await KamparData.seedOrUpdate();
    await IpohData.resetAndSeed();
  }

  /// Rebuilds the built-in Kampar + Ipoh datasets. Each seeder deletes only
  /// documents belonging to its own local authority.
  static Future<void> resetAndSeed() async {
    await KamparData.resetAndSeed();
    await IpohData.resetAndSeed();
  }
}
