import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize InAppWebView platform
  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MariaMaiaApp());
}

class MariaMaiaApp extends StatelessWidget {
  const MariaMaiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de Pecuária Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Splash Screen
// ──────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    debugPrint('=== Inicialização do app ===');
    await _requestPermissions();
    final webDir = await _copyWebAssets();

    debugPrint('Permissões solicitadas. Diretório web: $webDir');

    // Exemplo de log para fluxo da câmera
    debugPrint('Verificando permissões da câmera...');
    final cameraStatus = await Permission.camera.status;
    debugPrint(
      'Status da câmera: ${cameraStatus.isGranted ? 'Permitida' : 'Negada'}',
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WebViewScreen(webDirectory: webDir)),
      );
    }
  }

  Future<void> _requestPermissions() async {
    debugPrint('Solicitando permissões: câmera, fotos, localização...');
    await [
      Permission.camera,
      Permission.photos,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();
  }

  /// Salva um arquivo JSON no diretório de Downloads
  Future<String> saveJsonToDownloads(
    String fileName,
    String jsonContent,
  ) async {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) {
      debugPrint('✗ Não foi possível acessar o diretório de Downloads');
      throw Exception('Não foi possível acessar o diretório de Downloads');
    }
    final filePath = '${downloadsDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsString(jsonContent);
    debugPrint('✓ JSON salvo em: $filePath');
    return filePath;
  }

  /// Copies all web assets from Flutter assets to the app's documents directory.
  /// Uses a hardcoded list of files (from the Vite build output).
  Future<String> _copyWebAssets() async {
    final docDir = await getApplicationDocumentsDirectory();
    final wwwDir = Directory('${docDir.path}/www');

    debugPrint('=== Asset Copy Process Started ===');
    debugPrint('Application Documents Directory: ${docDir.path}');
    debugPrint('Target Web Directory: ${wwwDir.path}');

    // Always refresh to get latest version
    if (await wwwDir.exists()) {
      debugPrint('Removing existing www directory');
      await wwwDir.delete(recursive: true);
    }
    await wwwDir.create(recursive: true);
    debugPrint('Created www directory');

    // Create assets subdirectory
    final assetsSubDir = Directory('${wwwDir.path}/assets');
    await assetsSubDir.create(recursive: true);
    debugPrint('Created assets subdirectory');

    // List of files to copy (matches the Vite build output)
    final filesToCopy = [
      'assets/www/index.html',
      'assets/www/assets/index-7IFXiKKL.js',
      'assets/www/assets/web-aGpJbohV.js',
      'assets/www/assets/web-BAU6XU0Q.js',
      'assets/www/assets/web-BoCc4yw8.js',
    ];

    int successCount = 0;
    int failureCount = 0;

    for (final assetPath in filesToCopy) {
      try {
        debugPrint('Attempting to load: $assetPath');
        final data = await rootBundle.load(assetPath);

        // Remove the 'assets/www/' prefix to get the relative path
        final relativePath = assetPath.replaceFirst('assets/www/', '');
        final targetFile = File('${wwwDir.path}/$relativePath');

        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );

        final fileSize = await targetFile.length();
        debugPrint(
          '✓ Copied: $assetPath -> ${targetFile.path} ($fileSize bytes)',
        );
        successCount++;
      } catch (e) {
        debugPrint('✗ Error copying asset $assetPath: $e');
        failureCount++;
      }
    }

    debugPrint('=== Asset Copy Summary ===');
    debugPrint('Successfully copied: $successCount files');
    debugPrint('Failed to copy: $failureCount files');
    debugPrint('Web directory contents:');

    // List all files in the www directory for verification
    try {
      final files = wwwDir.listSync(recursive: true, followLinks: false);
      for (final file in files) {
        if (file is File) {
          debugPrint('  - ${file.path}');
        }
      }
    } catch (e) {
      debugPrint('Error listing files: $e');
    }

    return wwwDir.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.agriculture_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'MariaMaia',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gestor de Pecuária Pro',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// WebView Screen – uses InAppWebView with InAppLocalhostServer
