import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_memory.dart';

/// Fora do navegador (testes): banco em memória.
IdbFactory getIdbFactory() => idbFactoryMemory;
