import { Router } from 'express';
import { getAllClients, createClient } from '../controllers/clientController';
import { authenticateToken, authorizeRoles } from '../middlewares/auth';

const router = Router();
router.get('/', authenticateToken, getAllClients);
router.post('/', authenticateToken, authorizeRoles('admin', 'abogado'), createClient);
export default router;
