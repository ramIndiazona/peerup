export default () => ({
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3100', 10),
  appName: process.env.APP_NAME || 'peerup',
  apiPrefix: process.env.API_PREFIX || 'api',
  database: {
    url: process.env.DATABASE_URL,
  },
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    refreshSecret: process.env.JWT_REFRESH_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
    issuer: process.env.JWT_ISSUER || 'peerup',
  },
  webrtc: {
    reconnectTimeoutSeconds: Math.max(1, Number(process.env.CALL_RECONNECT_TIMEOUT_SECONDS) || 15),
    stunUrl: process.env.STUN_URL || 'stun:stun.l.google.com:19302',
    turnUrl: process.env.TURN_URL,
    turnUsername: process.env.TURN_USERNAME,
    turnCredential: process.env.TURN_CREDENTIAL,
  },
  matchmaking: {
    matchTimeoutSeconds: parseInt(process.env.MATCH_TIMEOUT_SECONDS || '20', 10),
    maxCandidatesPerScan: parseInt(process.env.MATCH_MAX_CANDIDATES || '50', 10),
    webRtcTimeoutSeconds: parseInt(process.env.WEBRTC_TIMEOUT_SECONDS || '30', 10),
    postCallAvailabilitySeconds: parseInt(process.env.POST_CALL_AVAILABLE_SECONDS || '3', 10),
  },
  heartbeat: {
    intervalSeconds: parseInt(process.env.HEARTBEAT_INTERVAL_SECONDS || '15', 10),
    timeoutSeconds: parseInt(process.env.HEARTBEAT_TIMEOUT_SECONDS || '45', 10),
  },
  limits: {
    dailyVoiceCalls: parseInt(process.env.DAILY_VOICE_CALLS || '20', 10),
    dailyAIConversations: parseInt(process.env.DAILY_AI_CONVERSATIONS || '10', 10),
    dailyAISeconds: parseInt(process.env.DAILY_AI_SECONDS || '1800', 10),
    premiumDailyAIConversations: parseInt(process.env.PREMIUM_DAILY_AI_CONVERSATIONS || '50', 10),
    premiumDailyAISeconds: parseInt(process.env.PREMIUM_DAILY_AI_SECONDS || '7200', 10),
    samePairCooldownHours: parseInt(process.env.SAME_PAIR_COOLDOWN_HOURS || '24', 10),
    recentPairCooldownHours: parseInt(process.env.RECENT_PAIR_COOLDOWN_HOURS || '2', 10),
    disposableCount: parseInt(process.env.MATCH_MAX_DISPOSABLE_CANDIDATES || '40', 10),
  },
  ai: {
    provider: process.env.AI_PROVIDER || 'openai',
    openaiApiKey: process.env.OPENAI_API_KEY,
    openaiModel: process.env.OPENAI_MODEL || 'gpt-4o-mini',
    sttProvider: process.env.STT_PROVIDER || 'openai',
    ttsProvider: process.env.TTS_PROVIDER || 'openai',
    moderationEnabled: process.env.AI_MODERATION_ENABLED === 'true',
    feedbackModel: process.env.AI_FEEDBACK_MODEL || 'gpt-4o-mini',

    ollamaUrl:
      process.env.OLLAMA_URL || 'http://localhost:11434',
    ollamaModel:
      process.env.OLLAMA_MODEL || 'gemma4:e2b',
      
  },
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY,
    enabled: process.env.FIREBASE_ENABLED === 'true',
  },
  storage: {
    endpoint: process.env.STORAGE_ENDPOINT,
    bucket: process.env.STORAGE_BUCKET,
    accessKey: process.env.STORAGE_ACCESS_KEY,
    secretKey: process.env.STORAGE_SECRET_KEY,
    region: process.env.STORAGE_REGION || 'us-east-1',
    publicUrl: process.env.STORAGE_PUBLIC_URL,
  },
  sentry: {
    dsn: process.env.SENTRY_DSN,
  },
  payment: {
    provider: process.env.PAYMENT_PROVIDER || 'none',
  },
  cors: {
    origins: (process.env.CORS_ORIGINS || 'http://localhost:3100,http://localhost:3000,http://localhost:8080')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  },
  tz: process.env.USER_TZ || 'UTC',
});