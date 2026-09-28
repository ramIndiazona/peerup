# Registration avatars

The existing Prisma `Profile.avatar String?` field stores one stable ID:
`avatar_01` through `avatar_06`. No schema change, migration, data reset, or
Prisma generation is required.

Registration details → Choose your avatar → Create account → existing
language/goals/interests onboarding → Home. The registration screen retains
one selection in its existing local form state, including after API/network
errors and when returning to details. The existing AuthCubit → AuthService →
AuthRepository chain sends the ID in JSON. No upload or picker is involved.

POST /api/auth/register example:

```json
{
  "email": "alex@example.com",
  "password": "SuperSecret123",
  "name": "Alex",
  "englishLevel": "B1",
  "avatar": "avatar_03"
}
```

The new mobile flow requires an explicit choice. The API permits omission for
existing clients (including backend/test/e2e-script.ts), storing null. Explicit
null, unknown IDs, arrays, URLs and paths are rejected by the existing global
ValidationPipe / VALIDATION_ERROR response. Login/register return `user.avatar`;
private/public profile and matching responses already expose the existing field.
The identity cache retains it through onboarding.

Assets are bundled at `mobile/assets/avatars/avatar_01.png` through
`avatar_06.png`. These are copies of existing backend/public/ai/characters
images, in order: emma, leo, grace, carter, mia, sofia. No images were generated
or downloaded. Replace those six files with approved artwork using the same
filenames if desired. IDs must remain synchronized between
`backend/src/common/constants/profile-avatars.ts` and
`mobile/lib/core/config/profile_avatars.dart`.

UserAvatar centrally resolves these IDs to local assets, while retaining support
for legacy profile URLs and initials. Profile, public profile, live-user preview,
matching, calls, edit profile and the Home header use this widget. The existing
backend static server and authenticated legacy storage/profile APIs are unchanged;
registration never calls them.

Validation commands:

```sh
cd backend
npm test -- --runInBand
npm run build
cd ../mobile
flutter analyze
flutter test
flutter run
```

Manual integration check with backend/Postgres/Redis running: register with one
avatar, complete onboarding, inspect Home/profile, then log out and back in.
Check that choosing another avatar deselects the first and that an API/network
failure preserves the choice for retry. Attempt a URL/path ID via HTTP and
confirm HTTP 400. Existing callers omitting avatar should still register.

## Changed files

- Backend: `src/common/constants/profile-avatars.ts`, `src/auth/dto/auth.dto.ts`,
  `src/auth/auth.service.ts`, `src/auth/dto/auth.dto.spec.ts`,
  `src/auth/auth.service.spec.ts`.
- Mobile: `lib/core/config/profile_avatars.dart`,
  `lib/core/widgets/avatar_selector.dart`, `lib/core/widgets/user_avatar.dart`,
  `lib/core/auth/auth_repository.dart`, `lib/core/auth/auth_service.dart`,
  `lib/features/auth/bloc/auth_cubit.dart`,
  `lib/features/auth/presentation/register_screen.dart`, `lib/models/auth_result.dart`,
  `lib/features/onboarding/onboarding_screen.dart`,
  `lib/features/home/presentation/match_home_screen.dart`,
  `lib/features/profile/presentation/edit_profile_screen.dart`,
  `pubspec.yaml`, `assets/avatars/avatar_01.png`–`avatar_06.png`,
  `test/avatar_selector_test.dart`.
- Documentation: `docs/registration-avatars.md`.

## Verification results

- Backend build passed; focused auth DTO/service tests passed.
- Flutter tests passed (4 tests, including existing login routing).
- Full backend suite has two failures in unchanged
  `presence.service.spec.ts` expectations for `redis.decr`.
- Flutter analysis reports four existing findings: two async-context infos in
  AI chat, a missing widget key info in AI modes, and an unused `theme` warning
  in the Home screen.
- Live database/device end-to-end registration was not run. Persistence is
  covered by a mocked Prisma service test, not a live database test.
