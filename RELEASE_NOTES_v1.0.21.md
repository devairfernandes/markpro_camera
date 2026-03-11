# MarkPro Camera - Release v1.0.21

Este documento detalha as alterações feitas na versão **1.0.21** do MarkPro Camera.

## 📋 Informações Gerais
- **App:** MarkPro Camera
- **Versão:** 1.0.21
- **Build Number:** 22
- **Data:** 11 de Março de 2026
- **Arquitetura:** ARM64 (v8a)
- **Peso do APK:** ~20.0 MB

---

## 🚀 Novidades e Correções

### 1. ✅ Importar Configuração — Agora com Seletor de Arquivo
- Antes: o usuário precisava **colar manualmente** o JSON no campo de texto.
- Agora: ao tocar em **"Importar Config"**, o explorador de arquivos do celular abre automaticamente filtrado por arquivos `.json`.
- Basta selecionar o arquivo `markpro_config.json` gerado pela exportação.
- O nome do projeto (`customTitle`) também é importado junto com as configurações.

### 2. ✅ Versão Corrigida no Painel de Configurações
- O badge de versão no painel de configurações agora exibe corretamente `v1.0.21`.
- Nas versões anteriores o badge ainda mostrava a versão antiga.

### 3. ✅ Marcador no Mini-Mapa (herdado da v1.0.20)
- O ícone de localização (gotinha vermelha) aparece no mini-mapa da tela da câmera **antes** de bater a foto.

---

## 📦 Instruções de Upload no GitHub

Para ativar o sistema de atualização OTA, siga os passos:

1. Acesse o repositório no GitHub:  
   `https://github.com/devairfernandes/markpro_camera`

2. Clique em **Releases → Draft a new release**.

3. Defina a tag como `1.0.21`.

4. No título coloque: `MarkPro Camera v1.0.21`

5. No campo de descrição, cole o conteúdo abaixo:
   ```
   - Importar configurações agora abre o explorador de arquivos .json
   - Versão corrigida no painel de configurações
   - Marcador de localização (gotinha) no mini mapa
   ```

6. Faça o upload do arquivo APK:  
   `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`

7. **Renomeie o arquivo** no GitHub para:  
   `app-arm64-v8a-release.apk`

8. Clique em **Publish Release**.

---

> ✅ Após publicar, o sistema OTA detectará automaticamente a nova versão e os usuários receberão a notificação de atualização dentro do app.

---

*MarkPro Camera — Precisão e Confiança no Registro de Trabalho.*  
*Dev: Devair Fernandes | 69 99221-4709*
