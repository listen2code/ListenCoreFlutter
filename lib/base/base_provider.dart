import '../core.dart';

/// A central registry for managing global provider implementations and effect routing.
class ProviderRegistry {
  ProviderRegistry._();

  static final List<BaseProvider<BaseEffect>> _providers = [];

  /// Registers a list of global provider implementations.
  static void init(List<BaseProvider<BaseEffect>> providers) {
    _providers.clear();
    _providers.addAll(providers);
  }

  /// Dispatches an effect to its registered provider.
  /// Iterates through providers and uses explicit type checking for robustness.
  /// Returns true if a handler was found and the effect was processed.
  static bool handle(BaseEffect effect) {
    for (final provider in _providers) {
      if (provider.canHandle(effect)) {
        provider.handle(effect);
        return true;
      }
    }
    return false;
  }
}

/// Base interface for all architecture providers.
/// Establishes a type-safe relationship between an effect [E] and its executor.
abstract class BaseProvider<E extends BaseEffect> {
  const BaseProvider();

  /// Checks if this provider can handle the given [effect].
  /// Uses 'is' check which is obfuscation-safe and supports inheritance.
  bool canHandle(BaseEffect effect) => effect is E;

  /// Polymorphic entry point to process an effect.
  /// Automatically casts the effect to its concrete type [E].
  void handle(BaseEffect effect) {
    if (effect is E) {
      handleEffect(effect);
    }
  }

  /// Concrete logic to process the specific effect [E].
  /// To be implemented by the shared layer providers.
  void handleEffect(E effect);
}
