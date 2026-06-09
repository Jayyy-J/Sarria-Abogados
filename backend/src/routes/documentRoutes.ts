import { Router } from 'express';
import { getAllDocuments, uploadDocument } from '../controllers/documentController';
import { authenticateToken } from '../middlewares/auth';

const router = Router();
router.get('/', authenticateToken, getAllDocuments);
router.post('/', authenticateToken, uploadDocument);
export default router;
