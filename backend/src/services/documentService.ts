import { supabase } from '../config/supabase';
import { OpenAI } from 'openai';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export const processDocument = async (documentId: string, content: string) => {
  try {
    const chunkSize = 1000;
    const chunkOverlap = 100;
    const chunks: string[] = [];

    for (let i = 0; i < content.length; i += chunkSize - chunkOverlap) {
      chunks.push(content.slice(i, i + chunkSize));
    }

    for (const chunk of chunks) {
      const response = await openai.embeddings.create({
        model: "text-embedding-3-small",
        input: chunk,
      });
      const embedding = response.data[0].embedding;

      await supabase.from('document_chunks').insert({
        document_id: documentId,
        content: chunk,
        embedding: embedding
      });
    }

    await supabase.from('documents').update({ indexed_at: new Date().toISOString() }).eq('id', documentId);
  } catch (error) {
    console.error('Process Document Error:', error);
  }
};
