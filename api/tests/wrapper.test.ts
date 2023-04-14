import wrapper from "../api/wrapper";
import { VercelRequest, VercelResponse } from "@vercel/node";
import fs from "fs";


describe("wrapper function", () => {
  it("should transcribe an audio file", async () => {
    const mockRequest = {
      body: {
        base64String: fs.readFileSync("tests/test.wav").toString("base64"),
      },
      headers: {
        'content-type': 'application/json'
      },
      method: 'POST'
    } as unknown as VercelRequest;

    const mockResponse = {
      send: jest.fn(),
      status: jest.fn().mockReturnThis(),
      json: jest.fn((data) => {
        expect(data).toHaveProperty('data');
        expect(typeof data.data).toBe('object');
      }),
    } as unknown as VercelResponse;

    await wrapper(mockRequest, mockResponse);
  }, 20000);
});