// ──────────────────────────────────────────────────────────────────────
class WebViewScreen extends StatefulWidget {
  final String webDirectory;
  const WebViewScreen({super.key, required this.webDirectory});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  static const MethodChannel _galleryChannel = MethodChannel(
    'com.mariamaia.maria_maia/gallery',
  );

  final Map<String, StringBuffer> _jsonChunkBuffers = {};
  final Map<String, String> _jsonChunkFileNames = {};

  InAppWebViewController? _webViewController;
  late InAppLocalhostServer _localhostServer;
  bool _serverReady = false;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      debugPrint('=== Starting InAppLocalhostServer ===');
      debugPrint('Web Directory: ${widget.webDirectory}');

      // Verify directory exists and check contents
      final webDir = Directory(widget.webDirectory);
      if (!await webDir.exists()) {
        throw Exception('Web directory does not exist: ${widget.webDirectory}');
      }

      final files = webDir.listSync(recursive: true, followLinks: false);
      debugPrint('Files in web directory (${files.length} total):');
      for (final file in files) {
        if (file is File) {
          final relative = file.path.replaceFirst(widget.webDirectory, '');
          debugPrint('  - $relative');
        }
      }

      // InAppLocalhostServer serves assets directly from Flutter's bundled
      // assets (flutter_assets/...). It does NOT reliably serve files from
      // the app's documents directory.
      //
      // The web assets are included in the Flutter asset bundle under:
      //   assets/www/
      // so we point the server at that path.
      _localhostServer = InAppLocalhostServer(
        documentRoot: 'assets/www',
        port: 8899,
      );

      debugPrint('Starting localhost server on http://localhost:8899');
      await _localhostServer.start();
      debugPrint('✓ Localhost server started successfully');

