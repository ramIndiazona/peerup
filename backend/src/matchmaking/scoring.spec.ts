import {
  computeRecentInteractionPenalty,
  filterCandidate,
  levelRank,
  scoreCandidate,
  selectWeightedRandom,
  SCORE_WEIGHTS,
} from './scoring';

const baseCandidate = {
  userId: 'u1',
  nativeLanguage: 'Spanish',
  learningLanguage: 'English',
  englishLevel: 'B1',
  interests: ['movies', 'music'],
  conversationGoals: ['fluency', 'job interview'],
  gender: 'FEMALE',
  yearsOld: 24,
  isBanned: false,
  blockedMe: false,
  iBlocked: false,
  availableSeconds: 120,
};

describe('levelRank', () => {
  it('maps known levels to ranks', () => {
    expect(levelRank('A1')).toBe(1);
    expect(levelRank('C2')).toBe(6);
  });
  it('defaults unknown/empty to B1 (3)', () => {
    expect(levelRank(undefined)).toBe(3);
    expect(levelRank('ZZ')).toBe(3);
  });
});

describe('filterCandidate', () => {
  it('rejects banned / blocked candidates', () => {
    expect(filterCandidate({ ...baseCandidate, isBanned: true }, {}).pass).toBe(false);
    expect(filterCandidate({ ...baseCandidate, blockedMe: true }, {}).pass).toBe(false);
    expect(filterCandidate({ ...baseCandidate, iBlocked: true }, {}).pass).toBe(false);
  });
  it('enforces language filter', () => {
    const r = filterCandidate(baseCandidate, { language: 'french' });
    expect(r.pass).toBe(false);
    expect(filterCandidate(baseCandidate, { language: 'english' }).pass).toBe(true);
  });
  it('enforces gender preference', () => {
    expect(filterCandidate(baseCandidate, { genderPreference: 'MALE' }).pass).toBe(false);
    expect(filterCandidate(baseCandidate, { genderPreference: 'FEMALE' }).pass).toBe(true);
  });
  it('enforces level window', () => {
    expect(
      filterCandidate(baseCandidate, { preferredLevel: { min: 'C1', max: 'C2' } }).pass,
    ).toBe(false);
    expect(
      filterCandidate(baseCandidate, { preferredLevel: { min: 'A1', max: 'B2' } }).pass,
    ).toBe(true);
  });
  it('passes when no filters set', () => {
    expect(filterCandidate(baseCandidate, {}).pass).toBe(true);
  });
});

describe('computeRecentInteractionPenalty', () => {
  it('hard-excludes pairs matched under 2h ago', () => {
    const p = computeRecentInteractionPenalty({ lastMatchedMinutesAgo: 30 });
    expect(p).toBe(-1000);
    expect(computeRecentInteractionPenalty({ lastMatchedMinutesAgo: null })).toBe(0);
  });
  it('applies 24h then 7d penalties', () => {
    expect(computeRecentInteractionPenalty({ lastMatchedMinutesAgo: 6 * 60 })).toBe(
      SCORE_WEIGHTS.recentInteractionPenalty24h,
    );
    expect(computeRecentInteractionPenalty({ lastMatchedMinutesAgo: 48 * 60 })).toBe(
      SCORE_WEIGHTS.recentInteractionPenalty7d,
    );
  });
});

describe('scoreCandidate', () => {
  it('always includes language + speaking-level weight on a compatible candidate', () => {
    const s = scoreCandidate(baseCandidate, { level: 'B1', language: 'english' }, {
      lastMatchedMinutesAgo: null,
    });
    expect(s.reasons.languageCompatibility).toBe(SCORE_WEIGHTS.languageCompatibility);
    expect(s.reasons.speakingLevel).toBeGreaterThan(0);
  });
  it('penalizes repeated matches today', () => {
    const s = scoreCandidate(baseCandidate, {}, {
      lastMatchedMinutesAgo: null,
      timesMatchedToday: 5,
    });
    expect(s.reasons.sameUserRepeatedPenalty).toBe(SCORE_WEIGHTS.sameUserRepeatedPenalty);
  });
  it('does not apply hard -1000 penalty into score (only soft penalties)', () => {
    const s = scoreCandidate(baseCandidate, {}, { lastMatchedMinutesAgo: 90 });
    // -1000 becomes a soft exclusion that selection uses separately; the score
    // reflects only the standard 24h penalty range.
    expect(s.score).toBeGreaterThan(-1000);
  });
});

describe('selectWeightedRandom', () => {
  it('returns null for empty list', () => {
    expect(selectWeightedRandom([], 5)).toBeNull();
  });
  it('returns exactly one candidate from the pool', () => {
    const scored = [
      { candidate: { ...baseCandidate, userId: 'a' }, score: 40, reasons: {} },
      { candidate: { ...baseCandidate, userId: 'b' }, score: 60, reasons: {} },
      { candidate: { ...baseCandidate, userId: 'c' }, score: 20, reasons: {} },
    ];
    const pick = selectWeightedRandom(scored, 5);
    expect(pick).toBeTruthy();
    expect(['a', 'b', 'c']).toContain(pick!.candidate.userId);
  });
  it('overwhelming favorite wins near-certainly', () => {
    const scored = [
      { candidate: { ...baseCandidate, userId: 'big' }, score: 1000, reasons: {} },
      { candidate: { ...baseCandidate, userId: 'small' }, score: 1, reasons: {} },
    ];
    let bigWins = 0;
    for (let i = 0; i < 200; i += 1) {
      if (selectWeightedRandom(scored, 5)!.candidate.userId === 'big') bigWins += 1;
    }
    expect(bigWins).toBeGreaterThan(190);
  });
});