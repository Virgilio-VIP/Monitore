#!/bin/bash
# 🚀 Script de Deploy com Shorebird
# Maria Maia - Gestor de Pecuária Pro
#
# Uso: ./deploy.sh [patch|release] [android|ios]
# Exemplo: ./deploy.sh patch android

set -e

DEPLOY_TYPE=${1:-patch}
PLATFORM=${2:-android}
VERSION=$(grep "version:" pubspec.yaml | head -1 | cut -d: -f2 | xargs)

echo "════════════════════════════════════════════════════════"
echo "  🚀 Maria Maia Deploy - Shorebird"
echo "════════════════════════════════════════════════════════"
echo "  Tipo: $DEPLOY_TYPE"
echo "  Plataforma: $PLATFORM"
echo "  Versão: $VERSION"
echo "════════════════════════════════════════════════════════"
echo ""

# Verificar se Shorebird está instalado
if ! command -v shorebird &> /dev/null; then
    echo "❌ Shorebird não encontrado!"
    echo "   Instale com: curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/shorebird/main/scripts/install.sh -sSf | bash"
    exit 1
fi

# Verificar se está logado
if ! shorebird account current &> /dev/null; then
    echo "❓ Não está logado no Shorebird"
    echo "   Faça login com: shorebird login"
    exit 1
fi

# Limpeza
echo "🧹 Limpando projeto..."
flutter clean
flutter pub get

if [ "$DEPLOY_TYPE" = "patch" ]; then
    echo ""
    echo "🔄 Enviando Patch (Hot Update)..."
    
    if [ "$PLATFORM" = "android" ]; then
        shorebird patch android --release
    elif [ "$PLATFORM" = "ios" ]; then
        shorebird patch ios
    fi
    
    echo ""
    echo "✅ Patch enviado com sucesso!"
    echo "   Usuários receberão a atualização automaticamente"
    
elif [ "$DEPLOY_TYPE" = "release" ]; then
    echo ""
    echo "📦 Compilando Release Build..."
    
    if [ "$PLATFORM" = "android" ]; then
        shorebird build apk --release
        echo ""
        echo "✅ APK assinado criado em:"
        echo "   build/app/outputs/flutter-apk/app-release.apk"
    elif [ "$PLATFORM" = "ios" ]; then
        shorebird build ipa
        echo ""
        echo "✅ IPA criado em:"
        echo "   build/ios/ipa/"
    fi
    
else
    echo "❌ Tipo de deploy inválido: $DEPLOY_TYPE"
    echo "   Use: patch ou release"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✨ Deploy concluído!"
echo "════════════════════════════════════════════════════════"
