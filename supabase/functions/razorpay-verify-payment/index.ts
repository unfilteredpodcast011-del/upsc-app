import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { orderId, paymentId, signature, userId, testId, amountPaise } = await req.json();
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!orderId || !paymentId || !signature) {
      throw new Error("Missing orderId, paymentId, or signature");
    }

    const expectedSig = await hmacSha256Hex(keySecret, `${orderId}|${paymentId}`);
    if (expectedSig !== signature) {
      console.error(`[verify-payment] Signature mismatch for order=${orderId}`);
      return new Response(
        JSON.stringify({ success: false, error: "Invalid payment signature" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[verify-payment] Signature verified for order=${orderId} payment=${paymentId}`);

    const supabase = createClient(supabaseUrl, supabaseKey);
    const { data: existing } = await supabase
      .from("payments")
      .select("id")
      .eq("razorpay_order_id", orderId)
      .maybeSingle();

    if (existing) {
      await supabase
        .from("payments")
        .update({
          razorpay_payment_id: paymentId,
          status: "captured",
          ...(amountPaise ? { amount_paise: Number(amountPaise) } : {}),
        })
        .eq("id", existing.id);
    } else {
      await supabase.from("payments").insert({
        student_id: userId && userId.includes("-") ? userId : null,
        test_id: testId && testId.includes("-") ? testId : null,
        razorpay_order_id: orderId,
        razorpay_payment_id: paymentId,
        amount_paise: Number(amountPaise) || 100,
        status: "captured",
      });
    }

    console.log(`[verify-payment] DB updated to captured for ${paymentId}`);
    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("[verify-payment] Error:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
