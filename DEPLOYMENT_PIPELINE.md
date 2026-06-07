# 🔄 Deploy Pipeline - Maria Maia

## Arquitetura

```
Desenvolvimento
    ↓
git push + tag
    ↓
GitHub Actions (shorebird-deploy.yml)
    ↓
Shorebird Build (Patch ou Release)
    ↓
Usuários recebem automaticamente
```

## 🏷️ Sistema de Tags

### Patch (Hot Update)

```bash
git tag -a "patch-v1.0.1" -m "Fix: Erro ao carregar dados"
git push origin patch-v1.0.1
```

Ativa: `shorebird patch android --release`

### Release (Nova Versão)

```bash
git tag -a "release-v1.1.0" -m "Feature: Novo dashboard"
git push origin release-v1.1.0
```

Ativa: `shorebird build apk --release`

## 📝 Fluxo Completo

### Passo 1: Desenvolvimento

```bash
git checkout -b feature/nova-feature
# ... edite código ...
git add .
git commit -m "feat: nova funcionalidade"
git push origin feature/nova-feature
```

### Passo 2: Criar Tag (Patch)

```bash
# Versão atual: 1.0.0
# Nova tag: patch-v1.0.1

git tag -a "patch-v1.0.1" -m "Fix: Erro crítico"
git push origin patch-v1.0.1
```

**GitHub Actions executa automaticamente!** ✨

### Passo 3: Monitorar Deploy

```bash
# Ver status no GitHub Actions
# https://github.com/seu-usuario/maria-maia/actions

# Ou localmente:
shorebird releases list
shorebird patches list
```

### Passo 4: Usuários Recebem

- Usuários reiniciam o app
- App baixa o patch automaticamente
- Atualização é aplicada em background
- Na próxima abertura, nova versão está ativa

## 🔐 Configurar Segredos (GitHub)

Para CI/CD funcionar, configure no GitHub:

1. Vá para: `Settings > Secrets and variables > Actions`

2. Adicione:
   - `SHOREBIRD_TOKEN` - Token do Shorebird
   - `PLAY_STORE_CONFIG` - JSON de credenciais
   - `GITHUB_TOKEN` - Token do GitHub (automático)

### Obter SHOREBIRD_TOKEN

```bash
shorebird token create --name "CI/CD"
# Copie o token e adicione ao GitHub
```

## 📊 Monitoramento

### Ver Histórico de Patches

```bash
shorebird patches list <version>
```

**Output exemplo:**
```
Version 1.0.0
  └─ Patch 1 (2026-03-12)
     └─ Status: Live
     └─ Active Devices: 1,245
     └─ Rollout: 100%
  └─ Patch 2 (2026-03-13)
     └─ Status: Live
     └─ Active Devices: 1,250
```

### Ver Instalações

```bash
shorebird releases info 1.0.0
```

## 🚨 Rollback

Se algo der errado:

```bash
# Listar patches
shorebird patches list

# Rollback (futura feature)
# shorebird patches rollback <patch-id>

# Ou manualmente:
# Remova o patch do dashboard do Shorebird
```

## 💡 Boas Práticas

### ✅ DOs

```bash
# ✅ Mensagens descritivas
git tag -a "patch-v1.0.1" -m "Fix: TypeError ao salvar rebanho"

# ✅ Commits atômicos
git commit -m "fix: valida entrada de peso"

# ✅ Testa antes
flutter test
flutter run --release

# ✅ Patches pequenos
# Apenas as mudanças necessárias
```

### ❌ DON'Ts

```bash
# ❌ Não faça
git tag -a "v123" -m "update"

# ❌ Não commitne sem testar
# ❌ Não misture features em um patch
# ❌ Não force push após tag
```

## 📚 Scripts Úteis

### Deploy Patch (Local)

```bash
./deploy.sh patch android
```

### Build Release (Local)

```bash
./deploy.sh release android
```

### Verificar Status

```bash
shorebird releases list
shorebird account current
shorebird config show
```

### Logout

```bash
shorebird logout
```

## 🆘 Troubleshooting

### GitHub Actions Falhando

1. Verifique `SHOREBIRD_TOKEN` em Settings > Secrets
2. Confirme que token é válido: `shorebird token validate`
3. Veja logs: GitHub > Actions > Workflow failures

### App Não Recebe Patch

1. Verifique se app está conectado à internet
2. Aguarde alguns minutos (cache de 5 min)
3. Force refresh no app
4. Confirme versão base via release

### Erro: "Unmatched tag"

```bash
# Certifique-se que a tag segue o padrão:
# patch-v1.0.0 ou release-v1.0.0

git tag -l
# Deletar tag errada
git tag -d wrong-tag
git push origin --delete wrong-tag
```

## 🎯 Exemplo Real

### Cenário: Corrigir Erro Crítico

```bash
# 1. Identificar erro
# Usuários reportam: "Erro ao salvar rebanho"

# 2. Clonar código
git clone <repo>
cd maria-maia

# 3. Criar branch
git checkout -b hotfix/save-bug

# 4. Corrigir
# ... edita código ...

# 5. Testar
flutter run --release
# ✅ Funciona!

# 6. Commit
git add .
git commit -m "fix: erro ao salvar rebanho - falta validação"
git push origin hotfix/save-bug

# 7. Merge em main
git checkout main
git merge --ff-only hotfix/save-bug

# 8. Tag (Patch)
git tag -a "patch-v1.0.2" -m "Fix: Crítico - erro ao salvar rebanho"
git push origin patch-v1.0.2

# 9. Await deployment
# GitHub Actions executa automaticamente

# 10. Monitor
# https://github.com/seu-repo/actions

# ✨ Usuários recebem fix em segundos!
```

---

**Maria Maia © 2026 - Deployment Pipeline com Shorebird** 🚀
