-- 1. EXTENSIONS & TYPES
CREATE EXTENSION IF NOT EXISTS "vector";

CREATE TYPE public.user_role AS ENUM ('admin', 'abogado', 'asistente', 'cliente');
CREATE TYPE public.case_status AS ENUM ('abierto', 'en_proceso', 'cerrado', 'archivado');
CREATE TYPE public.message_role AS ENUM ('system', 'user', 'assistant');

-- 2. TABLES
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
    embedding vector(1536),
    case_id UUID REFERENCES public.cases(id),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    indexed_at TIMESTAMPTZ
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

CREATE TABLE public.chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) NOT NULL,
    assistant_slug TEXT REFERENCES public.assistant_configs(slug) NOT NULL,
    title TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES public.chat_sessions(id) ON DELETE CASCADE NOT NULL,
    role public.message_role NOT NULL,
    content TEXT NOT NULL,
    tokens_used INTEGER,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assistant_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- 3. HELPER FUNCTIONS FOR RLS (Avoid Recursion)
CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS public.user_role AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 4. RLS POLICIES

-- Profiles
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admins can manage all profiles" ON public.profiles FOR ALL USING (public.get_auth_role() = 'admin');

-- Clients
CREATE POLICY "Staff can view all clients" ON public.clients FOR SELECT
    USING (public.get_auth_role() IN ('admin', 'abogado', 'asistente'));
CREATE POLICY "Admins and Abogados can manage clients" ON public.clients FOR ALL
    USING (public.get_auth_role() IN ('admin', 'abogado'));

-- Cases
CREATE POLICY "Staff can view all cases" ON public.cases FOR SELECT
    USING (public.get_auth_role() IN ('admin', 'abogado', 'asistente'));
CREATE POLICY "Lawyers can update their cases" ON public.cases FOR UPDATE
    USING (auth.uid() = lawyer_id OR public.get_auth_role() = 'admin');
CREATE POLICY "Admins can manage cases" ON public.cases FOR ALL
    USING (public.get_auth_role() = 'admin');

-- Assistant Configs
CREATE POLICY "All authenticated users can read active configs" ON public.assistant_configs FOR SELECT
    USING (is_active = true);
CREATE POLICY "Admins can manage configs" ON public.assistant_configs FOR ALL
    USING (public.get_auth_role() = 'admin');

-- Documents
CREATE POLICY "Staff can view documents" ON public.documents FOR SELECT
    USING (public.get_auth_role() IN ('admin', 'abogado', 'asistente'));
CREATE POLICY "Staff can upload documents" ON public.documents FOR INSERT
    WITH CHECK (public.get_auth_role() IN ('admin', 'abogado', 'asistente'));

-- Chat Sessions
CREATE POLICY "Users can manage their own chat sessions" ON public.chat_sessions FOR ALL
    USING (auth.uid() = user_id);

-- Chat Messages
CREATE POLICY "Users can manage messages of their sessions" ON public.chat_messages FOR ALL
    USING (EXISTS (SELECT 1 FROM public.chat_sessions WHERE id = session_id AND user_id = auth.uid()));

-- Audit Logs
CREATE POLICY "Only admins can view audit logs" ON public.audit_logs FOR SELECT
    USING (public.get_auth_role() = 'admin');

-- 5. PROFILE SYNC TRIGGER (Auth -> Profiles)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        NEW.email,
        COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'cliente'::public.user_role)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. AUDIT TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.fn_audit_log_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.audit_logs (
        table_name,
        record_id,
        action,
        old_data,
        new_data,
        performed_by
    ) VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        TG_OP,
        CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(OLD) END, -- simplified
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
        auth.uid()
    );
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_audit_clients AFTER INSERT OR UPDATE OR DELETE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_change();
CREATE TRIGGER tr_audit_cases AFTER INSERT OR UPDATE OR DELETE ON public.cases FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_change();

-- 7. INDEXES
CREATE INDEX idx_clients_id_number ON public.clients(identification_number);
CREATE INDEX idx_cases_client_id ON public.cases(client_id);
CREATE INDEX idx_cases_lawyer_id ON public.cases(lawyer_id);
CREATE INDEX idx_chat_messages_session_id ON public.chat_messages(session_id);
CREATE INDEX idx_documents_embedding ON public.documents USING hnsw (embedding vector_cosine_ops);
