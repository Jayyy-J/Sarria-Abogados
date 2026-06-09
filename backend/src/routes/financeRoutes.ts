import { Router } from 'express';
import { getInvoices, createTransaction } from '../controllers/financeController';
import { authenticateToken, authorizeRoles } from '../middlewares/auth';

const router = Router();
router.get('/invoices', authenticateToken, getInvoices);
router.post('/transactions', authenticateToken, authorizeRoles('admin', 'asistente'), createTransaction);
export default router;
