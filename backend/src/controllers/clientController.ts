import { Response } from 'express';
import { AuthRequest } from '../middlewares/auth';
import { supabase } from '../config/supabase';

export const getAllClients = async (req: AuthRequest, res: Response) => {
  const { data, error } = await supabase.from('clients').select('*');
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
};

export const createClient = async (req: AuthRequest, res: Response) => {
  const { full_name, identification_number, identification_type, email, habeas_data_authorized } = req.body;
  const { data, error } = await supabase.from('clients').insert({
    full_name,
    identification_number,
    identification_type,
    email,
    habeas_data_authorized,
    habeas_data_timestamp: habeas_data_authorized ? new Date().toISOString() : null,
    created_by: req.user.id
  }).select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json(data);
};
