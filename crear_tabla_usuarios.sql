-- Crear tabla usuarios si no existe
CREATE TABLE IF NOT EXISTS public.usuarios (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE,
  nombre TEXT,
  apellido TEXT,
  rol TEXT DEFAULT 'educador',
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_activo ON usuarios(activo);

-- Asegurar que la tabla ninos tiene la columna id_usuario
ALTER TABLE public.ninos 
ADD COLUMN IF NOT EXISTS id_usuario UUID;

-- Establecer la restricción de clave foránea para ninos.id_usuario
ALTER TABLE public.ninos 
DROP CONSTRAINT IF EXISTS ninos_id_usuario_fkey;

ALTER TABLE public.ninos 
ADD CONSTRAINT ninos_id_usuario_fkey 
  FOREIGN KEY (id_usuario) 
  REFERENCES public.usuarios(id) 
  ON DELETE CASCADE;

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

-- Limpiar políticas previas si existen
DROP POLICY IF EXISTS "Users can view own profile" ON public.usuarios;
DROP POLICY IF EXISTS "Users can update own profile" ON public.usuarios;
DROP POLICY IF EXISTS "Allow insert on signup" ON public.usuarios;

-- Política: Los usuarios pueden ver su propio perfil
CREATE POLICY "Users can view own profile" 
  ON public.usuarios 
  FOR SELECT 
  USING (auth.uid() = id);

-- Política: Los usuarios pueden actualizar su propio perfil
CREATE POLICY "Users can update own profile" 
  ON public.usuarios 
  FOR UPDATE 
  USING (auth.uid() = id);

-- Política: Permitir inserciones para crear nuevo usuario (necesario en signUp)
CREATE POLICY "Allow insert on signup" 
  ON public.usuarios 
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- Crear función para insertar usuario automáticamente al registrarse
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.usuarios (id, email, nombre, rol, activo)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nombre', NEW.email),
    'educador',
    TRUE
  )
  ON CONFLICT (id) DO UPDATE SET
    email = NEW.email,
    updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Crear trigger para ejecutar la función cuando se registra un nuevo usuario
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
