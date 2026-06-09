import { OpenAI } from 'openai';
import { supabase } from '../config/supabase';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export const searchContext = async (query: string, caseId?: string) => {
  try {
    const resp = await openai.embeddings.create({ model: 'text-embedding-3-small', input: query });
    const embedding = resp.data[0].embedding;

    const { data, error } = await supabase.rpc('match_document_chunks', {
      query_embedding: embedding,
      match_threshold: 0.5,
      match_count: 5,
      filter_case_id: caseId
    });

    if (error) throw error;
    return data.map((d: any) => d.content).join('\n\n');
  } catch (e) {
    return '';
  }
};
