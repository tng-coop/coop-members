#!/usr/bin/env -S npx tsx


import { createInterface } from "readline";
import { decode } from "jsonwebtoken";
import process from "process";

const rl = createInterface({
  input: process.stdin,
  crlfDelay: Infinity,
});

let rawInput = "";

// Collect all lines from stdin
rl.on("line", (line) => {
  rawInput += line;
});

// When stdin completes, parse and decode
rl.on("close", () => {
  try {
    // 1) Parse the incoming JSON
    const parsed = JSON.parse(rawInput);

    // 2) Extract jwtToken
    const token = parsed?.data?.loginMember?.jwtToken;
    if (!token) {
      console.error("No JWT token found in the input JSON.");
      process.exit(1);
    }

    // 3) Decode the JWT (no signature verification in this example)
    const decoded = decode(token);

    if (!decoded) {
      console.error("Failed to decode JWT token.");
      process.exit(1);
    }

    // 4) If decoded is an object, convert iat/exp to readable strings
    if (typeof decoded === "object" && decoded !== null) {
      // We'll make a shallow copy so we can add human-readable fields
      const payload = { ...decoded };

      // Convert iat to ISO date, if present
      if (typeof payload.iat === "number") {
        const dateObj = new Date(payload.iat * 1000);
        payload["iat_readable"] = dateObj.toISOString();
      }

      // Convert exp to ISO date, if present
      if (typeof payload.exp === "number") {
        const dateObj = new Date(payload.exp * 1000);
        payload["exp_readable"] = dateObj.toISOString();
      }

      console.log("Decoded JWT payload:", payload);
    } else {
      // If it's not an object, just show it as-is
      console.log("Decoded JWT payload (not object):", decoded);
    }
  } catch (err) {
    console.error("Error parsing input or decoding JWT:", err);
    process.exit(1);
  }
});
