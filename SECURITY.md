Seguridad: Supabase keys

No incluyas claves secretas (anonKey) ni URLs de bases de datos en el repositorio público.

Recomendación de uso local y CI

- Proporciona las variables en tiempo de compilación usando `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL="https://<tu-proyecto>.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="<tu-anon-key>"
```

- Para producción/CI, configura las variables de entorno/secretos en la plataforma (GitHub Actions, GitLab CI, Codemagic, etc.) y pasa `--dart-define` durante la build.

Rotación y limpieza

- Si ya subiste claves, revócalas en Supabase inmediatamente y genera nuevas.
- Para eliminar claves del historial de git usa herramientas como `git filter-repo` o `bfg repo-cleaner` (haz un backup antes).

Buenas prácticas

- Nunca pongas la `service_role` key en el cliente.
- Usa reglas RLS y políticas en Supabase para controlar el acceso.
- Guarda secretos en el gestor de secretos de la plataforma.
