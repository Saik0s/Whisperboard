// functions/transcriptionHandler.ts
import banana from "banana"
import { createClient } from "supabase";
import { ServerRequest } from "server";
import { MultipartReader } from "multipart";
import { Token, ApnsClient, Notification } from "apns"

const apnsKeyId = Deno.env.get("APNS_KEY_ID")!;
const apnsTeamId = Deno.env.get("APNS_TEAM_ID")!;
const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY")!;
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const bananaApiKey = Deno.env.get("BANANA_API_KEY")!;
const bananaModelKey = Deno.env.get("BANANA_MODEL_KEY")!;

const supabase = createClient(supabaseUrl, supabaseKey);

const MB = 1024 * 1024;

const generateUserId = (req: ServerRequest) => {
  const deviceId = req.headers.get("x-device-identifier");
  if (!deviceId) {
    throw new Error("Missing device identifier header.");
  }
  return deviceId;
};

const checkUserUsage = async (userId: string) => {
  const { count } = await supabase
    .from("transcriptions")
    .select("id", { count: "exact" })
    .eq("user_id", userId);

  const usageLimit = 10;
  return count >= usageLimit;
};

const trackUserUsage = async (userId: string, transcriptionId: string) => {
  const { error } = await supabase.from("usage_logs").insert([
    {
      user_id: userId,
      timestamp: new Date(),
      transcription_id: transcriptionId,
    },
  ]);

  if (error) {
    console.error("Failed to log user usage:", error);
  }
};

// Initialize the APNs client
const apnsClient = new APNS({
  token: new ApnsClient({
    keyId: apnsKeyId,
    team: apnsTeamId,
    signingKey: apnsPrivateKey,
  }),
  useSandbox: true, // Set to false for production
});

// Add this function to send push notifications
const sendPushNotification = async (deviceToken: string, message: string) => {
  const notification = new Notification(deviceToken, {
    aps: {
      alert: {
        title: "Transcription Completed",
        body: message,
      },
      sound: "default",
    },
  });

  try {
    const response = await apnsClient.send(notification);
    console.log("Push notification sent:", response);
  } catch (error) {
    console.error("Failed to send push notification:", error);
  }
};

export default async (req: ServerRequest) => {
  try {
    const userId = generateUserId(req);

    if (await checkUserUsage(userId)) {
      req.respond({ status: 429, body: "Usage limit reached." });
      return;
    }

    if (req.method === "POST") {
      const contentType = req.headers.get("content-type") || "";
      const match = contentType.match(/boundary=([^ ]+)/);
      if (!match) {
        req.respond({
          status: 400,
          body: "Missing content-type header with boundary.",
        });
        return;
      }

      const boundary = match[1];
      const reader = new MultipartReader(req.body, boundary, 10 * MB);
      const formData = await reader.readForm();

      const file = formData.file("audio");
      if (!file) {
        req.respond({ status: 400, body: "Missing file." });
        return;
      }

      const timestamp = +new Date();
      const uploadName = `${file.filename}-${timestamp}`;

      const { data: upload, error: uploadError } = await supabase.storage
        .from(`audio-files/${userId}`)
        .upload(uploadName, file.content, {
          contentType: file.contentType,
          cacheControl: "259200", // 3 days
          upsert: false,
        });

      if (uploadError) {
        console.error(uploadError);
        req.respond({ status: 500, body: "Failed to upload the file." });
        return;
      }

      // Call the transcription service
      const modelInputs = {
        prompt: "An interview about science",
        num_speakers: 2,
        filename: uploadName,
        file_url: upload.publicURL,
      };

      const transcriptionData = await banana.run(
        bananaApiKey,
        bananaModelKey,
        modelInputs
      );

      // Save the transcription data to your database
      const { data, error } = await supabase.from("transcriptions").insert([
        {
          user_id: userId,
          file_name: uploadName,
          transcription_data: transcriptionData,
        },
      ]);

      if (error) {
        console.error(error);
        req.respond({
          status: 500,
          body: "Failed to save transcription data.",
        });
        return;
      }

      const transcriptionId = data[0].id;
      await trackUserUsage(userId, transcriptionId);

      // Send a push notification
      const deviceToken = "USER_DEVICE_TOKEN"; // Replace with the actual device token from the iOS app
      const message = "Your transcription is ready!";
      await sendPushNotification(deviceToken, message);

      req.respond({
        status: 201,
        body: JSON.stringify({ status: "success", id: data[0].id }),
      });
    } else if (req.url.startsWith("/transcription/") && req.method === "GET") {
      const id = req.url.split("/").pop();

      const { data, error } = await supabase
        .from("transcriptions")
        .select("transcription_data")
        .eq("id", id)
        .eq("user_id", userId)
        .single();

      if (error) {
        console.error(error);
        req.respond({
          status: 500,
          body: "Failed to fetch transcription data.",
        });
        return;
      }

      req.respond({
        status: 200,
        body: JSON.stringify({
          status: "success",
          transcription: data.transcription_data,
        }),
      });
    } else {
      req.respond({ status: 404, body: "Not Found" });
    }
  } catch (error) {
    console.error(error);
    req.respond({ status: 400, body: error.message });
    return;
  }
};
