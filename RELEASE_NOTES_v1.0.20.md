# MarkPro Camera - Release v1.0.20

Este documento detalha as alterações feitas na versão **1.0.20** do MarkPro Camera.

## 📋 Informações Gerais
- **App:** MarkPro Camera
- **Versão:** 1.0.20
- **Build Number:** 21
- **Data:** 11 de Março de 2026
- **Arquitetura:** ARM64 (v8a)
- **Peso do APK:** ~20.0 MB

## 🚀 Novidades e Melhorias

### 1. Marcador no Mini-Mapa (Previa)
- Adicionado o ícone de localização ("gotinha" vermelha) no mini-mapa exibido na tela da câmera.
- Permite ao usuário verificar exatamente onde o ponto de GPS está marcando **antes** de capturar a foto.
- Melhora a precisão e confiança do profissional em campo.

### 2. Otimização de Build
- Mantido o build otimizado para ARM64-v8a.
- Redução drástica de tamanho (de original 55MB para 20MB) para facilitar o download via OTA em redes móveis (3G/4G).

### 3. Sistema OTA (Update)
- Arquivo `version.json` atualizado para sinalizar aos usuários das versões anteriores a disponibilidade da v1.0.20.
- Changelog atualizado para exibição no diálogo de atualização dentro do app.

## 📦 Instruções de Upload
Para que o sistema de atualização funcione corretamente, siga estes passos:
1. Acesse o Repositório no GitHub.
2. Crie uma nova **Release** com a tag `1.0.20`.
3. Faça o upload do arquivo:  
   `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`
4. Renomeie o arquivo no GitHub para `app-arm64-v8a-release.apk` (ou ajuste no `version.json` se necessário).
5. Publique a Release.

---
*MarkPro Camera - Precisão e Confiança no Registro de Trabalho.*
