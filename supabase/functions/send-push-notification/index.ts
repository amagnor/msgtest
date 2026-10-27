const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // CORS Preflight Anfrage für Flutter Web / Mobile
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();

    // Erkennt sowohl direkten Aufruf aus Flutter als auch Supabase Database Webhook (INSERT record)
    let title = "🎉 Ziel erreicht!";
    let body = "Ein Ziel wurde erreicht!";
    let topic = "all_users";

    if (payload.record) {
      // Database Webhook Payload
      title = payload.record.title || title;
      body = payload.record.message || body;
    } else {
      // Direkter Aufruf aus Flutter
      title = payload.title || title;
      body = payload.body || payload.message || body;
      topic = payload.topic || topic;
    }

    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    const serverKey = Deno.env.get("FCM_SERVER_KEY");

    let fcmResponse;

    if (serviceAccountJson) {
      // 1. FCM HTTP v1 API mit Firebase Service Account
      const serviceAccount = JSON.parse(serviceAccountJson);
      const accessToken = await getAccessToken(serviceAccount);

      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
      fcmResponse = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            topic: topic,
            notification: {
              title: title,
              body: body,
            },
            data: {
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
        }),
      });
    } else if (serverKey) {
      // 2. Fallback: FCM Legacy Key
      fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Authorization": `key=${serverKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          to: `/topics/${topic}`,
          notification: {
            title: title,
            body: body,
            sound: "default",
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        }),
      });
    } else {
      return new Response(
        JSON.stringify({
          error: "Kein FIREBASE_SERVICE_ACCOUNT oder FCM_SERVER_KEY in Supabase Secrets gesetzt.",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const fcmResult = await fcmResponse.json();

    return new Response(
      JSON.stringify({ success: true, result: fcmResult }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// Hilfsfunktion zur Generierung des Google OAuth2 Access Tokens aus dem Service Account
async function getAccessToken(serviceAccount: { client_email: string; private_key: string }) {
  const jwtHeader = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };
  const jwtClaim = btoa(JSON.stringify(claimSet));
  const unsignedJwt = `${jwtHeader}.${jwtClaim}`;

  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = serviceAccount.private_key
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "");

  const binaryDerString = atob(pemContents);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDerString.length; i++) {
    binaryDer[i] = binaryDerString.charCodeAt(i);
  }

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedJwt)
  );

  const jwtSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const signedJwt = `${unsignedJwt}.${jwtSignature}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}
