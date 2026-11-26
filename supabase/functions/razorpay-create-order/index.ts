import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { amountPaise, userId, testId, testTitle } = await req.json();
    const keyId = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!keyId || !keySecret) {
      throw new Error("Razorpay credentials not configured on server");
    }

    const amount = Number(amountPaise) || 100;
    const receipt = `rcpt_${Date.now()}`;

    // 1. Create Order via Razorpay Orders API
    const auth = btoa(`${keyId}:${keySecret}`);
    const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${auth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount,
        currency: "INR",
        receipt,
        notes: {
          userId: userId ?? "",
          testId: testId ?? "",
          testTitle: testTitle ?? "",
        },
      }),
    });

    const rzpOrder = await rzpRes.json();
    if (!rzpRes.ok) {
      console.error("[create-order] Razorpay error:", rzpOrder);
      throw new Error(rzpOrder.error?.description || "Failed to create Razorpay order");
    }

    console.log(`[create-order] Created order ${rzpOrder.id} for user=${userId} amount=${amount}`);

    // 2. Save order in Supabase immediately with status "created"
    const supabase = createClient(supabaseUrl, supabaseKey);
    const { error: dbError } = await supabase.from("payments").insert({
      student_id: userId && userId.includes("-") ? userId : null,
      test_id: testId && testId.includes("-") ? testId : null,
      razorpay_order_id: rzpOrder.id,
      amount_paise: amount,
      status: "created",
    });

    if (dbError) {
      console.error("[create-order] DB insert error:", dbError);
    } else {
      console.log(`[create-order] Saved order ${rzpOrder.id} to DB`);
    }

    return new Response(
      JSON.stringify({ orderId: rzpOrder.id, amount: rzpOrder.amount, currency: rzpOrder.currency }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("[create-order] Error:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
