import Anthropic from '@anthropic-ai/sdk';
import { supabase } from '../config/supabase';

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

export const getAssistantStream = async (slug: string, messages: any[], context: string) => {
  const { data: config } = await supabase.from('assistant_configs').select('*').eq('slug', slug).single();
  if (!config) throw new Error('Config not found');

  return anthropic.messages.stream({
    model: config.model_name,
    max_tokens: 4096,
    system: `${config.system_prompt}\n\nContext:\n${context}`,
    messages: messages,
    temperature: config.temperature,
  });
};
