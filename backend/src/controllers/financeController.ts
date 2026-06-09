import { Response } from 'express';
import { AuthRequest } from '../middlewares/auth';
import { supabase } from '../config/supabase';

export const getInvoices = async (req: AuthRequest, res: Response) => {
  try {
    const { data, error } = await supabase.from('invoices').select('*, cases(title)');
    if (error) throw error;
    res.json(data);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const createTransaction = async (req: AuthRequest, res: Response) => {
  const { type, category, amount, description } = req.body;
  try {
    const { data, error } = await supabase
      .from('transactions')
      .insert([{ type, category, amount, description }])
      .select().single();
    if (error) throw error;
    res.status(201).json(data);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
