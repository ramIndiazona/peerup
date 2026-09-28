/// Keep IDs in sync with backend/src/common/constants/profile-avatars.ts.
class ProfileAvatars {
  ProfileAvatars._();

  static const ids = <String>[
    'avatar_01',
    'avatar_02',
    'avatar_03',
    'avatar_04',
    'avatar_05',
    'avatar_06',
  ];

  static String? assetPath(String? id) =>
      ids.contains(id) ? 'assets/avatars/$id.png' : null;
}
