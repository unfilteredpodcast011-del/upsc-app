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
    const keyId = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const auth = btoa(`${keyId}:${keySecret}`);
    const rzpRes = await fetch("https://api.razorpay.com/v1/payments?count=25", {
      headers: { "Authorization": `Basic ${auth}` },
    });
    const rzpData = await rzpRes.json();
    const items = rzpData.items || [];

    const supabase = createClient(supabaseUrl, supabaseKey);
    let syncedCount = 0;

    for (const p of items) {
      if (p.status !== "captured" && p.status !== "failed") continue;
      const { data: existing } = await supabase
        .from("payments")
        .select("id")
        .eq("razorpay_payment_id", p.id)
        .maybeSingle();

      if (!existing) {
        const notes = p.notes || {};
        await supabase.from("payments").insert({
          student_id: notes.userId && notes.userId.includes("-") ? notes.userId : null,
          test_id: notes.testId && notes.testId.includes("-") ? notes.testId : null,
          razorpay_order_id: p.order_id || `sync_${p.id}`,
          razorpay_payment_id: p.id,
          amount_paise: p.amount,
          status: p.status === "captured" ? "captured" : "failed",
          created_at: new Date(p.created_at * 1000).toISOString(),
        });
        syncedCount++;
      }
    }

    return new Response(
      JSON.stringify({ success: true, syncedCount }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
