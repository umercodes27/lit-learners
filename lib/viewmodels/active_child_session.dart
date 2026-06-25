import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';

class ActiveChildSession extends ChangeNotifier {
  ActiveChildSession();

  ChildProfile? _activeChild;

  ChildProfile? get activeChild => _activeChild;

  void selectProfile(ChildProfile profile) {
    _activeChild = profile;
    notifyListeners();
  }

  void clear() {
    _activeChild = null;
    notifyListeners();
  }
}
