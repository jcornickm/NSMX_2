## 5. Credenciales y tokens de acceso

| Servicio | Almacenamiento | Variable |
|---|---|---|
| US Census API | `.Renviron` | Por confirmar el nombre exacto de la variable |
| GitHub PAT | `gitcreds` (gestor de credenciales del sistema Windows) | — |

**Recuperar el token de GitHub en cualquier momento:**
```r
gitcreds::gitcreds_get()
```

**Verificar el token del Census:**
```r
Sys.getenv("CENSUS_KEY")   # ajustar al nombre real de la variable
```

> 🔒 **Regla:** ningún token se escribe directamente en código. Siempre se accede vía `Sys.getenv()` o `gitcreds`.

---

## 7. Herramientas de IA y referencias

| Herramienta | Uso |
|---|---|
| Claude Pro | Asistencia principal de código y redacción |
| Gemini Pro | Consultas adicionales |
| Microsoft Copilot | Consultas adicionales |
| Elicit (versión gratuita) | Búsqueda y síntesis de literatura académica |
| Zotero (desktop + web) | Gestión de referencias bibliográficas |

---

*Documento generado: abril 2026. Actualizar al inicio de cada proyecto o cuando cambien versiones, credenciales o funciones.*