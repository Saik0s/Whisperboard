import { run } from "@banana-dev/banana-dev";
import type { VercelRequest, VercelResponse } from "@vercel/node";

import { config } from "dotenv";
config({ path: '.envrc' });

const apiKey: string = process.env.BANANA_API_KEY!;
const modelKey: string = process.env.BANANA_MODEL_KEY!;

export default async function (req: VercelRequest, res: VercelResponse) {
  if (req.method === "POST") {
    try {
      const json = req.body as { base64String: string };
      const base64String = json.base64String;
      const modelParameters = { base64String: base64String };
      const out = await run(apiKey, modelKey, modelParameters);
      res.status(200).json({ data: out });
    } catch (error) {
      console.error(error);
      res.status(500).json({
        error: "Failed to transcribe audio file.",
        underlyingError: error,
      });
    }
  } else {
    res.setHeader("Allow", "POST");
    res.status(405).end("Method Not Allowed");
  }
}

