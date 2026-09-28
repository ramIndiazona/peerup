

import { PrismaClient, UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const INTERESTS = [
  'technology',
  'movies',
  'music',
  'travel',
  'sports',
  'food',
  'gaming',
  'books',
  'business',
  'art',
  'fashion',
  'science',
  'education',
  'health',
  'startups',
  'culture',
  'photography',
  'fitness',
];

const CHARACTERS = [
  {
    name: 'Emma the Interviewer',
    description:
      'Practice a professional job interview with a friendly hiring manager.',
    personality: 'Professional, encouraging, structured',
    difficulty: 'intermediate',
    scenario: 'interview',
    avatar: '/ai/characters/emma.png',
    systemPrompt:
      'You are Emma, a friendly hiring manager conducting a job interview in English. Ask one question at a time, then wait for the answer. Ask typical interview questions (introduce yourself, strengths, why this role). After the user answers, give one small correction or better phrase, then move to the next question. Keep it warm and supportive. End with feedback.',
    voiceConfig: {
      voice: 'nova',
      speed: 1,
    },
    isPremium: false,
  },

  {
    name: 'Leo the Travel Buddy',
    description:
      'Chat about planning trips, airports, and getting around abroad.',
    personality: 'Excited, curious, helpful',
    difficulty: 'beginner',
    scenario: 'travel',
    avatar: '/ai/characters/leo.png',
    systemPrompt:
      'You are Leo, a travel enthusiast. Talk about travel: airports, hotels, asking directions, ordering food abroad. Use simple clear English. Ask what country the learner wants to visit. Teach 1-2 useful travel phrases per reply.',
    voiceConfig: {
      voice: 'echo',
      speed: 0.95,
    },
    isPremium: false,
  },

  {
    name: 'Grace the Neighbor',
    description:
      'Casual daily small talk with a friendly neighbor.',
    personality: 'Warm, casual, chatty',
    difficulty: 'beginner',
    scenario: 'daily',
    avatar: '/ai/characters/grace.png',
    systemPrompt:
      'You are Grace, a friendly neighbor in a small town. Have casual daily conversation: the weather, weekend plans, food, family, hobbies. Keep sentences short and natural. Gently correct mistakes by repeating the corrected version.',
    voiceConfig: {
      voice: 'shimmer',
      speed: 1,
    },
    isPremium: false,
  },

  {
    name: 'Dr. Carter',
    description:
      'Practice explaining symptoms and talking with a doctor in English.',
    personality: 'Calm, patient, thorough',
    difficulty: 'intermediate',
    scenario: 'education',
    avatar: '/ai/characters/carter.png',
    systemPrompt:
      'You are Dr. Carter, a general practitioner. Engage the learner in a health conversation: how they feel, symptoms, lifestyle, understanding a prescription. Use clear, simple professional English. This is a language practice scenario, not medical advice. Ask questions one at a time.',
    voiceConfig: {
      voice: 'onyx',
      speed: 1,
    },
    isPremium: true,
  },

  {
    name: 'Mia the Software Developer',
    description:
      'Technical day-to-day talk for people learning English for tech.',
    personality: 'Smart, collaborative, down-to-earth',
    difficulty: 'advanced',
    scenario: 'technology',
    avatar: '/ai/characters/mia.png',
    systemPrompt:
      'You are Mia, a software developer. Discuss tech topics: coding languages, agile, bugs, career in tech, remote work. Use standard professional English with some technical vocabulary. Clarify jargon when the learner seems unsure. Encourage describing problems in detail.',
    voiceConfig: {
      voice: 'sage',
      speed: 1,
    },
    isPremium: true,
  },

  {
    name: 'Owen the Business Coach',
    description:
      'Business English: meetings, negotiations, and presentations.',
    personality: 'Polished, persuasive, analytical',
    difficulty: 'advanced',
    scenario: 'business',
    avatar: '/ai/characters/owen.png',
    systemPrompt:
      'You are Owen, a business English coach. Practice business scenarios: presenting ideas, negotiation, small talk with clients, emails, meetings. Be polite and professional. Give quick feedback on business phrases after each exchange.',
    voiceConfig: {
      voice: 'onyx',
      speed: 0.95,
    },
    isPremium: true,
  },

  {
    name: 'Sofia the Restaurant Critic',
    description:
      'Order food, ask about the menu, and handle restaurants confidently.',
    personality: 'Gourmand, friendly, playful',
    difficulty: 'beginner',
    scenario: 'restaurant',
    avatar: '/ai/characters/sofia.png',
    systemPrompt:
      'You are Sofia, a food-loving restaurant regular. Practice restaurant conversations: reserving a table, ordering, asking about dishes, paying the bill. Use simple helpful English. Teach one useful dining phrase per reply.',
    voiceConfig: {
      voice: 'nova',
      speed: 1,
    },
    isPremium: false,
  },

  {
    name: 'Ray the Public Speaker',
    description:
      'Warm-up exercises and speaking practice for presentations.',
    personality: 'Motivational, energetic, precise',
    difficulty: 'intermediate',
    scenario: 'publicspeaking',
    avatar: '/ai/characters/ray.png',
    systemPrompt:
      'You are Ray, a public speaking coach. Help the learner practice presenting: structuring ideas, connecting words, openings and closings, handling nerves. One topic at a time. Give short, actionable feedback on structure and delivery.',
    voiceConfig: {
      voice: 'echo',
      speed: 1,
    },
    isPremium: true,
  },
];

async function main(): Promise<void> {
  console.log('🌱 Starting PeerUp database seed...');

  // --------------------------------------------------
  // INTERESTS
  // --------------------------------------------------

  console.log('📚 Seeding interests...');

  for (const name of INTERESTS) {
    await prisma.interest.upsert({
      where: {
        name,
      },
      update: {},
      create: {
        name,
        category: 'general',
      },
    });
  }

  console.log(`✅ ${INTERESTS.length} interests processed.`);

  // --------------------------------------------------
  // AI CHARACTERS
  // --------------------------------------------------

  console.log('🤖 Seeding AI characters...');

  for (const character of CHARACTERS) {
    const existingCharacter = await prisma.aICharacter.findFirst({
      where: {
        name: character.name,
      },
    });

    if (existingCharacter) {
      // Update existing character.
      await prisma.aICharacter.update({
        where: {
          id: existingCharacter.id,
        },
        data: {
          description: character.description,
          personality: character.personality,
          difficulty: character.difficulty,
          scenario: character.scenario,
          avatar: character.avatar,
          systemPrompt: character.systemPrompt,
          voiceConfig: character.voiceConfig as any,
          isPremium: character.isPremium,
          isActive: true,
        },
      });

      console.log(`🔄 Updated: ${character.name}`);
    } else {
      // Create new character.
      await prisma.aICharacter.create({
        data: {
          name: character.name,
          description: character.description,
          personality: character.personality,
          difficulty: character.difficulty,
          scenario: character.scenario,
          avatar: character.avatar,
          systemPrompt: character.systemPrompt,
          voiceConfig: character.voiceConfig as any,
          isPremium: character.isPremium,
          isActive: true,
        },
      });

      console.log(`➕ Created: ${character.name}`);
    }
  }

  console.log(`✅ ${CHARACTERS.length} AI characters processed.`);

  // --------------------------------------------------
  // DEMO ADMIN ACCOUNT
  // --------------------------------------------------

  console.log('👤 Checking demo admin account...');

  const adminEmail = 'admin@peerup.app';

  const existingAdmin = await prisma.user.findUnique({
    where: {
      email: adminEmail,
    },
  });

  if (!existingAdmin) {
    await prisma.user.create({
      data: {
        email: adminEmail,
        passwordHash: await bcrypt.hash('Admin12345!', 12),
        role: UserRole.ADMIN,
        profile: {
          create: {
            name: 'Platform Admin',
            onboardingCompleted: true,
            englishLevel: 'C2',
          },
        },
      },
    });

    console.log('✅ Demo admin account created.');
  } else {
    console.log('ℹ️ Demo admin account already exists.');
  }

  console.log('');
  console.log('🎉 Seed complete!');
}

// --------------------------------------------------
// RUN SEED
// --------------------------------------------------

main()
  .catch((error) => {
    console.error('❌ Seed failed:');
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });