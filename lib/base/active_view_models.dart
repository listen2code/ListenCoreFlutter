import 'base_view_model.dart';
import '../route/app_nav.dart';

typedef IntentObserver = void Function(String viewModelTag, dynamic intent);
typedef EffectObserver = void Function(String viewModelTag, dynamic effect);

class MviPlaybackObserver {
  static IntentObserver? onIntentDispatched;
  static EffectObserver? onEffectEmitted;
}

class ActiveViewModels {
  static final Map<String, BaseViewModel> _active = {};
  static final Map<String, String> _tagToRoute = {};

  static void register(String tag, BaseViewModel viewModel) {
    _active[tag] = viewModel;
    final currentRoute = AppNav.currentRouteName;
    if (currentRoute != null) {
      _tagToRoute[tag] = currentRoute;
    }
  }

  static void unregister(String tag) {
    _active.remove(tag);
    _tagToRoute.remove(tag);
  }

  static BaseViewModel? get(String tag) {
    return _active[tag];
  }

  static String? getRoute(String tag) {
    return _tagToRoute[tag];
  }

  static Map<String, BaseViewModel> get all => Map.unmodifiable(_active);
}
