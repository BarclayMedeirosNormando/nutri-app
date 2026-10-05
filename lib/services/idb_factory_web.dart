import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';

/// No navegador: IndexedDB de verdade.
IdbFactory getIdbFactory() => idbFactoryBrowser;
