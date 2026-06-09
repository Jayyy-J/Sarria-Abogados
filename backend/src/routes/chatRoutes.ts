import { Router } from 'express';
import { handleChatStream } from '../controllers/chatController';
import { authenticateToken } from '../middlewares/auth';

const router = Router();
router.post('/stream', authenticateToken, handleChatStream);
export default router;
