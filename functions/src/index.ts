import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import Razorpay from "razorpay";
import { GoogleGenerativeAI } from "@google/generative-ai";

admin.initializeApp();
const db = admin.firestore();

// 1. Create Razorpay Order Server-Side (Rs. 1 / 100 paise)
export const createRazorpayOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const { testId, userId } = data;
  const razorpay = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID || "rzp_test_YourKeyIdHere",
    key_secret: process.env.RAZORPAY_KEY_SECRET || "YourRazorpaySecretHere",
  });

  const options = {
    amount: 100, // Rs. 1 in paise
    currency: "INR",
    receipt: `rcpt_${userId.substring(0, 5)}_${Date.now()}`,
    notes: { testId, userId },
  };

  const order = await razorpay.orders.create(options);

  await db.collection("payments").doc(order.id).set({
    orderId: order.id,
    userId,
    testId,
    amountPaise: 100,
    currency: "INR",
    status: "created",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { orderId: order.id };
});

// 2. Verify Payment Signature (HMAC SHA-256) & Unlock Test
export const verifyPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const { orderId, paymentId, signature, testId } = data;
  const userId = context.auth.uid;
  const secret = process.env.RAZORPAY_KEY_SECRET || "YourRazorpaySecretHere";

  const generatedSignature = crypto
    .createHmac("sha256", secret)
    .update(`${orderId}|${paymentId}`)
    .digest("hex");

  if (generatedSignature.toLowerCase() === signature.toLowerCase()) {
    await db.collection("payments").doc(orderId).set({
      status: "captured",
      paymentId,
      signature,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await db.collection("user_unlocked_tests").doc(`${userId}_${testId}`).set({
      userId,
      testId,
      orderId,
      unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } else {
    throw new functions.https.HttpsError("invalid-argument", "Signature verification failed");
  }
});

// 3. Daily Scheduled Midnight IST Trigger: Auto-build daily test
export const createDailyTestMidnight = functions.pubsub
  .schedule("0 0 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const today = new Date().toISOString().split("T")[0];
    const exams = ["UPSC", "TNPSC"];

    for (const exam of exams) {
      const qSnap = await db.collection("questions")
        .where("exam", "==", exam)
        .where("publishDate", "==", today)
        .where("status", "==", "published")
        .limit(20)
        .get();

      const qIds = qSnap.docs.map((d) => d.id);
      if (qIds.length > 0) {
        const testId = `daily_${exam.toLowerCase()}_${today.replace(/-/g, "")}`;
        await db.collection("tests").doc(testId).set({
          id: testId,
          title: `Daily ${exam} Practice - ${today}`,
          type: "daily",
          exam,
          subject: "Daily Mock",
          questionCount: qIds.length,
          questionIds: qIds,
          defaultDurationSeconds: qIds.length * 60,
          priceInPaise: 100,
          publishDate: today,
          isLive: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // Send FCM Notification
        await admin.messaging().send({
          topic: `${exam.toLowerCase()}_students`,
          notification: {
            title: `Today's ${exam} Daily Test is Live!`,
            body: `Test your skills with today's ${qIds.length} fresh practice questions.`,
          },
        });
      }
    }
  });

// 4. Gemini AI MCQ Generator (Admin draft generator)
export const generateQuestionsWithGemini = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const { exam, subject, topic, ncertChapter, count } = data;
  const apiKey = process.env.GEMINI_API_KEY || "";
  if (!apiKey) {
    throw new functions.https.HttpsError("failed-precondition", "GEMINI_API_KEY is not configured.");
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

  const prompt = `Generate ${count || 5} original Multiple Choice Questions for ${exam} examination.
Subject: ${subject}
Topic: ${topic}
NCERT Reference: ${ncertChapter}

Return ONLY a JSON array with objects matching this exact structure:
[
  {
    "question_en": "Question text in English",
    "option_a": "Option A text",
    "option_b": "Option B text",
    "option_c": "Option C text",
    "option_d": "Option D text",
    "correct_answer": "A",
    "explanation": "Detailed explanation",
    "difficulty": "medium"
  }
]`;

  const result = await model.generateContent(prompt);
  const responseText = result.response.text();
  const cleaned = responseText.replace(/```json/g, "").replace(/```/g, "").trim();
  const mcqs = JSON.parse(cleaned);

  const batch = db.batch();
  for (const mcq of mcqs) {
    const qId = `q_ai_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const ref = db.collection("questions").doc(qId);
    batch.set(ref, {
      id: qId,
      exam,
      subject,
      topic,
      ncertChapter,
      difficulty: mcq.difficulty || "medium",
      status: "draft",
      correctAnswer: mcq.correct_answer,
      translations: {
        en: {
          question: mcq.question_en,
          options: { a: mcq.option_a, b: mcq.option_b, c: mcq.option_c, d: mcq.option_d },
          explanation: mcq.explanation,
        },
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  return { count: mcqs.length };
});

// 5. Admin Promotion Tool
export const setAdminRole = functions.https.onCall(async (data, context) => {
  const { targetEmail } = data;
  const user = await admin.auth().getUserByEmail(targetEmail);
  await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  await db.collection("users").doc(user.uid).update({ role: "admin" });
  return { success: true };
});