      if (mounted) {
        setState(() => _serverReady = true);
      }
    } catch (e) {
      debugPrint('✗ Error starting localhost server: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Server Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _localhostServer.close();
    super.dispose();
  }

  /// Verifica se uma URL possui um scheme customizado que deve ser aberto
  /// com um aplicativo externo (ex: whatsapp://, tel://, mailto://)
  bool _isCustomSchemeUrl(Uri? uri) {
    if (uri == null) return false;

    final customSchemes = [
      'whatsapp',
      'tel',
      'mailto',
      'sms',
      'intent',
      'geo',
      'market',
    ];

    return customSchemes.contains(uri.scheme);
  }

  /// Abre uma URL customizada com o aplicativo correspondente
  Future<void> _launchCustomUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);

      // Tratamento especial para WhatsApp Web que usa http/https
      if (urlString.contains('whatsapp.com')) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch WhatsApp Web: $urlString');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('WhatsApp não está disponível')),
            );
          }
        }
        return;
      }

      // Para schemes customizados (whatsapp://, tel://, etc.)
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('Opened custom scheme: $urlString');
      } else {
        debugPrint('Could not launch custom scheme: $urlString');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não é possível abrir: $urlString')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao abrir: $e')));
      }
    }
  }

  /// Registra handlers JavaScript para comunicação com a aplicação web
  void _registerJavaScriptHandlers(InAppWebViewController controller) {
    // Handler para salvar imagem em base64 para a galeria
    controller.addJavaScriptHandler(
      handlerName: 'saveImageToGallery',
      callback: (args) async {
        if (args.isEmpty) {
          debugPrint('saveImageToGallery: nenhum dado recebido');
          return {'success': false, 'message': 'Nenhum dado recebido'};
        }
        final imageData = args[0]; // Esperado: { base64: '...', name: '...' }
        return await _saveImageFromBase64(imageData);
      },
    );

    // Handler para solicitar permissoes
    controller.addJavaScriptHandler(
      handlerName: 'requestPhotosPermission',
      callback: (args) async {
        final status = await Permission.photos.request();
        return {'granted': status.isGranted, 'status': status.toString()};
      },
    );

    // Handler para salvar JSON de planejamento em Documents
    controller.addJavaScriptHandler(
      handlerName: 'saveJsonToDocuments',
      callback: (args) async {
        if (args.isEmpty) {
          debugPrint('saveJsonToDocuments: nenhum dado recebido');
          return {'success': false, 'message': 'Nenhum dado recebido'};
        }
        final jsonData =
            args[0]; // Esperado: { jsonContent: '...', fileName: '...' }
        return await _saveJsonFromWeb(jsonData);
      },
    );

    // Handlers para envio chunked de JSON grande (evita limite de payload)
    controller.addJavaScriptHandler(
      handlerName: 'saveJsonStart',
      callback: (args) async {
        if (args.isEmpty || args[0] is! Map) {
          return {'success': false, 'message': 'Dados inválidos'};
        }
        final data = args[0] as Map;
        final sessionId = (data['sessionId'] ?? '').toString();
        final fileName = (data['fileName'] ?? '').toString();

        if (sessionId.isEmpty) {
          return {'success': false, 'message': 'sessionId ausente'};
        }

        _jsonChunkBuffers[sessionId] = StringBuffer();
        _jsonChunkFileNames[sessionId] = fileName;
        debugPrint('saveJsonStart: session=$sessionId file=$fileName');
        return {'success': true};
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'saveJsonChunk',
      callback: (args) async {
        if (args.isEmpty || args[0] is! Map) {
          return {'success': false, 'message': 'Dados inválidos'};
        }
        final data = args[0] as Map;
        final sessionId = (data['sessionId'] ?? '').toString();
        final chunk = (data['chunk'] ?? '').toString();

        final buffer = _jsonChunkBuffers[sessionId];
        if (sessionId.isEmpty || buffer == null) {
          return {'success': false, 'message': 'Sessão inexistente'};
        }

        buffer.write(chunk);
        return {'success': true};
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'saveJsonFinish',
      callback: (args) async {
        if (args.isEmpty || args[0] is! Map) {
          return {'success': false, 'message': 'Dados inválidos'};
        }
        final data = args[0] as Map;
        final sessionId = (data['sessionId'] ?? '').toString();
        final buffer = _jsonChunkBuffers.remove(sessionId);
        final fileName = _jsonChunkFileNames.remove(sessionId);

        if (sessionId.isEmpty || buffer == null) {
          return {'success': false, 'message': 'Sessão inexistente'};
        }

        debugPrint('saveJsonFinish: session=$sessionId bytes=${buffer.length}');

        return await _saveJsonFromWeb({
          'jsonContent': buffer.toString(),
          'fileName': fileName,
        });
      },
    );
  }

  /// Salva uma imagem em base64 para a galeria do dispositivo
  Future<Map<String, dynamic>> _saveImageFromBase64(dynamic imageData) async {
    try {
      if (imageData is! Map) {
        return {'success': false, 'message': 'Dados inválidos'};
      }

      final base64String = imageData['base64'] as String?;
      final fileName =
          imageData['name'] as String? ??
          'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (base64String == null || base64String.isEmpty) {
        return {'success': false, 'message': 'String base64 vazia'};
      }

      debugPrint('Salvando imagem: $fileName');

      // Decodifica a string base64 para bytes
      final imageBytes = base64Decode(base64String);

      if (Platform.isAndroid) {
        final result = await _galleryChannel
            .invokeMethod<Map<dynamic, dynamic>>('saveImageToGallery', {
              'bytes': imageBytes,
              'fileName': fileName,
            });

        final success = result?['success'] == true;
        final savedPath = (result?['path'] ?? '').toString();

        if (!success) {
          debugPrint('Falha ao salvar na galeria (Android): $result');
          return {
            'success': false,
            'message': (result?['message'] ?? 'Falha ao salvar na galeria')
                .toString(),
            'result': result,
          };
        }

        debugPrint('Imagem salva com sucesso na galeria: $savedPath');

        return {
          'success': true,
          'message': 'Imagem salva com sucesso na galeria',
          'path': savedPath,
          'result': result,
        };
      }

      // Fallback for non-Android platforms.
      final appDocDir = await getApplicationDocumentsDirectory();
      final picturesPath = '${appDocDir.path}/Pictures';
      final picturesDir = Directory(picturesPath);
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }
      final filePath = '$picturesPath/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      debugPrint('Imagem salva em fallback local: $filePath');

      return {
        'success': true,
        'message': 'Imagem salva com sucesso',
        'path': filePath,
      };
    } catch (e) {
      debugPrint('Erro ao salvar imagem: $e');
      return {'success': false, 'message': 'Erro ao salvar: $e'};
    }
  }

  /// Salva o JSON exportado da web app em Documents no Android
  Future<Map<String, dynamic>> _saveJsonFromWeb(dynamic jsonData) async {
    try {
      if (jsonData is! Map) {
        return {'success': false, 'message': 'Dados inválidos'};
      }

      final jsonContent = jsonData['jsonContent'] as String?;
      var fileName =
          jsonData['fileName'] as String? ??
          'plano-nutricional-${DateTime.now().millisecondsSinceEpoch}.json';

      if (jsonContent == null || jsonContent.isEmpty) {
        return {'success': false, 'message': 'Conteúdo JSON vazio'};
      }

      if (!fileName.toLowerCase().endsWith('.json')) {
        fileName = '$fileName.json';
      }

      if (Platform.isAndroid) {
        final result = await _galleryChannel
            .invokeMethod<Map<dynamic, dynamic>>('saveJsonToDocuments', {
              'jsonContent': jsonContent,
              'fileName': fileName,
            });

        final success = result?['success'] == true;
        final savedPath = (result?['path'] ?? '').toString();

        if (!success) {
          debugPrint('Falha ao salvar JSON (Android): $result');
          return {
            'success': false,
            'message': (result?['message'] ?? 'Falha ao salvar JSON')
                .toString(),
            'result': result,
          };
        }

        debugPrint('JSON salvo com sucesso: $savedPath');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('JSON salvo em: $savedPath'),
              duration: const Duration(seconds: 5),
            ),
          );
        }

        return {
          'success': true,
          'message': 'JSON salvo com sucesso',
          'path': savedPath,
          'result': result,
        };
      }

      // Fallback para outras plataformas
      final appDocDir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${appDocDir.path}/Exports');
      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }
      final filePath = '${exportsDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('JSON salvo em: $filePath'),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      return {
        'success': true,
        'message': 'JSON salvo com sucesso',
        'path': filePath,
      };
    } catch (e) {
      debugPrint('Erro ao salvar JSON: $e');
      return {'success': false, 'message': 'Erro ao salvar JSON: $e'};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_serverReady) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_webViewController != null) {
          final canGoBack = await _webViewController!.canGoBack();
          if (canGoBack) {
            _webViewController!.goBack();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('http://localhost:8899/index.html'),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              supportZoom: false,
              geolocationEnabled: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              transparentBackground: false,
              allowContentAccess: true,
              allowFileAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              userAgent: 'MariaMaia/1.0 (Flutter; Mobile)',
              cacheMode: CacheMode.LOAD_DEFAULT,
              useWideViewPort: true,
              loadWithOverviewMode: true,
              textZoom: 100,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              debugPrint('WebView created successfully');
              _registerJavaScriptHandlers(controller);
            },
            onPermissionRequest: (controller, request) async {
              debugPrint('Permission request: ${request.resources}');
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            onGeolocationPermissionsShowPrompt: (controller, origin) async {
              debugPrint('Geolocation permission requested for: $origin');
              return GeolocationPermissionShowPromptResponse(
                origin: origin,
                allow: true,
                retain: true,
              );
            },
            onLoadStart: (controller, url) {
              debugPrint('WebView load started: $url');
            },
            onLoadStop: (controller, url) async {
              debugPrint('WebView load completed: $url');
              // PhotoBridge v3: intercept FileReader.prototype.readAsDataURL.
              // React reads every picked/captured image through FileReader – by
              // patching the prototype we get the base64 data at the same time
              // React does, with zero dependency on DOM change events.
              await controller.evaluateJavascript(
                source: r'''
(function() {
  if (window._photoBridgeInstalled) return;
  window._photoBridgeInstalled = true;
  var PB_VERBOSE = false;

  function pbLog(msg) {
    if (PB_VERBOSE) console.log(msg);
  }

  // 1. Intercept FileReader so we piggyback on React's own read
  var _origRead = FileReader.prototype.readAsDataURL;
  FileReader.prototype.readAsDataURL = function(blob) {
    if (blob && blob.type && blob.type.startsWith('image/')) {
      var self = this;
      var fileName = (blob && blob.name) ? blob.name : ('photo_' + Date.now() + '.jpg');
      self.addEventListener('load', function onPBLoad() {
        self.removeEventListener('load', onPBLoad);
        var raw = self.result;
        var b64 = (raw && raw.indexOf(',') >= 0) ? raw.split(',')[1] : raw;
        if (!b64) return;
        var kb = Math.round(b64.length * 0.75 / 1024);
        pbLog('[PhotoBridge] intercepted: ' + fileName + ' (' + kb + ' KB)');
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview
            .callHandler('saveImageToGallery', {base64: b64, name: fileName})
            .then(function(r){ pbLog('[PhotoBridge] OK: ' + JSON.stringify(r)); })
            .catch(function(e){ console.error('[PhotoBridge] Erro:', e); });
        } else {
          console.warn('[PhotoBridge] flutter_inappwebview nao encontrado');
        }
      });
    }
    return _origRead.call(this, blob);
  };

  // 2. Patch file inputs without forcing capture.
  // For Samsung/Android WebView, capture="environment" frequently returns
  // empty FileList. Keeping chooser mode improves reliability.
  function patchInputs() {
    document.querySelectorAll('input[type="file"]').forEach(function(el) {
      if (el.hasAttribute('capture')) el.removeAttribute('capture');
    });
  }
  patchInputs();
  new MutationObserver(patchInputs)
    .observe(document.documentElement, {childList:true, subtree:true});

  // 3. Debug helper
  window.PhotoBridgeDebug = {
    version: '3.1',
    setVerbose: function(enabled) {
      PB_VERBOSE = !!enabled;
      console.log('[PhotoBridge] verbose=' + PB_VERBOSE);
      return PB_VERBOSE;
    },
    status: function() {
      var all = document.querySelectorAll('input[type="file"]');
      var ok = !!(window.flutter_inappwebview);
      console.log('=== PhotoBridge Status ===\nVersion: 3.1 (FileReader intercept, chooser mode)\nInputs: '+all.length+'\nFlutter: '+(ok?'AVAILABLE':'NOT FOUND')+'\n=========================');
      return {version:'3.1', inputs:all.length, flutterReady:ok};
    },
    testCapture: function() {
      var el = document.querySelector('input[type="file"]');
      if (!el) { console.warn('[PhotoBridge] Nenhum input. Va para a tela de camera primeiro.'); return false; }
      pbLog('[PhotoBridge] testCapture -> click()'); el.click(); return true;
    }
  };
})();

(function() {
  if (window._jsonBridgeInstalled) return;
  window._jsonBridgeInstalled = true;
  console.log('[JsonBridge] installed');

  var JSON_CHUNK_SIZE = 180000;

  function sendJsonChunked(jsonText, fileName) {
    var sessionId = 'json_' + Date.now() + '_' + Math.random().toString(36).slice(2);
    var total = Math.ceil(jsonText.length / JSON_CHUNK_SIZE);

    // Chunked approach: Fire all chunks in PARALLEL for maximum speed
    return window.flutter_inappwebview.callHandler('saveJsonStart', {
      sessionId: sessionId,
      fileName: fileName,
      totalChunks: total
    }).then(function(startRes) {
      if (!startRes || startRes.success !== true) {
        throw new Error((startRes && startRes.message) ? startRes.message : 'Falha ao iniciar sessao JSON');
      }

      // Create all chunk calls at once
      var chunkCalls = [];
      for (var i = 0; i < total; i++) {
        var begin = i * JSON_CHUNK_SIZE;
        var end = Math.min(begin + JSON_CHUNK_SIZE, jsonText.length);
        var chunk = jsonText.slice(begin, end);
        
        chunkCalls.push(
          window.flutter_inappwebview.callHandler('saveJsonChunk', {
            sessionId: sessionId,
            chunk: chunk,
            index: i,
            total: total
          }).then(function(chunkRes) {
            if (!chunkRes || chunkRes.success !== true) {
              throw new Error((chunkRes && chunkRes.message) ? chunkRes.message : 'Falha no chunk ' + i);
            }
          })
        );
      }

      // Send ALL chunks in parallel, wait for all to complete
      console.log('[JsonBridge] Sending ' + total + ' chunks in parallel');
      return Promise.all(chunkCalls).then(function() {
        console.log('[JsonBridge] All chunks sent, finishing...');
        return window.flutter_inappwebview.callHandler('saveJsonFinish', {
          sessionId: sessionId
        });
      });
    });
  }

  function sendJsonToFlutter(jsonText, fileName) {
    if (!jsonText || !window.flutter_inappwebview) {
      return Promise.reject(new Error('Bridge indisponivel para salvar JSON'));
    }

    var finalFileName = fileName || ('plano-nutricional-' + Date.now() + '.json');
    return sendJsonChunked(jsonText, finalFileName);
  }

  // Source-level fallback: capture planning JSON at creation time.
  // This bypasses dependency on navigator.share/Capacitor/blob click behavior.
  try {
    if (!window._mmJsonStringifyPatched) {
      window._mmJsonStringifyPatched = true;
      var originalStringify = JSON.stringify;
      var lastPayloadSignature = '';

      JSON.stringify = function(value, replacer, space) {
        var result = originalStringify.apply(JSON, arguments);
        try {
          var looksLikePlanningPayload =
            value &&
            typeof value === 'object' &&
            Array.isArray(value.PLANEJAMENTO) &&
            Array.isArray(value.LOTES_SELECIONADOS) &&
            Array.isArray(value.LOCAIS);

          if (looksLikePlanningPayload && typeof result === 'string' && result.length > 10) {
            var signature = String(result.length) + ':' + result.slice(0, 80);
            if (signature !== lastPayloadSignature) {
              lastPayloadSignature = signature;

              var planningId = null;
              try {
                for (var i = 0; i < value.PLANEJAMENTO.length; i++) {
                  var row = value.PLANEJAMENTO[i];
                  if (row && row.TAG === 'ID_PLANEJAMENTO') {
                    planningId = row.RESPOSTA;
                    break;
                  }
                }
              } catch (_) {}

              var fileName = planningId
                ? ('plano-nutricional-' + planningId + '.json')
                : ('plano-nutricional-' + Date.now() + '.json');

              console.log('[JsonBridge] planning payload captured via JSON.stringify:', fileName, 'bytes=' + result.length);
              sendJsonToFlutter(result, fileName).catch(function(err) {
                console.error('[JsonBridge] stringify fallback failed:', err);
              });
            }
          }
        } catch (err) {
          console.error('[JsonBridge] erro no hook JSON.stringify:', err);
        }
        return result;
      };
      console.log('[JsonBridge] JSON.stringify patched');
    }
  } catch (err) {
    console.error('[JsonBridge] patch JSON.stringify falhou:', err);
  }

  function patchNavigatorShare() {
    try {
      if (!(navigator && typeof navigator.share === 'function')) {
        return false;
      }
      if (navigator._mmSharePatched) {
        return true;
      }

      var originalShare = navigator.share.bind(navigator);
      navigator.share = function(shareData) {
        try {
          var files = shareData && shareData.files;
          if (files && files.length) {
            for (var i = 0; i < files.length; i++) {
              var file = files[i];
              var name = file && file.name ? String(file.name) : '';
              var type = file && file.type ? String(file.type).toLowerCase() : '';
              var isJson = name.toLowerCase().endsWith('.json') || type.indexOf('application/json') >= 0;
              if (isJson && typeof file.text === 'function') {
                console.log('[JsonBridge] navigator.share JSON file intercepted:', name || '<sem_nome>');
                return file.text().then(function(text) {
                  return sendJsonToFlutter(text, name);
                }).then(function() {
                  return originalShare(shareData);
                }).catch(function(err) {
                  console.error('[JsonBridge] navigator.share intercept falhou:', err);
                  return originalShare(shareData);
                });
              }
            }
          }
        } catch (err) {
          console.error('[JsonBridge] erro no patch navigator.share:', err);
        }
        return originalShare(shareData);
      };
      navigator._mmSharePatched = true;
      console.log('[JsonBridge] navigator.share patched');
      return true;
    } catch (err) {
      console.error('[JsonBridge] patch navigator.share falhou:', err);
      return false;
    }
  }

  function patchCapacitorNativePromise() {
    try {
      var cap = window.Capacitor;
      if (!(cap && typeof cap.nativePromise === 'function')) {
        return false;
      }
      if (cap._mmNativePromisePatched) {
        return true;
      }

      var originalNativePromise = cap.nativePromise.bind(cap);
      cap.nativePromise = function(pluginName, methodName, options) {
        var resultPromise = originalNativePromise(pluginName, methodName, options);

        try {
          if (pluginName === 'Filesystem' && methodName === 'writeFile') {
            var path = (options && options.path ? String(options.path) : '');
            var data = options && options.data;
            var isJsonPath = path.toLowerCase().endsWith('.json');
            var isStringData = typeof data === 'string';
            var trimmed = isStringData ? data.trim() : '';
            var looksLikeJson = isStringData && (trimmed.startsWith('{') || trimmed.startsWith('['));

            console.log('[JsonBridge] Filesystem.writeFile observed:', path || '<sem_path>');

            if (isJsonPath && looksLikeJson) {
              sendJsonToFlutter(data, path)
                .then(function(r) {
                  if (!r || r.success !== true) {
                    throw new Error((r && r.message) ? r.message : 'Falha ao salvar JSON');
                  }
                  console.log('[JsonBridge] JSON salvo em Documents:', r.path || r.message);
                })
                .catch(function(err) {
                  console.error('[JsonBridge] falha ao salvar JSON (nativePromise):', err);
                });
            }
          }
        } catch (err) {
          console.error('[JsonBridge] erro ao processar nativePromise:', err);
        }

        return resultPromise;
      };
      cap._mmNativePromisePatched = true;
      console.log('[JsonBridge] Capacitor.nativePromise patched');
      return true;
    } catch (err) {
      console.error('[JsonBridge] patch nativePromise falhou:', err);
      return false;
    }
  }

  var patchAttempts = 0;
  var patchTimer = setInterval(function() {
    patchAttempts += 1;
    var shareReady = patchNavigatorShare();
    var nativeReady = patchCapacitorNativePromise();

    if (patchAttempts === 1 || patchAttempts % 5 === 0) {
      console.log('[JsonBridge] patch status attempt=' + patchAttempts + ' share=' + shareReady + ' native=' + nativeReady + ' hasCap=' + (!!window.Capacitor));
    }

    if (shareReady && nativeReady) {
      clearInterval(patchTimer);
      console.log('[JsonBridge] all patches active');
    }

    if (patchAttempts >= 40) {
      clearInterval(patchTimer);
      console.warn('[JsonBridge] patch timeout share=' + shareReady + ' native=' + nativeReady + ' hasCap=' + (!!window.Capacitor));
    }
  }, 250);

  // 2) Intercept blob downloads fallback (web behavior)
  if (!window.URL || !window.URL.createObjectURL || !window.URL.revokeObjectURL) {
    return;
  }

  var originalCreateObjectURL = window.URL.createObjectURL.bind(window.URL);
  var originalRevokeObjectURL = window.URL.revokeObjectURL.bind(window.URL);
  var blobRegistry = {};

  window.URL.createObjectURL = function(obj) {
    var url = originalCreateObjectURL(obj);
    try {
      if (obj instanceof Blob) {
        blobRegistry[url] = obj;
      }
    } catch (_) {}
    return url;
  };

  window.URL.revokeObjectURL = function(url) {
    delete blobRegistry[url];
    return originalRevokeObjectURL(url);
  };

  document.addEventListener('click', function(event) {
    var anchor = event.target && event.target.closest ? event.target.closest('a[download]') : null;
    if (!anchor) return;

    if (anchor.dataset.mmJsonBridgeBypass === '1') {
      anchor.dataset.mmJsonBridgeBypass = '0';
      return;
    }

    var href = anchor.getAttribute('href') || '';
    var downloadName = (anchor.getAttribute('download') || '').trim();
    var isBlobDownload = href.indexOf('blob:') === 0;
    var isJsonName = downloadName.toLowerCase().endsWith('.json');

    if (!isBlobDownload && !isJsonName) return;

    var blob = blobRegistry[href];
    if (!blob) return;

    var blobType = (blob.type || '').toLowerCase();
    if (!blobType.includes('application/json') && !isJsonName) return;

    event.preventDefault();

    blob.text().then(function(jsonText) {
      var fileName = downloadName || ('plano-nutricional-' + Date.now() + '.json');
      return sendJsonToFlutter(jsonText, fileName);
    }).then(function(response) {
      if (!response || response.success !== true) {
        throw new Error((response && response.message) ? response.message : 'Falha ao salvar JSON');
      }
      console.log('[JsonBridge] JSON salvo com sucesso:', response.path || response.message);
    }).catch(function(error) {
      console.error('[JsonBridge] erro ao salvar JSON no dispositivo:', error);
      // Reexecuta o fluxo original de download como fallback.
      anchor.dataset.mmJsonBridgeBypass = '1';
      try {
        anchor.click();
      } catch (_) {}
    });
  }, true);
})();
              ''',
              );
            },
            onConsoleMessage: (controller, consoleMessage) {
              debugPrint('WebView Console: ${consoleMessage.message}');
            },
            onReceivedError: (controller, request, error) {
              debugPrint(
                'WebView Error: ${error.type} - ${error.description}\nURL: ${request.url}',
              );
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;
              debugPrint('Navigation request: $uri');

              // Ignorar data: URLs e blob: URLs (internas)
              if (uri?.scheme == 'data' || uri?.scheme == 'blob') {
                return NavigationActionPolicy.ALLOW;
              }

              // Interceptar schemes customizados (whatsapp://, tel://, mailto://, etc.)
              if (_isCustomSchemeUrl(uri)) {
                debugPrint('Custom scheme detected: ${uri?.scheme}');
                await _launchCustomUrl(uri.toString());
                return NavigationActionPolicy.CANCEL;
              }

              // Permitir navegação normal (http, https, localhost)
              return NavigationActionPolicy.ALLOW;
            },
          ),
        ),
      ),
    );
  }
}
