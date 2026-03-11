# 📸 MarkPro Camera

> **Câmera Profissional com Carimbo de Prova — by Devair Fernandes**

[![Versão](https://img.shields.io/badge/versão-1.0.21-00E676?style=for-the-badge)](https://github.com/devairfernandes/markpro_camera/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-5.0%2B-3DDC84?style=for-the-badge&logo=android)](https://developer.android.com)
[![Licença](https://img.shields.io/badge/licença-privado-red?style=for-the-badge)](LICENSE)

---

## 🎯 O que é o MarkPro Camera?

O **MarkPro Camera** é uma ferramenta fotográfica de alta precisão desenvolvida para profissionais que precisam de **prova irrefutável de data, horário e localização**. Ideal para:

- 👷 Obras e vistorias técnicas
- 🔧 Manutenções e serviços de campo
- 📋 Laudos e relatórios técnicos
- 🏠 Registros imobiliários
- 🚗 Relatórios de acidentes e sinistros

---

## ✨ Funcionalidades

| Recurso | Descrição |
|--------|-----------|
| 🛰️ **GPS Preciso** | Latitude, Longitude, Altitude e Precisão em tempo real |
| 🕐 **Carimbo de Data/Hora** | Hora e data com sincronização automática |
| 🗺️ **Mini Mapa Integrado** | Visão aérea da localização usando OpenStreetMap (sem API key) |
| 🏢 **Logo Personalizada** | Importe o logo da sua empresa para aparecer nas fotos |
| 📛 **Nome do Projeto** | Identifique cada conjunto de fotos com um nome personalizado |
| ✍️ **Assinatura do Dev** | Marca d'água lateral com identificação do desenvolvedor |
| 📂 **Galeria Interna** | Galeria MarkPro com localização garantida para cada foto |
| 🔗 **Link do Maps** | Compartilhe um link do Google Maps direto da foto |
| 🔄 **Atualização OTA** | Receba novas versões automaticamente pelo próprio app |
| ⚙️ **Exportar/Importar Config** | Salve suas configurações em arquivo `.json` |

---

## 🚀 Como Instalar

1. Acesse a seção [**Releases**](https://github.com/devairfernandes/markpro_camera/releases)
2. Baixe o arquivo `app-release.apk` da versão mais recente
3. No Android, ative **"Instalar de fontes desconhecidas"** nas configurações de segurança
4. Abra o APK e instale

> ✅ O app se atualiza automaticamente via OTA quando uma nova versão for publicada!

---

## 📱 Como Usar

### Tirar uma foto com carimbo
1. Abra o app — a câmera inicia automaticamente
2. Aguarde o GPS carregar (ícone verde no canto)
3. Pressione o botão central para capturar
4. A foto é salva na galeria com todos os dados de localização

### Acessar a Galeria MarkPro
- **Toque longo** no botão de galeria (canto inferior esquerdo)
- Fotos com **badge verde 📍** têm GPS garantido
- Toque em uma foto para ver detalhes e compartilhar o link do Maps
- **Segure** uma foto para excluí-la

### Configurações
- Toque no ícone **⚙️** (canto inferior direito)
- Configure o nome do projeto, logo, e itens visíveis no carimbo
- Use **"Exportar Config"** para salvar e compartilhar suas configurações

---

## ⚙️ Configurações Disponíveis

| Item | Descrição |
|------|-----------|
| **Nome do Projeto** | Aparece no topo da foto |
| **Logo da Empresa** | Substitui o nome do projeto por uma imagem |
| **Data / Hora** | Exibe a data e hora no carimbo |
| **Endereço** | Endereço geocodificado via GPS |
| **Mini Mapa** | Mini mapa aéreo da localização |
| **Coordenadas** | Lat/Long em graus decimais |
| **Altitude** | Altitude e precisão do GPS |

---

## 🛠️ Stack Técnica

| Tecnologia | Uso |
|---|---|
| **Flutter 3.x** | Framework principal |
| **Dart Image Library** | Processamento de imagem em Isolate |
| **Geolocator** | GPS e permissões |
| **Flutter Map + OSM** | Mapa integrado sem API key |
| **Shared Preferences** | Banco de dados local de fotos e configurações |
| **Share Plus** | Compartilhamento de fotos e arquivos |
| **OTA Update** | Atualização automática via GitHub Releases |
| **Native EXIF** | Escrita de metadados GPS no arquivo de imagem |

---

## 📋 Histórico de Versões

Veja o [CHANGELOG.md](CHANGELOG.md) para o histórico completo.

### Última versão: **v1.0.18** *(10/03/2026)*
- Exportar Config gera arquivo `.json` real
- Badge de versão corrigido nas configurações
- Assinatura do desenvolvedor na lateral de cada foto
- GPS solicitado corretamente na primeira abertura
- Menu de configurações premium redesenhado
- Galeria interna com localização permanente

---

## 📞 Contato do Desenvolvedor

**Devair Fernandes**
📱 69 99221-4709

---

*MarkPro Camera — O Padrão Profissional para Prova Digital.*
