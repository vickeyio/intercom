enum IntercomRole {
  director,
  crew,
}

extension IntercomRoleX on IntercomRole {
  String get label => switch (this) {
        IntercomRole.director => 'Director',
        IntercomRole.crew => 'Crew',
      };
}

