import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface PreAuthRequest extends Request {
  userId?: number;
}

export function verifyPreAuth(req: PreAuthRequest, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Falta preAuthToken' });
  }

  const token = authHeader.split(' ')[1];
  
  try {
    const secret = process.env.JWT_SECRET;
    if (!secret) {
      return res.status(500).json({ error: 'Variables no configuradas' });
    }
    const payload = jwt.verify(token!, secret)! as { userId: number; stage: string };
    if (payload.stage !== 'password_ok') {
      return res.status(401).json({ error: 'Token invalido para esta etapa' });
    }

    req.userId = payload.userId;
    next();
  } catch {
    return res.status(401).json({ error: 'preAuthToken expirado o invalido' });
  }
}
