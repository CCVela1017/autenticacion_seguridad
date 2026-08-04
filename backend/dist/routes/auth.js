"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const bcrypt_1 = __importDefault(require("bcrypt"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const db_1 = __importDefault(require("../db"));
const otplib_1 = require("otplib");
const qrcode_1 = __importDefault(require("qrcode"));
const preAuth_1 = require("../middleware/preAuth");
const router = (0, express_1.Router)();
router.post('/register', async (req, res) => {
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
    const exists = db_1.default.prepare('SELECT id FROM users WHERE username = ?').get(username);
    if (exists)
        return res.status(409).json({ error: 'Usuario ya existe' });
    const hash = await bcrypt_1.default.hash(password, 12);
    db_1.default.prepare('INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)').run(username, hash, role);
    res.status(201).json({ message: 'Usuario creado' });
});
router.post('/login-password', async (req, res) => {
    const { username, password } = req.body;
    const user = db_1.default.prepare('SELECT * FROM users WHERE username = ?').get(username);
    if (!user)
        return res.status(401).json({ error: 'Credenciales invalidas' });
    const match = await bcrypt_1.default.compare(password, user.password_hash);
    if (!match)
        return res.status(401).json({ error: 'Credenciales invalidas' });
    const preAuthToken = jsonwebtoken_1.default.sign({ userId: user.id, stage: 'password_ok' }, process.env.JWT_SECRET, { expiresIn: '5m' });
    res.json({ preAuthToken, needsTotpSetup: !user.totp_confirmed });
});
router.post('/totp/setup', preAuth_1.verifyPreAuth, async (req, res) => {
    const userId = req.userId;
    const user = db_1.default.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    const secret = (0, otplib_1.generateSecret)();
    db_1.default.prepare('UPDATE users SET totp_secret = ? WHERE id = ?').run(secret, userId);
    const otpauthUrl = (0, otplib_1.generateURI)({ issuer: 'AppAutenticacion', label: user.username, secret });
    const qrCodeDataUrl = await qrcode_1.default.toDataURL(otpauthUrl);
    res.json({ qrCodeDataUrl, secret });
});
router.post('/totp/confirm', preAuth_1.verifyPreAuth, (req, res) => {
    const { code } = req.body;
    const userId = req.userId;
    const user = db_1.default.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    const valid = (0, otplib_1.verify)({ token: code, secret: user.totp_secret });
    if (!valid)
        return res.status(401).json({ error: 'Codigo invalido' });
    db_1.default.prepare('UPDATE users SET totp_confirmed = 1 WHERE id = ?').run(userId);
    const finalToken = jsonwebtoken_1.default.sign({ userId, stage: 'full_auth' }, process.env.JWT_SECRET, { expiresIn: '2h' });
    res.json({ token: finalToken });
});
router.post('/totp/verify', preAuth_1.verifyPreAuth, (req, res) => {
    const { code } = req.body;
    const userId = req.userId;
    const user = db_1.default.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user.totp_secret) {
        return res.status(400).json({ error: 'TOTP no configurado' });
    }
    const valid = (0, otplib_1.verify)({ token: code, secret: user.totp_secret });
    if (!valid)
        return res.status(401).json({ error: 'Codigo invalido' });
    const finalToken = jsonwebtoken_1.default.sign({ userId, stage: 'full_auth' }, process.env.JWT_SECRET, { expiresIn: '2h' });
    res.json({ token: finalToken });
});
router.get('/get-role', preAuth_1.verifyPreAuth, (req, res) => {
    const userId = req.userId;
    const user = db_1.default.prepare('SELECT role FROM users WHERE id = ?').get(userId);
    if (!user)
        return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json({ role: user.role });
});
router.post('/identify', (req, res) => {
    const { identifier } = req.body;
    if (!identifier) {
        return res.status(400).json({ error: 'Falta el identificador' });
    }
    const user = db_1.default.prepare('SELECT username FROM users WHERE username = ?').get(identifier);
    if (user) {
        return res.json({ exists: true, name: user.username });
    }
    else {
        return res.status(404).json({ exists: false, error: 'Usuario inexistente' });
    }
});
router.post('/authenticate', async (req, res) => {
    const { identifier, password, otpCode, biometricVerified } = req.body;
    console.log('>>> INTENTO DE AUTENTICACIÓN FINAL PARA:', identifier);
    console.log('>>> OTP RECIBIDO:', otpCode);
    console.log('>>> BIOMETRÍA:', biometricVerified);
    const user = db_1.default.prepare('SELECT * FROM users WHERE username = ?').get(identifier);
    if (!user) {
        console.log('>>> ERROR: Usuario no encontrado');
        return res.status(401).json({ success: false, error: 'Usuario no encontrado' });
    }
    const match = await bcrypt_1.default.compare(password, user.password_hash);
    if (!match) {
        console.log('>>> ERROR: Contraseña incorrecta');
        return res.status(401).json({ success: false, error: 'Contraseña incorrecta' });
    }
    const valid = (0, otplib_1.verify)({ token: otpCode, secret: user.totp_secret });
    console.log('>>> ¿ES VÁLIDO EL TOTP?:', valid);
    if (!valid) {
        console.log('>>> ERROR: Código TOTP inválido');
        return res.status(401).json({ success: false, error: 'Código TOTP inválido' });
    }
    const token = jsonwebtoken_1.default.sign({ userId: user.id, stage: 'full_auth' }, process.env.JWT_SECRET, { expiresIn: '2h' });
    res.json({ success: true, role: user.role, token });
});
exports.default = router;
//# sourceMappingURL=auth.js.map