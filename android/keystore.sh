#!/bin/bash
# Script para gerar keystore para assinatura de APK
# Maria Maia - Gestor de Pecuária Pro

cd "$(dirname "$0")"

# Criar keystore
keytool -genkey -v \
  -keystore app/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload \
  -storepass maria2025 \
  -keypass maria2025 \
  -dname "CN=Maria Maia, OU=Pecuaria, O=TraceInChain, L=Brasil, S=Brasil, C=BR"

echo "✓ Keystore criado em: app/upload-keystore.jks"
echo "  Alias: upload"
echo "  Password: maria2025"
echo "  Validade: 10000 dias (~27 anos)"
