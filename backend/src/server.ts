import express from 'express';
import authRoutes from './routes/auth';
import dotenv from 'dotenv';
dotenv.config();

const app = express();
app.use(express.json());

app.use('/auth', authRoutes);

const PORT = process.env.PORT || 8000;

app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`Servidor corriendo en puerto ${PORT}`);
});