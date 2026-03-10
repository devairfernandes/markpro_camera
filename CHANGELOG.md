# 📋 MarkPro Camera — Changelog

Todas as mudanças notáveis estão registradas neste arquivo.  
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).

---

## [1.0.18] — 10/03/2026
### 🔧 Correções
- **Exportar Configurações**: Corrigido para gerar um arquivo `.json` real compartilhável (antes compartilhava texto puro)
- **Badge de versão**: Corrigido nas configurações para exibir `v1.0.18`
- O arquivo exportado agora inclui `customTitle`, `exportedAt` e `version`

---

## [1.0.17] — 10/03/2026
### ✨ Novidades
- **Assinatura do Desenvolvedor**: Texto "Dev: Devair Fernandes 69 99221-4709" exibido verticalmente na lateral direita de todas as fotos
- Texto com fundo semitransparente para manter legibilidade

---

## [1.0.16] — 10/03/2026
### 🎨 Redesign
- **Menu de configurações completamente redesenhado**:
  - Seção "Identidade do Projeto" com card gradiente e preview de logo
  - Seção "Carimbo Visual" com grid animado de chips (toque para ativar/desativar)
  - Seção "Configurações Avançadas" com exportar, importar e verificar GPS
  - Badge de versão no topo do menu
  - Modal deslizável até tela cheia (`DraggableScrollableSheet`)
- Botão "Remover Logo" aparece dinamicamente quando há logo carregada

---

## [1.0.15] — 10/03/2026
### 🛰️ GPS e Permissões
- Permissão de localização solicitada corretamente na **primeira abertura** do app
- Novo diálogo quando o GPS está desligado com botão **"Ativar GPS"** (abre configurações do Android)
- Novo diálogo quando a permissão foi negada com atalho para configurações do app
- Após ativar o GPS, a localização é buscada automaticamente ao voltar para o app

---

## [1.0.14] — 10/03/2026
### 📂 Galeria Interna
- **Galeria Interna MarkPro**: substituição da galeria externa pelo picker nativo
- Fotos tiradas pelo app são copiadas para diretório interno (`markpro_photos/`)
- Metadados GPS, endereço e timestamp salvos em banco local (`SharedPreferences`)
- Badge verde **📍** em fotos com GPS disponível
- Link do Google Maps garantido para qualquer foto, mesmo após reiniciar o app
- Exclusão de fotos diretamente da galeria interna
- Limite de 200 fotos armazenadas internamente

---

## [1.0.13] — 09/03/2026
### 🗺️ Mapa e Visual
- Substituição do Google Maps por **OpenStreetMap** (sem necessidade de API key)
- Mapa com tiles de alto contraste (CartoDB)
- Ícone do app atualizado

---

## [1.0.2] — 09/03/2026
### 🚀 Lançamento Oficial
- Processamento de imagem migrado para **Isolates** (app não trava ao salvar)
- Renomeado oficialmente para **MarkPro Camera**
- Sistema de atualização automática **OTA** via GitHub funcionando
- README premium e documentação técnica

---

## [1.0.1] — 09/03/2026
### ✨ Novidades
- Logo customizável da galeria do dispositivo
- Exportar e Importar configurações via JSON
- Melhoria na precisão do GPS e altitude
- Logo 50% maior no carimbo

---

## [1.0.0] — 09/03/2026
### 📦 Lançamento Beta
- Primeiro protótipo funcional com timestamp
- Mapa dinâmico integrado (OSM)
- Salvamento automático na galeria
- Verificação de autenticidade (Original Photo Verified)
