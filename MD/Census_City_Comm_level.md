---
output:
  word_document: default
  html_document: default
---
### US Census Bureau — combinaciones CTY_CODE × COMM_LVL (endpoint /hs)

Confirmado en pruebas de abril 2026:

| CTY_CODE  | COMM_LVL | Resultado                                              |
|-----------|----------|--------------------------------------------------------|
| Omitido   | omitido  | Timeout (payload demasiado grande)                     |
| Omitido   | "HS2"    | ✅ Funciona                                            |
| Omitido   | "HS4"    | ❌ Error del servidor (500)                            |
| "2010"    | omitido  | ✅ Funciona — devuelve HS2+HS4+HS6+10 dígitos mezclados|
| "2010"    | "HS2"    | ✅ Funciona (usado en Query 2)                         |
| "2010"    | "HS4"    | ❌ Error del servidor (500)                            |

**Workaround para HS4/HS6:** omitir COMM_LVL, descargar con CTY_CODE únicamente,
y filtrar por nchar(I_COMMODITY) == 4 o == 6 en la limpieza.
Implementado en Query3_Partidas_Cap_Principales.R.