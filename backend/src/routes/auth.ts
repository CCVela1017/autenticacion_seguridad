import { Router, Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import db from '../db';
import { generate, generateSecret, generateSync, generateURI, verify, verifySync } from 'otplib'
import qrcode from 'qrcode';
import { verifyPreAuth, PreAuthRequest } from '../middleware/preAuth';

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

  if (!user) return res.status(401).json({ error: 'Credenciales invalidas' });

  const match = await bcrypt.compare(password, user.password_hash);
  if (!match) return res.status(401).json({ error: 'Credenciales invalidas' });

  const preAuthToken = jwt.sign(
    { userId: user.id, stage: 'password_ok' },
    process.env.JWT_SECRET as string,
    { expiresIn: '5m' }
  );

  res.json({ preAuthToken, needsTotpSetup: !user.totp_confirmed });
});

// configuracion de TOTP por primera vez
router.post('/totp/setup', verifyPreAuth, async (req: PreAuthRequest, res: Response) => {
  const userId = req.userId!;
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as User;

  const secret = generateSecret();
  db.prepare('UPDATE users SET totp_secret = ? WHERE id = ?').run(secret, userId);

  const otpauthUrl = generateURI({ issuer: 'AppAutenticacion', label: user.username, secret });
  const qrCodeDataUrl = await qrcode.toDataURL(otpauthUrl);

  res.json({ qrCodeDataUrl, secret });
});

// confirmacion de TOTP por primera vez
router.post('/totp/confirm', verifyPreAuth, async (req: PreAuthRequest, res: Response) => {
  const { code } = req.body;
  const userId = req.userId!;
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as User;

  const result = await verify({ token: code, secret: user.totp_secret! });
  if (!result.valid) return res.status(401).json({ error: 'Codigo invalido' });

  db.prepare('UPDATE users SET totp_confirmed = 1 WHERE id = ?').run(userId);

  const finalToken = jwt.sign(
    { userId, stage: 'full_auth' },
    process.env.JWT_SECRET as string,
    { expiresIn: '2h' }
  );
  res.json({ token: finalToken });
});

// validacion TOTP login normal
router.post('/totp/verify', verifyPreAuth, async (req: PreAuthRequest, res: Response) => {
  const { code } = req.body;
  const userId = req.userId!;
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as User;

  if (!user.totp_secret) {
    return res.status(400).json({ error: 'TOTP no configurado' });
  }

  const result = await verify({ token: code, secret: user.totp_secret });
  if (!result.valid) return res.status(401).json({ error: 'Codigo invalido' });

  const finalToken = jwt.sign(
    { userId, stage: 'full_auth' },
    process.env.JWT_SECRET as string,
    { expiresIn: '2h' }
  );
  res.json({ token: finalToken });
});

router.get('/get-role', verifyPreAuth, (req: PreAuthRequest, res: Response) => {
  const userId = req.userId!;
  const user = db.prepare('SELECT role FROM users WHERE id = ?').get(userId) as { role: string | null } | undefined;

  if (!user) return res.status(404).json({ error: 'Usuario no encontrado' });

  res.json({ role: user.role });
});1

export default router;