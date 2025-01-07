// gen-token.ts
import jwt from 'jsonwebtoken';

const secret = 'SUPER_SECRET_TOKEN';

const payload = {
  member_id: 1, // or whatever user ID you want
  role: 'member'
};

const token = jwt.sign(payload, secret);

// Print it so you can copy/paste
console.log('JWT token:', token);
