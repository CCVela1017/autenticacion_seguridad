"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = __importDefault(require("./routes/auth"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const app = (0, express_1.default)();
app.use(express_1.default.json());
app.use('/auth', auth_1.default);
const PORT = process.env.PORT || 8000;
app.listen(Number(PORT), '0.0.0.0', () => {
    console.log(`Servidor corriendo en puerto ${PORT}`);
});
//# sourceMappingURL=server.js.map