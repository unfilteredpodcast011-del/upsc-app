import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req) => {
  try {
    const rawBody = await req.text();
    const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";
    const sigHeader = req.headers.get("x-razorpay-signature") ?? "";

    if (webhookSecret) {
      const expected = await hmacSha256Hex(webhookSecret, rawBody);
      if (expected !== sigHeader) {
        console.error("[webhook] Invalid X-Razorpay-Signature");
        return new Response("Invalid signature", { status: 400 });
      }
    }

    const event = JSON.parse(rawBody);
    const eventType = event.event;
    console.log(`[webhook] Received event: ${eventType}`);

    const payment = event.payload?.payment?.entity;
    if (!payment) {
      return new Response("OK", { status: 200 });
    }

    const paymentId = payment.id;
    const orderId = payment.order_id;
    const amountPaise = payment.amount;
    const notes = payment.notes || {};
    const status = eventType === "payment.failed" ? "failed" : "captured";

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Idempotent check by razorpay_payment_id or razorpay_order_id
    const { data: existing } = await supabase
      .from("payments")
      .select("id, status")
      .or(`razorpay_payment_id.eq.${paymentId},razorpay_order_id.eq.${orderId}`)
      .maybeSingle();

    if (existing) {
      if (existing.status !== "captured") {
        await supabase
          .from("payments")
          .update({
            razorpay_payment_id: paymentId,
            amount_paise: amountPaise,
            status,
          })
          .eq("id", existing.id);
        console.log(`[webhook] Updated existing payment ${paymentId} -> ${status}`);
      } else {
        console.log(`[webhook] Idempotent skip: ${paymentId} already captured`);
      }
    } else {
      await supabase.from("payments").insert({
        student_id: notes.userId && notes.userId.includes("-") ? notes.userId : null,
        test_id: notes.testId && notes.testId.includes("-") ? notes.testId : null,
        razorpay_order_id: orderId || `wh_${paymentId}`,
        razorpay_payment_id: paymentId,
        amount_paise: amountPaise,
        status,
      });
      console.log(`[webhook] Inserted new payment ${paymentId} -> ${status}`);
    }

    return new Response("OK", { status: 200 });
  } catch (err) {
    console.error("[webhook] Error:", err);
    return new Response("Webhook error", { status: 400 });
  }
});
