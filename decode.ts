#!/usr/bin/env -S npx tsx

import { createInterface } from "readline";
import { verify, JwtPayload } from "jsonwebtoken";
import process from "process";

const rl = createInterface({
  input: process.stdin,
  crlfDelay: Infinity,
});

let rawInput = "";

// For a real project, set the secret in an ENV variable, a config file, etc.
const JWT_SECRET = process.env.JWT_SECRET || "SUPER_SECRET_TOKEN";

// Collect all lines from stdin
rl.on("line", (line) => {
  rawInput += line;
});

// When stdin completes, parse and verify
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

    // 3) Verify the JWT signature using our secret or public key
    //    - If invalid or expired, verify() throws an error
    const decoded = verify(token, JWT_SECRET) as JwtPayload | string;

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

      console.log("Verified JWT payload:", payload);
    } else {
      // If it's not an object, just show it as-is
      console.log("Verified JWT payload (not object):", decoded);
    }
  } catch (err) {
    console.error("Error verifying JWT:", err);
    process.exit(1);
  }
});
