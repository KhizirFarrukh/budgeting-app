import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'codegen_probe.g.dart';

/// A deliberately trivial provider that exists only to prove the Riverpod code
/// generator runs end to end (substage 3.3.3).
///
/// **Substage 6.1 replaces this** with the real provider graph — repository
/// streams and use-case results. Nothing should be built on it.
///
/// Proving both generators before Stage 4 begins is the point: a generator
/// misconfiguration discovered while writing the first real table costs a
/// session to diagnose.
@riverpod
String codegenProbe(Ref ref) => 'codegen-ok';
