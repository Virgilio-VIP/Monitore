# Guia de Uso - Bridge de Imagens MariaMaia

## Como Usar a Ponte JavaScript ↔ Dart/Flutter

Este documento explica como usar a ponte de comunicação para salvar imagens na galeria do Android a partir da sua aplicação web (React/JavaScript).

---

## 1. Solicitar Permissões

**Quando:** Ao iniciar o app ou quando do primeiro uso

```javascript
// Chamar o handler Dart para solicitar permissões
const result = await window.flutter_inappwebview.callHandler(
  'requestPermissions'
);

console.log('Permissões:', result);
// Resposta esperada:
// {
//   camera: true,
//   photos: true,
//   storage: true
// }
```

---

## 2. Salvar Imagem na Galeria

**Quando:** Após capturar uma foto com a câmera ou selecionar uma imagem

### Exemplo 1: Capturar de um Canvas

```javascript
// 1. Capturar imagem de um canvas
const canvas = document.getElementById('camera-canvas');
const imageBase64 = canvas.toDataURL('image/jpeg', 0.8)
  .split(',')[1]; // Remove o prefixo "data:image/jpeg;base64,"

// 2. Salvar na galeria
const result = await window.flutter_inappwebview.callHandler(
  'saveImageToGallery',
  {
    imageBase64: imageBase64,
    fileName: `foto_pasto_${new Date().toISOString().slice(0, 10)}.jpg`
  }
);

if (result.success) {
  console.log('✓ Imagem salva:', result.path);
  // Mostrar notificação ao usuário
  showNotification('Imagem salva com sucesso na galeria!');
} else {
  console.error('✗ Erro ao salvar:', result.error);
  showNotification('Erro ao salvar a imagem');
}
```

### Exemplo 2: Salvar de um Input File

```javascript
// 1. Obter arquivo do input
const fileInput = document.getElementById('photo-input');
const file = fileInput.files[0];

// 2. Converter para base64
const reader = new FileReader();
reader.onload = async (e) => {
  const imageBase64 = e.target.result.split(',')[1];
  
  const result = await window.flutter_inappwebview.callHandler(
    'saveImageToGallery',
    {
      imageBase64: imageBase64,
      fileName: `rebanho_${Date.now()}.jpg`
    }
  );
  
  if (result.success) {
    console.log('✓ Salvo:', result.path);
  }
};
reader.readAsDataURL(file);
```

### Exemplo 3: Com Tratamento de Erros Robusto

```javascript
async function savePhotoToGallery(canvasElement, photoName) {
  try {
    // Validar canvas
    if (!canvasElement) {
      throw new Error('Canvas não encontrado');
    }

    // Extrair imagem
    const imageData = canvasElement.toDataURL('image/jpeg', 0.85);
    
    // Validar se é válida
    if (!imageData.startsWith('data:image')) {
      throw new Error('Dados de imagem inválidos');
    }

    // Remover prefixo base64
    const imageBase64 = imageData.split(',')[1];

    // Chamar bridge
    console.log('📸 Salvando imagem:', photoName);
    const result = await window.flutter_inappwebview.callHandler(
      'saveImageToGallery',
      {
        imageBase64: imageBase64,
        fileName: `MariaMaia_${photoName}_${Date.now()}.jpg`
      }
    );

    // Processar resposta
    if (result.success) {
      console.log('✅ Imagem salva com sucesso!');
      console.log('   Caminho:', result.path);
      console.log('   Tamanho:', result.size, 'bytes');
      return { success: true, data: result };
    } else {
      console.error('❌ Erro ao salvar:', result.error);
      return { success: false, error: result.error };
    }

  } catch (error) {
    console.error('❌ Erro inesperado:', error.message);
    return { 
      success: false, 
      error: `Erro: ${error.message}` 
    };
  }
}

// Uso:
const response = await savePhotoToGallery(
  document.getElementById('camera'),
  'pasto-norte'
);
```

---

## 3. Integração com React Hook

```javascript
import { useCallback } from 'react';

export function useGalleryManager() {
  const saveImage = useCallback(async (imageBase64, fileName) => {
    try {
      if (!window.flutter_inappwebview) {
        throw new Error('Flutter bridge não disponível');
      }

      const result = await window.flutter_inappwebview.callHandler(
        'saveImageToGallery',
        {
          imageBase64,
          fileName: fileName || `foto_${Date.now()}.jpg`
        }
      );

      return result;
    } catch (error) {
      console.error('Erro ao salvar imagem:', error);
      return { success: false, error: error.message };
    }
  }, []);

  const requestPermissions = useCallback(async () => {
    try {
      const result = await window.flutter_inappwebview.callHandler(
        'requestPermissions'
      );
      return result;
    } catch (error) {
      console.error('Erro ao solicitar permissões:', error);
      return null;
    }
  }, []);

  return { saveImage, requestPermissions };
}

// Uso em um componente:
export function CameraComponent() {
  const { saveImage } = useGalleryManager();

  const handleCapture = async () => {
    const canvas = canvasRef.current;
    const base64 = canvas.toDataURL('image/jpeg', 0.8).split(',')[1];
    
    const result = await saveImage(base64, 'captura-do-dia.jpg');
    
    if (result.success) {
      alert('Imagem salva!');
    }
  };

  return <button onClick={handleCapture}>Capturar Foto</button>;
}
```

---

## 4. Requisitos

✅ **Permissões Android** (já configuradas em `AndroidManifest.xml`):
- `android.permission.WRITE_EXTERNAL_STORAGE`
- `android.permission.READ_EXTERNAL_STORAGE`
- `android.permission.CAMERA`

✅ **Diretório de Saída**:
- Imagens são salvas em: `/storage/emulated/0/Pictures/MariaMaia/`
- Automaticamente visível na galeria do Android

✅ **Formatos Suportados**:
- JPEG
- PNG
- WebP

---

## 5. Verificação de Disponibilidade

```javascript
// Verificar se o bridge está disponível
function hasFlutterBridge() {
  return typeof window.flutter_inappwebview !== 'undefined';
}

// Exemplo de uso
if (hasFlutterBridge()) {
  // Usar a ponte
  const result = await window.flutter_inappwebview.callHandler(...);
} else {
  // Usar fallback (ex: localforage, IndexedDB)
  console.warn('Flutter bridge não disponível');
}
```

---

## 6. Troubleshooting

### "Imagem não aparece na galeria"
1. Verifique se a permissão foi concedida
2. Verifique se `saveImageToGallery` retornou `success: true`
3. Verifique o caminho: deve estar em `/Pictures/MariaMaia/`

### "Erro: Bridge não disponível"
- O app está rodando dentro do WebView Flutter?
- Verifique se o handler foi registrado no Dart

### "Permissão negada"
- Usuário rejeitou a permissão na primeira vez
- Ir em Configurações > MariaMaia > Permissões e ativar

---

## 7. Logs de Debug

Verifique os logs do Dart (Flutter Console) para debug:

```
flutter logs
```

Procure por mensagens como:
- `✓ Handlers JavaScript registrados`
- `=== Handler JavaScript: saveImageToGallery ===`
- `✓ Imagem salva com sucesso!`
- `✗ Erro ao salvar imagem:`

