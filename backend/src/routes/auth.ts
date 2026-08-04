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

  const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&._-]).{8,}$/;
  
  if (!passwordRegex.test(password)) {
    return res.status(400).json({ 
      error: 'La contraseña debe tener al menos 8 caracteres, incluir una mayúscula, una minúscula, un número y un carácter especial (@$!%*?&._-)' 
    });
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
});


router.post('/identify', (req: Request, res: Response) => {
  const { identifier } = req.body;
  
  if (!identifier) {
    return res.status(400).json({ error: 'Falta el identificador' });
  }

  const user = db.prepare('SELECT username FROM users WHERE username = ?').get(identifier) as { username: string } | undefined;

  if (user) {
    return res.json({ exists: true, name: user.username });
  } else {
    return res.status(404).json({ exists: false, error: 'Usuario inexistente' });
  }
});

router.post('/authenticate', async (req: Request, res: Response) => {
  const { identifier, password, otpCode, biometricVerified } = req.body;
  
  console.log('>>> INTENTO DE AUTENTICACIÓN FINAL PARA:', identifier);
  console.log('>>> OTP RECIBIDO:', otpCode);
  console.log('>>> BIOMETRÍA:', biometricVerified);

  const user = db.prepare('SELECT * FROM users WHERE username = ?').get(identifier) as User | undefined;
  if (!user) {
    console.log('>>> ERROR: Usuario no encontrado');
    return res.status(401).json({ success: false, error: 'Usuario no encontrado' });
  }


  const match = await bcrypt.compare(password, user.password_hash);
  if (!match) {
    console.log('>>> ERROR: Contraseña incorrecta');
    return res.status(401).json({ success: false, error: 'Contraseña incorrecta' });
  }


  const valid = verify({ token: otpCode, secret: user.totp_secret! });
  console.log('>>> ¿ES VÁLIDO EL TOTP?:', valid);
  if (!valid) {
    console.log('>>> ERROR: Código TOTP inválido');
    return res.status(401).json({ success: false, error: 'Código TOTP inválido' });
  }

  const token = jwt.sign(
    { userId: user.id, stage: 'full_auth' },
    process.env.JWT_SECRET as string,
    { expiresIn: '2h' }
  );

  res.json({ success: true, role: user.role, token });
});

export default router;