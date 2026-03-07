import * as admin from 'firebase-admin';
import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

admin.initializeApp();

const db = admin.firestore();

const summaryDocRef = (userId: string, dayKey: string) =>
  db.collection('users').doc(userId).collection('summaries').doc(dayKey);

type ThoughtData = {
  content?: string;
  mood?: string;
  tags?: string[];
  createdAt?: admin.firestore.Timestamp;
};

function dayKeyFromTimestamp(ts?: admin.firestore.Timestamp): string {
  const date = ts?.toDate() ?? new Date();
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  const d = String(date.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function normalizeTags(tags: string[] = []): string[] {
  return [...new Set(tags.map((tag) => tag.trim().toLowerCase()).filter(Boolean))];
}

export const onThoughtCreated = onDocumentCreated(
  'users/{userId}/thoughts/{thoughtId}',
  async (event) => {
    const userId = event.params.userId;
    const thought = (event.data?.data() ?? {}) as ThoughtData;
    const dayKey = dayKeyFromTimestamp(thought.createdAt);
    const tags = normalizeTags(thought.tags);
    const mood = (thought.mood ?? 'neutral').toLowerCase();

    const updates: Record<string, admin.firestore.FieldValue> = {
      totalThoughts: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      [`moodCounts.${mood}`]: admin.firestore.FieldValue.increment(1),
    };

    for (const tag of tags) {
      updates[`tagCounts.${tag}`] = admin.firestore.FieldValue.increment(1);
    }

    await summaryDocRef(userId, dayKey).set(updates, { merge: true });
  },
);

export const onThoughtDeleted = onDocumentDeleted(
  'users/{userId}/thoughts/{thoughtId}',
  async (event) => {
    const userId = event.params.userId;
    const thought = (event.data?.data() ?? {}) as ThoughtData;
    const dayKey = dayKeyFromTimestamp(thought.createdAt);
    const tags = normalizeTags(thought.tags);
    const mood = (thought.mood ?? 'neutral').toLowerCase();

    const updates: Record<string, admin.firestore.FieldValue> = {
      totalThoughts: admin.firestore.FieldValue.increment(-1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      [`moodCounts.${mood}`]: admin.firestore.FieldValue.increment(-1),
    };

    for (const tag of tags) {
      updates[`tagCounts.${tag}`] = admin.firestore.FieldValue.increment(-1);
    }

    await summaryDocRef(userId, dayKey).set(updates, { merge: true });
  },
);

export const getWeeklyInsights = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  const userId = request.auth.uid;
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - 6));

  const summarySnap = await db
    .collection('users')
    .doc(userId)
    .collection('summaries')
    .where(admin.firestore.FieldPath.documentId(), '>=', start.toISOString().slice(0, 10))
    .get();

  let totalThoughts = 0;
  const moodTotals: Record<string, number> = {};
  const tagTotals: Record<string, number> = {};

  for (const doc of summarySnap.docs) {
    const data = doc.data();
    totalThoughts += Number(data.totalThoughts ?? 0);

    const moodCounts = (data.moodCounts ?? {}) as Record<string, number>;
    for (const [mood, count] of Object.entries(moodCounts)) {
      moodTotals[mood] = (moodTotals[mood] ?? 0) + Number(count ?? 0);
    }

    const tagCounts = (data.tagCounts ?? {}) as Record<string, number>;
    for (const [tag, count] of Object.entries(tagCounts)) {
      tagTotals[tag] = (tagTotals[tag] ?? 0) + Number(count ?? 0);
    }
  }

  const topTags = Object.entries(tagTotals)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([tag, count]) => ({ tag, count }));

  return {
    totalThoughts,
    moodTotals,
    topTags,
  };
});
