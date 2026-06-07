# 🚀 Shorebird - Hot Updates para Maria Maia

Shorebird permite atualizar o app Flutter **sem precisar republish na Google Play Store**. Tudo funciona via OTA (Over-The-Air).

## 📦 Instalação do Shorebird CLI

### macOS com Homebrew (recomendado no futuro)
```bash
brew install shorebird
```

### Via Script Oficial (macOS/Linux)
```bash
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/shorebird/main/scripts/install.sh -sSf | bash
```

### Windows
Baixe no [shorebird.dev/download](https://shorebird.dev/download)

### Via Flutter Pub (alternativa)
```bash
dart pub global activate shorebird
```

## 🔧 Configuração do Projeto

O projeto já está configurado com:
- `shorebird.yaml` - Configuração base
- `android/key.properties` - Credenciais (compartilhadas com Shorebird)

### Primeiro Login
```bash
shorebird login
```

Ou registre uma conta:
```bash
shorebird account create --email seu_email@exemplo.com
```

## 📱 Build Inicial com Shorebird

Para criar a versão base:

```bash
# Android
shorebird build apk --release

# iOS  
shorebird build ipa
```

OuApk será gerado assinado automaticamente em:
```
build/app/outputs/flutter-apk/app-release.apk
```

## 🔄 Enviando Atualizações (Hot Updates)

Após fazer mudanças no código, envie um patch sem republish:

```bash
shorebird patch android --release
```

Isso:
- ✅ Compila apenas o Dart
- ✅ Testa a mudança
- ✅ Envia para todos os usuários automaticamente
- ❌ Não precisa renovar assinatura
- ❌ Não precisa passar na App Store review

### Exemplo de Fluxo de Atualização:

```bash
# 1. Corrija um bug no código
vim lib/main.dart

# 2. Envie o patch
shorebird patch android --release

# 3. Pronto! Usuários recebem em tempo real
```

## 📊 Dashboard de Releases

```bash
# Ver histórico de patches
shorebird releases list

# Ver detalhes de um release
shorebird releases info <version>

# Ver patches enviados
shorebird patches list <version>
```

## 🎯 Casos de Uso Ideais

✅ **Correções rápidas** - Bug fix que não pode esperar
✅ **Ajustes de UI** - Mudanças visuais menores
✅ **Texto e mensagens** - Atualização de copy
✅ **Hotfix crítico** - Problema de segurança
✅ **A/B Testing** - Experimentos rápidos

❌ **Não use para**: Mudanças no AndroidManifest, permissões, mudanças no Kotlin/Swift

## 🔐 Segurança

- Shorebird assina criptograficamente todos os updates
- Apenas seu app pode instalar seus updates
- Updates são entregues via HTTPS
- App verifica integridade antes de instalar

## 📈 Monitoramento

```bash
# Ver estatísticas de deployment
shorebird patches info <patch-number>

# Ver rollout status
shorebird releases info <version>
```

## 🚨 Rollback de Patches

Se algo der errado:

```bash
# Listar patches
shorebird patches list <version>

# Fazer rollback (futura feature)
shorebird patches rollback <patch-number>
```

## 💬 Exemplos Práticos

### 1. Corrigir Mensagem de Erro

```bash
# Edite a mensagem em lib/main.dart
# ...
errorMessage = 'Erro ao carregar: ${error.description}';

# Envie o patch
shorebird patch android --release

# Pronto! Todos veem a mensagem corrigida em segundos
```

### 2. Ajustar Cor do Tema

```bash
# Mude a cor em lib/main.dart
colorSchemeSeed: const Color(0xFF1B5E20), // Era #2E7D32

# Deploy
shorebird patch android --release
```

### 3. Habilitar/Desabilitar Feature

```dart
// Feature flag dentro do código
const bool FEATURE_NEW_DASHBOARD = false; // true = habilita

// Mude para true e faça patch
shorebird patch android --release
```

## 🆘 Troubleshooting

### Erro: "No active user"
```bash
shorebird login
```

### Erro: "Build failed"
```bash
flutter clean
flutter pub get
shorebird patch android --release
```

### App não recebe update
1. Reinicie o app
2. Verifique conexão internet
3. Confirme app é versão correta com Shorebird integrado

## 📚 Links Úteis

- [Documentação Shorebird](https://shorebird.dev/docs)
- [GitHub Shorebird](https://github.com/shorebirdtech/shorebird)
- [Discord Community](https://discord.gg/shorebird)

## 🎛️ Variáveis de Ambiente (Opcional)

```bash
# Diretório de cache do Shorebird
export SHOREBIRD_CACHE=~/.shorebird

# Token para CI/CD
export SHOREBIRD_TOKEN=seu_token_aqui
```

## 💡 Dicas Profissionais

1. **Sempre teste localmente primeiro**
   ```bash
   shorebird patch android --release --dry-run
   ```

2. **Mantenha patches pequenos** - Menos dados = faster download

3. **Version control** - Commit/tag antes de enviar patch
   ```bash
   git tag -a "patch-v1.0.1" -m "Fix loading error"
   shorebird patch android --release
   ```

4. **Monitoring** - Acompanhe rollout antes de confirmar

5. **Fallback** - Sempre tenha Android Debug Bridge para rollback manual

---

**Maria Maia © 2026 - Gestor de Pecuária Pro com Shorebird** 🚀
