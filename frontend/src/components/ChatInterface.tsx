import React, { useState, useRef, useEffect } from 'react'
import { supabase } from '../services/supabase'

interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

interface ChatInterfaceProps {
  assistantSlug: string;
}

export const ChatInterface: React.FC<ChatInterfaceProps> = ({ assistantSlug }) => {
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const [isStreaming, setIsStreaming] = useState(false)
  const scrollRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    scrollRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!input.trim() || isStreaming) return

    const userMessage: Message = { role: 'user', content: input }
    setMessages(prev => [...prev, userMessage])
    setInput('')
    setIsStreaming(true)

    try {
      const { data: { session } } = await supabase.auth.getSession()
      const response = await fetch(`${import.meta.env.VITE_API_URL}/api/chat/stream`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session?.access_token}`
        },
        body: JSON.stringify({
          assistantSlug,
          messages: [...messages, userMessage],
        })
      })

      if (!response.body) return
      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      let assistantContent = ''

      setMessages(prev => [...prev, { role: 'assistant', content: '' }])

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const chunk = decoder.decode(value)
        const lines = chunk.split('\n')

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.replace('data: ', '')
            if (data === '[DONE]') break
            try {
              const parsed = JSON.parse(data)
              if (parsed.text) {
                assistantContent += parsed.text
                setMessages(prev => {
                  const last = prev[prev.length - 1]
                  return [...prev.slice(0, -1), { ...last, content: assistantContent }]
                })
              }
            } catch (e) {}
          }
        }
      }
    } catch (err) {
      console.error(err)
    } finally {
      setIsStreaming(false)
    }
  }

  return (
    <div className="flex flex-col h-[500px] bg-white rounded-lg border shadow-sm">
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((m, i) => (
          <div key={i} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[80%] px-4 py-2 rounded-lg text-sm ${m.role === 'user' ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-800'}`}>
              {m.content}
            </div>
          </div>
        ))}
        <div ref={scrollRef} />
      </div>
      <form onSubmit={handleSubmit} className="p-3 border-t">
        <div className="flex gap-2">
          <input
            type="text"
            className="flex-1 border rounded px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500"
            placeholder="Escribe..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
          <button
            type="submit"
            disabled={isStreaming}
            className="bg-indigo-600 text-white px-4 py-2 rounded text-sm hover:bg-indigo-700 disabled:opacity-50"
          >
            {isStreaming ? '...' : 'Enviar'}
          </button>
        </div>
      </form>
    </div>
  )
}
