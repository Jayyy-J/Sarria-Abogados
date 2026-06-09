import { Response } from 'express';
import { AuthRequest } from '../middlewares/auth';
import { getAssistantStream } from '../services/aiService';
import { searchContext } from '../services/ragService';
import { supabase } from '../config/supabase';

export const handleChatStream = async (req: AuthRequest, res: Response) => {
  const { assistantSlug, messages, sessionId, caseId } = req.body;

  try {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');

    const lastMessage = messages[messages.length - 1].content;
    const context = await searchContext(lastMessage, caseId);

    const stream = await getAssistantStream(assistantSlug, messages, context);

    let fullResponse = '';
    stream.on('text', (text) => {
      fullResponse += text;
      res.write(`data: ${JSON.stringify({ text })}\n\n`);
    });

    stream.on('end', async () => {
      if (sessionId) {
        await supabase.from('chat_messages').insert({
          session_id: sessionId,
          role: 'assistant',
          content: fullResponse
        });
      }
      res.write('data: [DONE]\n\n');
      res.end();
    });
  } catch (error) {
    res.write(`data: ${JSON.stringify({ error: 'Processing error' })}\n\n`);
    res.end();
  }
};
