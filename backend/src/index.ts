import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import chatRoutes from './routes/chatRoutes';
import clientRoutes from './routes/clientRoutes';
import documentRoutes from './routes/documentRoutes';
import financeRoutes from './routes/financeRoutes';

dotenv.config();

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

app.use('/api/chat', chatRoutes);
app.use('/api/clients', clientRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api/finance', financeRoutes);

app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
