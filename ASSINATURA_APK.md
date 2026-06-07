# 🔐 Assinatura de APK - Maria Maia

## Configuração Inicial

### 1️ Gerar Keystore (primeira vez)

Execute o script para criar o arquivo de assinatura:

```bash
cd android
chmod +x keystore.sh
./keystore.sh
```

Ou manualmente com keytool:

```bash
keytool -genkey -v \
  -keystore app/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload \
  -storepass maria2025 \
  -keypass maria2025 \
  -dname "CN=Maria Maia, OU=Pecuaria, O=TraceInChain, L=Brasil, S=Brasil, C=BR"
```

### 2️ Verificação do Keystore

Confirme que o arquivo foi criado:

```bash
ls -lah app/upload-keystore.jks
```

### 3️ Credenciais

As credenciais estão configuradas em `android/key.properties`:

```properties
storePassword=maria2025
keyPassword=maria2025
keyAlias=upload
storeFile=app/upload-keystore.jks
```

## 🏗️ Gerar APK Assinado

### Opção 1: Build Release via Flutter

```bash
flutter build apk --release
```

O APK assinado será gerado em:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Opção 2: Build App Bundle (Google Play)

```bash
flutter build appbundle --release
```

O bundle será gerado em:
```
build/app/outputs/bundle/release/app-release.aab
```

### Opção 3: Build Split APKs (por arquitetura)

```bash
flutter build apk --release --split-per-abi
```

Gera APKs separados para cada arquitetura (menor tamanho).

## 📊 Informações do Keystore

| Propriedade | Valor |
|-------------|-------|
| Alias | `upload` |
| Algoritmo | RSA 2048-bit |
| Validade | 10.000 dias (~27 anos) |
| Senha | `maria2025` |
| CN | Maria Maia |
| Organização | TraceInChain |

## 🚀 Publicar na Google Play

1. **Faça login** em [Google Play Console](https://play.google.com/console)
2. **Crie um novo app** ou selecione existente
3. **Vá para** `Versão > Produção`
4. **Envie** o arquivo `.aab` gerado
5. **Preencha** informações do app (descrição, screenshots, etc.)
6. **Aguarde aprovação** (geralmente 24-48 horas)

## ⚠️ Segurança

- **Backup do Keystore**: Guarde `app/upload-keystore.jks` em local seguro
- **Não compartilhe**: Nunca compartilhe o arquivo ou senhas
- **key.properties**: Adicione `android/key.properties` ao `.gitignore`

```bash
echo "android/key.properties" >> .gitignore
echo "android/app/upload-keystore.jks" >> .gitignore
```

## 🔧 Troubleshooting

### Erro: "Keystore not found"
```bash
# Recrie o keystore
./keystore.sh
```

### Erro: "Invalid keystore format"
```bash
# Delete e recrie
rm android/app/upload-keystore.jks
./keystore.sh
```

### Erro: "Wrong password"
Verifique `android/key.properties` e confirme as senhas

## 📝 Comandos Úteis

```bash
# Listar keystore
keytool -list -v -keystore android/app/upload-keystore.jks -storepass maria2025

# Validar APK assinado
jarsigner -verify -verbose build/app/outputs/flutter-apk/app-release.apk

# Ver tamanho do APK
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

---

**Maria Maia © 2026 - Gestor de Pecuária Pro**
