# JavaScript Bridge - Guia de Uso

## 📸 Salvando Imagens na Galeria

A aplicação Dart agora possui dois handlers JavaScript que permitem salvar imagens e solicitar permissões diretamente do React.

### Handler: `saveImageToGallery`

Salva uma imagem (em formato base64) na galeria do dispositivo.

**Assinatura:**
```javascript
window.flutter_inappwebview.callHandler(
  'saveImageToGallery',
  {
    base64: '<string_base64_da_imagem>',
    name: '<nome_do_arquivo>'  // opcional, padrão: photo_TIMESTAMP.jpg
  }
)
```

**Resposta:**
```javascript
{
  success: true,           // boolean
  message: 'Descrição',    // string
  path: '/caminho/arquivo' // string (apenas se success=true)
}
```

**Exemplo de Uso em React:**

```javascript
import { useState } from 'react';

function PhotoCapture() {
  const [saving, setSaving] = useState(false);
  const [result, setResult] = useState(null);

  const handleSavePhoto = async (base64ImageData) => {
    setSaving(true);
    try {
      const response = await window.flutter_inappwebview.callHandler(
        'saveImageToGallery',
        {
          base64: base64ImageData,
          name: `Maria_${new Date().toISOString()}.jpg`
        }
      );
      
      setResult(response);
      
      if (response.success) {
        console.log('✅ Imagem salva:', response.path);
      } else {
        console.error('❌ Erro:', response.message);
      }
    } catch (error) {
      console.error('Erro ao chamar handler:', error);
      setResult({ success: false, message: error.message });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div>
      <button 
        onClick={() => handleSavePhoto('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAA...')}
        disabled={saving}
      >
        {saving ? 'Salvando...' : 'Salvar Foto'}
      </button>
      {result && (
        <div style={{ color: result.success ? 'green' : 'red' }}>
          {result.message}
        </div>
      )}
    </div>
  );
}

export default PhotoCapture;
```

---

### Handler: `requestPhotosPermission`

Solicita permissão ao usuário para acessar fotos/câmera.

**Assinatura:**
```javascript
window.flutter_inappwebview.callHandler('requestPhotosPermission')
```

**Resposta:**
```javascript
{
  granted: true,        // boolean - permissão foi concedida?
  status: 'granted'     // string - status detalhado
}
```

**Exemplo de Uso em React:**

```javascript
import { useState, useEffect } from 'react';

function PhotoPermission() {
  const [hasPermission, setHasPermission] = useState(false);
  const [checkingPermission, setCheckingPermission] = useState(true);

  useEffect(() => {
    requestPhotoPermission();
  }, []);

  const requestPhotoPermission = async () => {
    try {
      const response = await window.flutter_inappwebview.callHandler(
        'requestPhotosPermission'
      );
      
      setHasPermission(response.granted);
      
      if (response.granted) {
        console.log('✅ Permissão concedida');
      } else {
        console.warn('⚠️ Permissão negada:', response.status);
      }
    } catch (error) {
      console.error('Erro ao solicitar permissão:', error);
    } finally {
      setCheckingPermission(false);
    }
  };

  if (checkingPermission) return <div>Verificando permissões...</div>;
  
  if (!hasPermission) {
    return (
      <div>
        <p>Permissão necessária para usar câmera</p>
        <button onClick={requestPhotoPermission}>
          Conceder Permissão
        </button>
      </div>
    );
  }

  return <div>Câmera habilitada</div>;
}

export default PhotoPermission;
```

---

## 🔄 Fluxo Completo: Captura → Conversão → Salvamento

```javascript
// 1. Capturar image do canvas ou input
const canvas = document.querySelector('canvas');
const imageData = canvas.toDataURL('image/jpeg');

// 2. Extrair a parte base64 (remover o prefixo "data:image/jpeg;base64,")
const base64String = imageData.split(',')[1];

// 3. Enviar para Dart
const result = await window.flutter_inappwebview.callHandler(
  'saveImageToGallery',
  {
    base64: base64String,
    name: `photo_${Date.now()}.jpg`
  }
);

// 4. Processar resposta
if (result.success) {
  alert('Foto salva com sucesso!');
} else {
  alert('Erro: ' + result.message);
}
```

---

## 📂 Localização das Fotos

As imagens são salvas em:
```
/data/data/com.mariamaia.maria_maia/app_Documents/Pictures/
```

**Nota importante:** 
- As imagens são salvas no diretório interno da aplicação (`app_Documents`)
- Dependendo do dispositivo e versão Android, podem não aparecer imediatamente na galeria do sistema
- Para integração com galeria do Android, seria necessário usar MediaStore (implementação mais complexa)

---

## ⚙️ Configuração Necessária

### Permissões Android (já configuradas)

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

---

## 🐛 Troubleshooting

### "window.flutter_inappwebview is undefined"
- **Causa:** WebView ainda não foi completamente carregado
- **Solução:** Chamar handler apenas após `DOMContentLoaded` ou com delay

```javascript
window.addEventListener('load', () => {
  // Chamar handlers aqui
  window.flutter_inappwebview.callHandler('requestPhotosPermission');
});
```

### "Permissão negada"
- **Causa:** Usuário negou permissão no prompt do Android
- **Solução:** Verificar status de permissão antes de usar câmera

### "Erro ao salvar: Dados inválidos"
- **Causa:** Formato de base64 inválido ou objeto sem `base64` property
- **Solução:** Garantir que está passando string base64 válida e nome do arquivo (opcional)

---

## 📝 Resumo dos Handlers

| Handler | Função | Entrada | Saída |
|---------|--------|---------|-------|
| `saveImageToGallery` | Salva imagem em base64 | `{base64, name?}` | `{success, message, path?}` |
| `requestPhotosPermission` | Solicita permissão | `[]` | `{granted, status}` |

---

## 🚀 Próximos Passos

1. Integrar handlers em componentes React que usam câmera
2. Testar captura de imagem real
3. Verificar localização dos arquivos salvos
4. (Opcional) Implementar MediaStore para visibilidade em galeria do sistema

---

Versão: 1.0  
Data: Março 2026  
App: MariaMaia v1.0 (Flutter + React Web)
