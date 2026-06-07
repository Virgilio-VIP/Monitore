# 🚀 Quick Start - Shorebird

## ✅ O que foi configurado

- ✅ `shorebird.yaml` - Configuração base
- ✅ `deploy.sh` - Script de deploy (patch/release)
- ✅ GitHub Actions workflow - Deploy automático via tags
- ✅ `.gitignore` - Protege dados sensíveis

## 🔧 Próximos Passos

### 1. Instalar Shorebird CLI

```bash
# macOS / Linux
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/shorebird/main/scripts/install.sh -sSf | bash

# Ou Windows: https://shorebird.dev/download
```

### 2. Fazer Login

```bash
shorebird login
# ou
shorebird account create --email seu_email@exemplo.com
```

### 3. Fazer Build Inicial

```bash
# Build a versão base (uma única vez)
shorebird build apk --release

# Enviar para Google Play Store
```

### 4. Enviar Patches (Hot Updates)

```bash
# Após fazer mudanças no código:
./deploy.sh patch android

# Ou manualmente:
shorebird patch android --release

# Pronto! Todos os usuários recebem em tempo real 🎉
```

## 📊 Exemplo de Fluxo

```bash
# 1. Faça mudanças (e.g., corrija um bug)
vim lib/main.dart

# 2. Teste localmente
flutter run --release

# 3. Envie o patch
./deploy.sh patch android

# 4. Usuários recebem automaticamente em segundos
```

## 🎯 Quando Usar

### ✅ Use Shorebird Patch Para:
- Correções rápidas (bug fixes)
- Ajustes de UI/styling
- Mudanças de texto
- Hotfix crítico

### ❌ Não Use Para:
- Mudanças em dependências nativas
- Alterações em AndroidManifest
- Mudanças em permissões
- Atualizações de Kotlin/Swift

## 🔗 Links Úteis

- [Shorebird Docs](https://shorebird.dev)
- [GitHub Shorebird](https://github.com/shorebirdtech/shorebird)
- [Discord Community](https://discord.gg/shorebird)

---

Veja `SHOREBIRD_SETUP.md` para documentação completa! 📚
