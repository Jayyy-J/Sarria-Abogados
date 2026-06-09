-- 1. EXTENSIONS & TYPES
CREATE EXTENSION IF NOT EXISTS "vector";

CREATE TYPE public.user_role AS ENUM ('admin', 'abogado', 'asistente', 'cliente');
CREATE TYPE public.case_status AS ENUM ('abierto', 'en_proceso', 'cerrado', 'archivado');
CREATE TYPE public.message_role AS ENUM ('system', 'user', 'assistant');

-- 2. CORE TABLES
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    role public.user_role NOT NULL DEFAULT 'cliente',
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    identification_number TEXT UNIQUE NOT NULL,
    identification_type TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    address TEXT,
    habeas_data_authorized BOOLEAN NOT NULL DEFAULT FALSE,
    habeas_data_timestamp TIMESTAMPTZ,
    habeas_data_policy_version TEXT DEFAULT 'v1.0',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

CREATE TABLE public.cases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    status public.case_status NOT NULL DEFAULT 'abierto',
    client_id UUID REFERENCES public.clients(id) NOT NULL,
    lawyer_id UUID REFERENCES public.profiles(id) NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.assistant_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    system_prompt TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT 'anthropic',
    model_name TEXT NOT NULL,
    temperature FLOAT NOT NULL DEFAULT 0.7,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT,
    file_path TEXT,
    case_id UUID REFERENCES public.cases(id),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    indexed_at TIMESTAMPTZ
);

CREATE TABLE public.document_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    embedding vector(1536),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    action TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    performed_by UUID REFERENCES public.profiles(id),
    client_ip TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. FINANCIAL TABLES
CREATE TABLE public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID REFERENCES public.cases(id) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pendiente',
    due_date DATE NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. RLS & HELPERS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assistant_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS public.user_role AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admins can manage all profiles" ON public.profiles FOR ALL USING (public.get_auth_role() = 'admin');

CREATE POLICY "Staff can view all clients" ON public.clients FOR SELECT USING (public.get_auth_role() IN ('admin', 'abogado', 'asistente'));
CREATE POLICY "Admins and Abogados can manage clients" ON public.clients FOR ALL USING (public.get_auth_role() IN ('admin', 'abogado'));

CREATE POLICY "Staff can view all cases" ON public.cases FOR SELECT USING (public.get_auth_role() IN ('admin', 'abogado', 'asistente'));

-- 5. MATCH FUNCTION FOR RAG
CREATE OR REPLACE FUNCTION match_document_chunks (
  query_embedding vector(1536),
  match_threshold float,
  match_count int,
  filter_case_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  document_id uuid,
  content text,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.document_id,
    c.content,
    1 - (c.embedding <=> query_embedding) AS similarity
  FROM document_chunks c
  JOIN documents d ON c.document_id = d.id
  WHERE (filter_case_id IS NULL OR d.case_id = filter_case_id)
    AND 1 - (c.embedding <=> query_embedding) > match_threshold
  ORDER BY c.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
