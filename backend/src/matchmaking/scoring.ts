/**
 * Pure matchmaking scoring. Kept dependency-free so it can be unit tested in
 * isolation. Scores are weights; the engine selects candidates
 * probabilistically among the top scorers.
 */

export type LevelRank = 1 | 2 | 3 | 4 | 5 | 6;

export const LANGUAGE_LEVEL_ORDER: string[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

export function levelRank(level?: string): LevelRank {
  const idx = LANGUAGE_LEVEL_ORDER.indexOf(level ?? '');
  return (idx >= 0 ? idx + 1 : 3) as LevelRank; // unknown -> assume B1-ish middle
}

export const SCORE_WEIGHTS = {
  languageCompatibility: 30,
  speakingLevel: 25,
  interests: 15,
  conversationGoal: 10,
  agePreference: 5,
  genderPreference: 5,
  availabilityDuration: 5,
  randomness: 5,
  recentInteractionPenalty24h: -30,
  recentInteractionPenalty7d: -10,
  sameUserRepeatedPenalty: -30,
} as const;

export interface MatchFilters {
  language?: string;
  level?: string; // explicit level the user declared for searching
  preferredLevel?: { min?: string; max?: string };
  interests?: string[];
  genderPreference?: 'MALE' | 'FEMALE' | 'any';
  agePreference?: { min?: number; max?: number } | null;
  goal?: string;
  matchType?: string;
}

export interface CandidateProfile {
  userId: string;
  nativeLanguage: string;
  learningLanguage: string;
  englishLevel?: string;
  interests: string[];
  conversationGoals: string[];
  gender?: string;
  yearsOld?: number | null;
  isBanned: boolean;
  availableSeconds: number;
  blockedMe: boolean;
  iBlocked: boolean;
}

export interface InteractionHistory {
  // minutesSinceLastInteraction: null when never interacted
  lastMatchedMinutesAgo: number | null; // within this pair
  timesMatchedToday?: number;
}

export interface ScoredCandidate {
  candidate: CandidateProfile;
  score: number;
  reasons: Record<string, number>;
}

export function computeRecentInteractionPenalty(
  history: InteractionHistory,
): number {
  if (history.lastMatchedMinutesAgo === null) return 0;
  const minutes = history.lastMatchedMinutesAgo;
  const hours = minutes / 60;
  if (hours < 2) return -1000 as number; // hard exclusion period
  if (hours < 24) return SCORE_WEIGHTS.recentInteractionPenalty24h;
  if (hours < 7 * 24) return SCORE_WEIGHTS.recentInteractionPenalty7d;
  return 0;
}

export function filterCandidate(
  candidate: CandidateProfile,
  filters: MatchFilters,
): { pass: boolean; reason?: string } {
  if (candidate.isBanned || candidate.blockedMe || candidate.iBlocked) {
    return { pass: false, reason: candidate.isBanned ? 'banned' : 'blocked' };
  }

  // Language: only users learning English are in the pool at all, but if a
  // specific language filter was set, enforce it.
  if (
    filters.language &&
    candidate.learningLanguage &&
    filters.language.toLowerCase() !== candidate.learningLanguage.toLowerCase()
  ) {
    return { pass: false, reason: 'language' };
  }

  // Gender preference.
  if (filters.genderPreference && filters.genderPreference !== 'any') {
    if (candidate.gender && candidate.gender !== filters.genderPreference) {
      return { pass: false, reason: 'gender' };
    }
  }

  // Age preference.
  const agePref = filters.agePreference;
  if (agePref && agePref.min !== undefined && agePref.max !== undefined) {
    const age = candidate.yearsOld;
    if (age !== null && age !== undefined) {
      if (age < (agePref.min ?? 0) || age > (agePref.max ?? 200)) {
        return { pass: false, reason: 'age' };
      }
    }
  }

  // Level window: if the user wants a specific band, candidate must be inside.
  const pref = filters.preferredLevel;
  if (pref && pref.min && pref.max) {
    const cand = levelRank(candidate.englishLevel);
    if (cand < levelRank(pref.min) || cand > levelRank(pref.max)) {
      return { pass: false, reason: 'level' };
    }
  }

  return { pass: true };
}

export function scoreCandidate(
  candidate: CandidateProfile,
  filters: MatchFilters,
  history: InteractionHistory,
): ScoredCandidate {
  const reasons: Record<string, number> = {};
  let score = 0;

  // 1. Language compatibility (30)
  const languageOk =
    !filters.language ||
    !candidate.learningLanguage ||
    filters.language.toLowerCase() === candidate.learningLanguage.toLowerCase();
  const languageScore = languageOk ? SCORE_WEIGHTS.languageCompatibility : 0;
  reasons.languageCompatibility = languageScore;
  score += languageScore;

  // 2. Speaking level proximity (25)
  const diff = Math.abs(
    levelRank(filters.level || 'B1') - levelRank(candidate.englishLevel),
  );
  const levelScore = Math.max(0, SCORE_WEIGHTS.speakingLevel - diff * 6);
  reasons.speakingLevel = levelScore;
  score += levelScore;

  // 3. Shared interests (15, cap)
  const sharedInterests = (candidate.interests ?? []).filter((i) =>
    (filters.interests ?? []).some((fi) => fi.toLowerCase() === i.toLowerCase()),
  ).length;
  const interestScore = Math.min(
    SCORE_WEIGHTS.interests,
    sharedInterests * SCORE_WEIGHTS.interests * 0.35,
  );
  reasons.interests = interestScore;
  score += interestScore;

  // 4. Conversation goal overlap (10)
  const goal = filters.goal?.toLowerCase();
  const goalMatch = goal
    ? (candidate.conversationGoals ?? []).some((g) =>
        g.toLowerCase().includes(goal),
      )
    : false;
  const goalScore = goalMatch ? SCORE_WEIGHTS.conversationGoal : 0;
  reasons.conversationGoal = goalScore;
  score += goalScore;

  // 5. Age preference satisfaction (5)
  const agePref = filters.agePreference;
  if (agePref && candidate.yearsOld !== null && candidate.yearsOld !== undefined) {
    const inBand =
      candidate.yearsOld >= (agePref.min ?? 0) &&
      candidate.yearsOld <= (agePref.max ?? 200);
    reasons.agePreference = inBand ? SCORE_WEIGHTS.agePreference : 0;
    score += inBand ? SCORE_WEIGHTS.agePreference : 0;
  }

  // 6. Gender preference satisfaction (5)
  if (filters.genderPreference && filters.genderPreference !== 'any') {
    const matches =
      !candidate.gender || candidate.gender === filters.genderPreference;
    reasons.genderPreference = matches ? SCORE_WEIGHTS.genderPreference : 0;
    score += matches ? SCORE_WEIGHTS.genderPreference : 0;
  }

  // 7. Availability duration bonus (5) - reward users waiting longer
  const availScore = Math.min(
    SCORE_WEIGHTS.availabilityDuration,
    Math.floor(candidate.availableSeconds / 60) * 0.5,
  );
  reasons.availabilityDuration = availScore;
  score += availScore;

  // 8. Randomness (0..5) to avoid deterministic chains
  const randomScore = Math.random() * SCORE_WEIGHTS.randomness;
  reasons.randomness = randomScore;
  score += randomScore;

  // 9. Penalties
  const recency = computeRecentInteractionPenalty(history);
  reasons.recentInteractionPenalty = recency === -1000 ? 0 : recency;
  score += recency === -1000 ? 0 : recency;

  if ((history.timesMatchedToday ?? 0) > 2) {
    reasons.sameUserRepeatedPenalty = SCORE_WEIGHTS.sameUserRepeatedPenalty;
    score += SCORE_WEIGHTS.sameUserRepeatedPenalty;
  }

  return { candidate, score: Math.round(score), reasons };
}

/**
 * Weighted random selection among top candidates. Prevents the same user from
 * always being chosen. Returns one candidate, or null.
 */
export function selectWeightedRandom(
  scored: ScoredCandidate[],
  topN = 5,
): ScoredCandidate | null {
  if (scored.length === 0) return null;
  const sorted = [...scored].sort((a, b) => b.score - a.score);
  const top = sorted.slice(0, topN);
  const floor = 40; // no candidate below this weight should win by luck alone
  const pool = top.filter((c) => c.score >= floor);
  const usable = pool.length > 0 ? pool : top;
  const total = usable.reduce((sum, c) => sum + Math.max(0, c.score), 0);
  if (total <= 0) return top[0];

  let roll = Math.random() * total;
  for (const c of usable) {
    roll -= Math.max(0, c.score);
    if (roll <= 0) return c;
  }
  return usable[usable.length - 1];
}