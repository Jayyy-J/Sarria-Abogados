import { Response } from 'express';
import { AuthRequest } from '../middlewares/auth';
import { supabase } from '../config/supabase';
import { processDocument } from '../services/documentService';

export const getAllDocuments = async (req: AuthRequest, res: Response) => {
  const { data, error } = await supabase.from('documents').select('*');
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
};

export const uploadDocument = async (req: AuthRequest, res: Response) => {
  const { title, content, case_id } = req.body;
  try {
    const { data, error } = await supabase
      .from('documents')
      .insert([{ title, content, case_id }])
      .select().single();

    if (error) throw error;

    // Background process
    processDocument(data.id, content);
    res.status(201).json(data);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
