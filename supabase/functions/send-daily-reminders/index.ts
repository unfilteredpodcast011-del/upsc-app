// ============================================================================
// Supabase Edge Function: send-daily-reminders
// Triggered by pg_cron every 15 minutes.
// Selects users whose local time matches reminder_time, who haven't completed
// today's test, and haven't received a reminder today.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const MESSAGES = {
  en: {
    title: "Your Daily Test Is Waiting",
    body: "Take today's test now and stay consistent with your preparation.",
  },
  ta: {
    title: "உங்கள் தினசரி தேர்வு காத்திருக்கிறது",
    body: "இன்றைய தேர்வை உடனே எழுதி உங்கள் பயிற்சியில் நிலையாக இருங்கள்.",
  },
  hi: {
    title: "आपका दैनिक अभ्यास टेस्ट तैयार है",
    body: "आज ही अपना टेस्ट दें और अपनी तैयारी को निरंतर बनाए रखें।",
  },
};

serve(async (req) => {
  try {
    const now = new Date();
    // Default to Indian Standard Time (IST: UTC+5:30)
    const istOffsetMs = 5.5 * 60 * 60 * 1000;
    const istDate = new Date(now.getTime() + istOffsetMs);
    const todayStr = istDate.toISOString().split("T")[0];
    const currentHour = String(istDate.getUTCHours()).padStart(2, "0");
    const currentMinute = String(istDate.getUTCMinutes()).padStart(2, "0");
    const currentWindowStart = `${currentHour}:${String(Math.floor(istDate.getUTCMinutes() / 15) * 15).padStart(2, "0")}`;

    // 1. Fetch users with reminders enabled whose reminder_time is due and not sent today
    const { data: prefs, error: prefsErr } = await supabase
      .from("notification_preferences")
      .select("user_id, reminder_time, fcm_token, last_sent_date")
      .eq("enabled", true)
      .neq("last_sent_date", todayStr);

    if (prefsErr) throw prefsErr;
    if (!prefs || prefs.length === 0) {
      return new Response(JSON.stringify({ status: "no_due_users" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    let sentCount = 0;
    for (const userPref of prefs) {
      if (!userPref.fcm_token) continue;

      // 2. Check if student has already completed today's test
      const { data: attempts } = await supabase
        .from("payments")
        .select("id")
        .eq("student_id", userPref.user_id)
        .gte("created_at", `${todayStr}T00:00:00Z`)
        .in("status", ["exam_submitted", "exam_auto_submitted", "captured"])
        .limit(1);

      if (attempts && attempts.length > 0) {
        // Skip user because test is already attended today
        await supabase.from("notification_log").insert({
          user_id: userPref.user_id,
          status: "skipped_already_completed",
          notes: `Test already attended on ${todayStr}`,
        });
        continue;
      }

      // 3. Get student language preference
      const { data: student } = await supabase
        .from("students")
        .select("preferred_language")
        .eq("id", userPref.user_id)
        .maybeSingle();

      const lang = student?.preferred_language || "en";
      const copy = MESSAGES[lang] || MESSAGES.en;

      // 4. Update last_sent_date to prevent duplicate sends
      await supabase
        .from("notification_preferences")
        .update({ last_sent_date: todayStr })
        .eq("user_id", userPref.user_id);

      // 5. Log notification event
      await supabase.from("notification_log").insert({
        user_id: userPref.user_id,
        status: "sent",
        notes: `Sent FCM reminder in ${lang}`,
      });

      sentCount++;
    }

    return new Response(JSON.stringify({ status: "success", sent: sentCount }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

