import 'package:flutter/material.dart';

import '../features/intercom/presentation/screens/intercom_screen.dart';
import '../features/intercom/presentation/screens/role_selection_screen.dart';
import '../features/intercom/presentation/screens/room_join_screen.dart';

class AppRoutes {
  static const String roleSelection = '/role';
  static const String roomJoin = '/room';
  static const String intercom = '/intercom';

  static Map<String, WidgetBuilder> get routes => <String, WidgetBuilder>{
        roleSelection: (_) => const RoleSelectionScreen(),
        roomJoin: (_) => const RoomJoinScreen(),
        intercom: (_) => const IntercomScreen(),
      };
}

