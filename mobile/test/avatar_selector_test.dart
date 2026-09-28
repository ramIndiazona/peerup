import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerup/core/config/profile_avatars.dart';
import 'package:peerup/core/widgets/avatar_selector.dart';
import 'package:peerup/core/widgets/user_avatar.dart';
import 'package:peerup/models/auth_result.dart';

void main() {
  testWidgets('selecting another avatar replaces the previous selection', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder:
                (context, setState) => AvatarSelector(
                  selected: selected,
                  onSelected: (id) => setState(() => selected = id),
                ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.tap(find.byKey(const ValueKey('avatar_01')));
    await tester.pumpAndSettle();
    expect(selected, 'avatar_01');
    await tester.tap(find.byKey(const ValueKey('avatar_03')));
    await tester.pumpAndSettle();
    expect(selected, 'avatar_03');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved avatar resolves to a bundled asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UserAvatar(url: 'avatar_03'))),
    );
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      (avatar.foregroundImage! as AssetImage).assetName,
      'assets/avatars/avatar_03.png',
    );
    expect(ProfileAvatars.assetPath('../../file'), isNull);
  });

  test('identity cache preserves avatar and supports old identities', () {
    final json = {
      'id': 'id',
      'email': 'a@b.com',
      'name': 'Alex',
      'onboardingCompleted': false,
    };
    expect(UserIdentity.fromJson(json).avatar, isNull);
    final identity = UserIdentity.fromJson({...json, 'avatar': 'avatar_02'});
    expect(UserIdentity.fromJson(identity.toJson()).avatar, 'avatar_02');
  });
}
