import { ValidationPipe } from '@nestjs/common';
import { RegisterDto } from './auth.dto';
import { ALLOWED_AVATARS } from '../../common/constants/profile-avatars';

const pipe = new ValidationPipe({ whitelist: true, transform: true, transformOptions: { enableImplicitConversion: true } });
const validate = (extra: object) => pipe.transform({
  email: 'alex@example.com', password: 'SuperSecret123', name: 'Alex', ...extra,
}, { type: 'body', metatype: RegisterDto });

describe('registration avatars', () => {
  it.each(ALLOWED_AVATARS)('accepts %s', async (avatar) => {
    expect((await validate({ avatar })).avatar).toBe(avatar);
  });
  it('preserves older clients that omit avatar', async () => {
    expect((await validate({})).avatar).toBeUndefined();
  });
  it.each(['../../file', '/random-image.png', '/user-uploaded-image', 'https://example.com/a.png', '', 'avatar_07', null, ['avatar_01'], 1])('rejects invalid avatar %p', async (avatar) => {
    await expect(validate({ avatar })).rejects.toThrow();
  });
});
