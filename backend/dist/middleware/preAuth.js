"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyPreAuth = verifyPreAuth;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
function verifyPreAuth(req, res, next) {
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
        const payload = jsonwebtoken_1.default.verify(token, secret);
        if (payload.stage !== 'password_ok') {
            return res.status(401).json({ error: 'Token invalido para esta etapa' });
        }
        req.userId = payload.userId;
        next();
    }
    catch {
        return res.status(401).json({ error: 'preAuthToken expirado o invalido' });
    }
}
//# sourceMappingURL=preAuth.js.map