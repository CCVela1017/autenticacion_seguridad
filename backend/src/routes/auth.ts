import { Router, Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import db from '../db';

const router = Router();

interface User {
  id: number;
  username: string;
  password_hash: string;
  totp_secret: string | null;
  totp_confirmed: number;
  role: string | null;
}

interface RegisterBody {
  username: string;
  password: string;
  role: string | null;
}

router.post('/register', async (req: Request<{}, {}, RegisterBody>, res: Response) => {
  const { username, password, role } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'Faltan campos' });
  }

  const exists = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
  if (exists) return res.status(409).json({ error: 'Usuario ya existe' });

  const hash = await bcrypt.hash(password, 12);
  db.prepare('INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)').run(username, hash, role);

  res.status(201).json({ message: 'Usuario creado' });
});

router.post('/login-password', async (req: Request<{}, {}, RegisterBody>, res: Response) => {
  const { username, password } = req.body;
  const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username) as User | undefined;

  if (!user) return res.status(401).json({ error: 'Credenciales inválidas' });

  const match = await bcrypt.compare(password, user.password_hash);
  if (!match) return res.status(401).json({ error: 'Credenciales inválidas' });

  const preAuthToken = jwt.sign(
    { userId: user.id, stage: 'password_ok' },
    process.env.JWT_SECRET as string,
    { expiresIn: '5m' }
  );

  res.json({ preAuthToken, needsTotpSetup: !user.totp_confirmed });
});

export default router;