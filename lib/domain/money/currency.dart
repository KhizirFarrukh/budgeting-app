/// A currency and, crucially, its minor-unit exponent.
///
/// The exponent is what makes every stored amount interpretable: 12345 minor
/// units is 123.45 in a 2-exponent currency, 12345 in a 0-exponent currency
/// such as JPY, and 12.345 in a 3-exponent currency such as KWD.
///
/// **Nothing in this project may hardcode two decimal places** (substage 3.6's
/// `must_not`). The exponent is stored once at onboarding and drives all
/// parsing and formatting thereafter.
///
/// Immutable once any ledger entry exists (SCHEMA §6 rule V-24), because every
/// stored amount is interpreted through it — changing it later would silently
/// reinterpret history rather than convert it.
class Currency {
  const Currency({required this.code, required this.minorUnitExponent})
    : assert(
        minorUnitExponent == 0 ||
            minorUnitExponent == 2 ||
            minorUnitExponent == 3,
        'ISO 4217 minor unit exponents in use are 0, 2 and 3 (SCHEMA C-12)',
      );

  /// ISO 4217 code, e.g. `PKR`, `USD`, `JPY`, `KWD`.
  final String code;

  /// Digits after the decimal separator: 0, 2 or 3.
  final int minorUnitExponent;

  /// 10^[minorUnitExponent] — how many minor units make one major unit.
  ///
  /// Computed by integer multiplication, never `pow()`, which returns a
  /// floating-point value and would put a `double` on the money path (INV-01).
  int get minorUnitsPerMajor {
    int result = 1;
    for (int i = 0; i < minorUnitExponent; i++) {
      result *= 10;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          minorUnitExponent == other.minorUnitExponent;

  @override
  int get hashCode => Object.hash(code, minorUnitExponent);

  @override
  String toString() => 'Currency($code, exp=$minorUnitExponent)';
}
