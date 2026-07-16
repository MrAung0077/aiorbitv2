import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/brain_status.dart';

final brainStatusProvider = StateProvider<BrainStatus?>((ref) => null);

final brainOverlayVisibleProvider = StateProvider<bool>((ref) => false);
