import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    await _requestPermissions();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WebViewScreen()),
      );
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();
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
// WebView Screen
// ──────────────────────────────────────────────────────────────────────
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  static const MethodChannel _galleryChannel = MethodChannel(
    'br.com.monitore.app/gallery',
  );

  final Map<String, StringBuffer> _jsonChunkBuffers = {};
  final Map<String, String> _jsonChunkFileNames = {};
  // filename.toLowerCase() → path in media_archive temp dir
  final Map<String, String> _mediaCachePaths = {};

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
      _localhostServer = InAppLocalhostServer(
        documentRoot: 'assets/www',
        port: 8899,
      );
      await _localhostServer.start();
      if (mounted) setState(() => _serverReady = true);
    } catch (e) {
      debugPrint('✗ Error starting localhost server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _localhostServer.close();
    super.dispose();
  }

  // ── JavaScript handlers ──────────────────────────────────────────────

  void _registerJavaScriptHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'saveImageToGallery',
      callback: (args) async {
        if (args.isEmpty) return {'success': false, 'message': 'Nenhum dado recebido'};
        return await _saveImageFromBase64(args[0]);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'requestPhotosPermission',
      callback: (args) async {
        final status = await Permission.photos.request();
        return {'granted': status.isGranted, 'status': status.toString()};
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'saveJsonToDocuments',
      callback: (args) async {
        if (args.isEmpty) return {'success': false, 'message': 'Nenhum dado recebido'};
        return await _saveJsonFromWeb(args[0]);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'saveJsonStart',
      callback: (args) async {
        if (args.isEmpty || args[0] is! Map) return {'success': false, 'message': 'Dados inválidos'};
        final data = args[0] as Map;
        final sessionId = (data['sessionId'] ?? '').toString();
        final fileName = (data['fileName'] ?? '').toString();
        if (sessionId.isEmpty) return {'success': false, 'message': 'sessionId ausente'};
        _jsonChunkBuffers[sessionId] = StringBuffer();
        _jsonChunkFileNames[sessionId] = fileName;
        return {'success': true};
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'saveJsonChunk',
      callback: (args) async {
        if (args.isEmpty || args[0] is! Map) return {'success': false, 'message': 'Dados inválidos'};
        final data = args[0] as Map;
        final sessionId = (data['sessionId'] ?? '').toString();
        final chunk = (data['chunk'] ?? '').toString();
        final buffer = _jsonChunkBuffers[sessionId];
        if (sessionId.isEmpty || buffer == null) return {'success': false, 'message': 'Sessão inexistente'};
        buffer.write(chunk);
        return {'success': true};
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'saveJsonFinish',
      callback: (args) async {
        if (args.isEmpty || args[0] is! Map) return {'success': false, 'message': 'Dados inválidos'};
        final data = args[0] as Map;
        final sessionId = (data['sessionId'] ?? '').toString();
        final buffer = _jsonChunkBuffers.remove(sessionId);
        final fileName = _jsonChunkFileNames.remove(sessionId);
        if (sessionId.isEmpty || buffer == null) return {'success': false, 'message': 'Sessão inexistente'};
        return await _saveJsonFromWeb({'jsonContent': buffer.toString(), 'fileName': fileName});
      },
    );

    // Intercepts camera <input capture> clicks from JS — uses image_picker which
    // avoids flutter_inappwebview's broken process-death camera flow.
    controller.addJavaScriptHandler(
      handlerName: 'capturePhotoNative',
      callback: (args) async {
        try {
          final picker = ImagePicker();
          final photo = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
            maxWidth: 1280,
          );
          if (photo == null) return {'success': false, 'cancelled': true};

          final bytes = await photo.readAsBytes();
          final fileName = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';

          final cacheDir = await getTemporaryDirectory();
          final archiveDir = Directory('${cacheDir.path}/media_archive');
          if (!await archiveDir.exists()) await archiveDir.create(recursive: true);
          final archiveFile = File('${archiveDir.path}/$fileName');
          await archiveFile.writeAsBytes(bytes);
          _mediaCachePaths[fileName.toLowerCase()] = archiveFile.path;

          if (Platform.isAndroid) {
            try {
              await _galleryChannel.invokeMethod(
                'saveImageFromFile',
                {'filePath': archiveFile.path, 'fileName': fileName},
              );
            } catch (e) {
              debugPrint('[capturePhotoNative] gallery save failed: $e');
            }
          }

          return {
            'success': true,
            'base64': base64Encode(bytes),
            'name': fileName,
            'mimeType': 'image/jpeg',
          };
        } catch (e) {
          debugPrint('[capturePhotoNative] error: $e');
          return {'success': false, 'message': e.toString()};
        }
      },
    );
  }

  // ── Image save ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _saveImageFromBase64(dynamic imageData) async {
    try {
      if (imageData is! Map) return {'success': false, 'message': 'Dados inválidos'};
      final base64String = imageData['base64'] as String?;
      final fileName = imageData['name'] as String? ?? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (base64String == null || base64String.isEmpty) return {'success': false, 'message': 'String base64 vazia'};

      final imageBytes = base64Decode(base64String);

      // Save to temp archive first — also avoids passing large bytes through
      // the Binder IPC (~1 MB limit) which causes TransactionTooLargeException.
      final cacheDir = await getTemporaryDirectory();
      final archiveDir = Directory('${cacheDir.path}/media_archive');
      if (!await archiveDir.exists()) await archiveDir.create(recursive: true);
      final archiveFile = File('${archiveDir.path}/$fileName');
      await archiveFile.writeAsBytes(imageBytes);
      _mediaCachePaths[fileName.toLowerCase()] = archiveFile.path;

      if (Platform.isAndroid) {
        // Pass file path, not bytes — avoids Binder TransactionTooLargeException
        // for large images (camera photos can be 8-15 MB raw).
        final result = await _galleryChannel.invokeMethod<Map<dynamic, dynamic>>(
          'saveImageFromFile',
          {'filePath': archiveFile.path, 'fileName': fileName},
        );
        final success = result?['success'] == true;
        if (!success) return {'success': false, 'message': (result?['message'] ?? 'Falha ao salvar na galeria').toString()};
        return {'success': true, 'message': 'Imagem salva na galeria', 'path': (result?['path'] ?? '').toString()};
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final picturesDir = Directory('${appDocDir.path}/Pictures');
      if (!await picturesDir.exists()) await picturesDir.create(recursive: true);
      final file = File('${picturesDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);
      return {'success': true, 'message': 'Imagem salva', 'path': file.path};
    } catch (e) {
      debugPrint('Erro ao salvar imagem: $e');
      return {'success': false, 'message': 'Erro ao salvar: $e'};
    }
  }

  // ── JSON save + WhatsApp share ────────────────────────────────────────

  Future<Map<String, dynamic>> _saveJsonFromWeb(dynamic jsonData) async {
    try {
      if (jsonData is! Map) return {'success': false, 'message': 'Dados inválidos'};
      final jsonContent = jsonData['jsonContent'] as String?;
      var fileName = jsonData['fileName'] as String? ?? 'planejamento-${DateTime.now().millisecondsSinceEpoch}.json';
      if (jsonContent == null || jsonContent.isEmpty) return {'success': false, 'message': 'Conteúdo JSON vazio'};

      if (!fileName.toLowerCase().endsWith('.json')) fileName = '$fileName.json';

      final processed = _sanitizeJsonAndExtractMedia(jsonContent);
      final sanitizedJson = (processed['jsonContent'] ?? jsonContent).toString();
      final mediaFiles = (processed['mediaFiles'] as List<Map<String, String>>?) ?? [];

      if (Platform.isAndroid) {
        final result = await _galleryChannel.invokeMethod<Map<dynamic, dynamic>>(
          'saveJsonToDocuments',
          {'jsonContent': sanitizedJson, 'fileName': fileName},
        );
        final success = result?['success'] == true;
        if (!success) {
          return {'success': false, 'message': (result?['message'] ?? 'Falha ao salvar JSON').toString()};
        }
        await _sharePlanFilesOnWhatsApp(
          fileName: fileName,
          sanitizedJsonContent: sanitizedJson,
          mediaFiles: mediaFiles,
        );
        return {'success': true, 'message': 'JSON salvo', 'path': (result?['path'] ?? '').toString()};
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${appDocDir.path}/Exports');
      if (!await exportsDir.exists()) await exportsDir.create(recursive: true);
      final file = File('${exportsDir.path}/$fileName');
      await file.writeAsString(sanitizedJson);
      return {'success': true, 'message': 'JSON salvo', 'path': file.path};
    } catch (e) {
      debugPrint('Erro ao salvar JSON: $e');
      return {'success': false, 'message': 'Erro ao salvar JSON: $e'};
    }
  }

  Map<String, dynamic> _sanitizeJsonAndExtractMedia(String jsonContent) {
    try {
      final decoded = jsonDecode(jsonContent);
      final mediaFiles = <Map<String, String>>[];

      dynamic sanitizeNode(dynamic node) {
        if (node is List) return node.map(sanitizeNode).toList();
        if (node is Map) {
          final mutable = <String, dynamic>{};
          node.forEach((k, v) => mutable[k.toString()] = v);

          final tag = (mutable['TAG'] ?? '').toString();
          if (tag == 'DADOS_MIDIA' && mutable['RESPOSTA'] is List) {
            final resposta = mutable['RESPOSTA'] as List;
            final sanitizedResposta = <Map<String, String>>[];
            for (final item in resposta) {
              if (item is Map) {
                final name = (item['nome'] ?? '').toString();
                final mime = (item['tipo'] ?? '').toString().isNotEmpty
                    ? (item['tipo'] ?? '').toString()
                    : _guessMime(name);
                final content = (item['conteudo'] ?? '').toString();
                final localPath = (item['localPath'] ?? item['path'] ?? item['filePath'] ?? '').toString();
                if (name.isNotEmpty && (content.isNotEmpty || localPath.isNotEmpty)) {
                  mediaFiles.add({'fileName': name, 'mimeType': mime, 'base64': content, 'localPath': localPath});
                }
                sanitizedResposta.add({'nome': name, 'tipo': mime});
              }
            }
            mutable['RESPOSTA'] = sanitizedResposta;
            return mutable;
          }

          final output = <String, dynamic>{};
          mutable.forEach((k, v) => output[k] = sanitizeNode(v));
          return output;
        }
        return node;
      }

      return {'jsonContent': jsonEncode(sanitizeNode(decoded)), 'mediaFiles': mediaFiles};
    } catch (e) {
      debugPrint('Falha ao sanitizar JSON: $e');
      return {'jsonContent': jsonContent, 'mediaFiles': <Map<String, String>>[]};
    }
  }

  String _guessMime(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }

  String _sanitizeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), '_').trim();
    return cleaned.isEmpty ? 'arquivo.bin' : cleaned;
  }

  File? _findGalleryMedia({required Map<String, File> galleryByName, required String preferredName}) {
    if (preferredName.isEmpty) return null;
    final exact = galleryByName[preferredName.toLowerCase()];
    if (exact != null) return exact;
    final stem = preferredName.contains('.')
        ? preferredName.substring(0, preferredName.lastIndexOf('.'))
        : preferredName;
    final lowerStem = stem.toLowerCase();
    for (final entry in galleryByName.entries) {
      if (entry.key == lowerStem || entry.key.startsWith('$lowerStem.')) return entry.value;
    }
    return null;
  }

  Future<void> _sharePlanFilesOnWhatsApp({
    required String fileName,
    required String sanitizedJsonContent,
    required List<Map<String, String>> mediaFiles,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final cacheDir = await getTemporaryDirectory();
      final shareDir = Directory('${cacheDir.path}/share_temp');
      if (await shareDir.exists()) await shareDir.delete(recursive: true);
      await shareDir.create(recursive: true);

      final filePaths = <String>[];

      // Write JSON
      final jsonFile = File('${shareDir.path}/$fileName');
      await jsonFile.writeAsString(sanitizedJsonContent);
      filePaths.add(jsonFile.path);

      // Build gallery index as fallback
      final galleryDir = Directory('/storage/emulated/0/Pictures/Monitore');
      final galleryByName = <String, File>{};
      if (await galleryDir.exists()) {
        await for (final entity in galleryDir.list(followLinks: false)) {
          if (entity is File) {
            final name = entity.uri.pathSegments.last;
            galleryByName[name.toLowerCase()] = entity;
          }
        }
      }

      // Prepare media files — cascading fallbacks so ZIP is always populated.
      final preparedFiles = <File>[];
      final seenPaths = <String>{};

      // When the JS bridge omits `conteudo` (at.data.split(",")[1] → undefined),
      // mediaFiles arrives empty. Fall back to everything saved in media_archive
      // during this session (photo capture/selection always archives there).
      var effectiveMediaFiles = mediaFiles;
      if (effectiveMediaFiles.isEmpty && _mediaCachePaths.isNotEmpty) {
        debugPrint('[Share] mediaFiles empty — using ${_mediaCachePaths.length} archived images');
        effectiveMediaFiles = _mediaCachePaths.entries.map((e) {
          final archiveName = e.value.split('/').last;
          return {
            'fileName': archiveName,
            'mimeType': _guessMime(archiveName),
            'base64': '',
            'localPath': e.value,
          };
        }).toList();
      }

      for (var i = 0; i < effectiveMediaFiles.length; i++) {
        final media = effectiveMediaFiles[i];
        final origName = media['fileName']?.isNotEmpty == true ? media['fileName']! : 'midia_${i + 1}.bin';
        final safeName = _sanitizeFileName(origName);
        final b64 = media['base64'] ?? '';
        final localPath = media['localPath'] ?? '';
        var prepared = false;

        debugPrint('[Share] media[$i]: $safeName  b64=${b64.length}chars  localPath=$localPath');

        // 1. Explicit local path (set by a future bridge extension)
        if (!prepared && localPath.isNotEmpty) {
          try {
            final src = File(localPath);
            if (await src.exists() && !seenPaths.contains(src.path)) {
              final copy = File('${shareDir.path}/$safeName');
              await src.copy(copy.path);
              preparedFiles.add(copy);
              seenPaths.add(src.path);
              prepared = true;
            }
          } catch (e) {
            debugPrint('[Share] localPath failed: $e');
          }
        }

        // 2. Media archive — bytes saved the moment the image was captured/selected.
        //    This is the most reliable source and avoids JSON base64 round-trip issues.
        if (!prepared) {
          final cached = _mediaCachePaths[origName.toLowerCase()] ??
              _mediaCachePaths[safeName.toLowerCase()];
          if (cached != null) {
            try {
              final cachedFile = File(cached);
              if (await cachedFile.exists() && !seenPaths.contains(cachedFile.path)) {
                final copy = File('${shareDir.path}/$safeName');
                await cachedFile.copy(copy.path);
                preparedFiles.add(copy);
                seenPaths.add(cachedFile.path);
                prepared = true;
                debugPrint('[Share] Used media_archive for $safeName');
              }
            } catch (e) {
              debugPrint('[Share] media_archive failed: $e');
            }
          }
        }

        // 3. Base64 from JSON (may be absent when conteudo is missing or chunking issue)
        if (!prepared && b64.isNotEmpty) {
          try {
            final cleanB64 = b64.contains(',') ? b64.split(',').last : b64;
            final bytes = base64Decode(cleanB64);
            final mediaFile = File('${shareDir.path}/$safeName');
            await mediaFile.writeAsBytes(bytes);
            preparedFiles.add(mediaFile);
            prepared = true;
          } catch (e) {
            debugPrint('[Share] base64Decode failed for $safeName: $e');
          }
        }

        // 4. Gallery directory scan (may fail on Android 10+ due to scoped storage)
        if (!prepared) {
          try {
            final fromGallery = _findGalleryMedia(galleryByName: galleryByName, preferredName: safeName);
            if (fromGallery != null && await fromGallery.exists() && !seenPaths.contains(fromGallery.path)) {
              final copy = File('${shareDir.path}/$safeName');
              await fromGallery.copy(copy.path);
              preparedFiles.add(copy);
              seenPaths.add(fromGallery.path);
              prepared = true;
            }
          } catch (e) {
            debugPrint('[Share] gallery scan failed: $e');
          }
        }

        if (!prepared) {
          debugPrint('[Share] WARN: could not prepare $safeName from any source');
        }
      }

      // Create ZIP if there are media files
      if (preparedFiles.isNotEmpty) {
        final zipName = '${fileName.replaceAll(RegExp(r'\.json$'), '')}_midias.zip';
        final zipPath = '${shareDir.path}/$zipName';
        final encoder = ZipFileEncoder();
        encoder.create(zipPath);
        for (final f in preparedFiles) { encoder.addFile(f); }
        encoder.close();
        filePaths.add(zipPath);
      }

      await _galleryChannel.invokeMethod<Map<dynamic, dynamic>>(
        'shareFilesViaFileProvider',
        {'filePaths': filePaths, 'text': 'Planejamento: $fileName'},
      );
    } catch (e) {
      debugPrint('Erro ao compartilhar no WhatsApp: $e');
    }
  }

  // ── URL helpers ──────────────────────────────────────────────────────

  bool _isCustomSchemeUrl(Uri? uri) {
    if (uri == null) return false;
    return ['whatsapp', 'tel', 'mailto', 'sms', 'intent', 'geo', 'market'].contains(uri.scheme);
  }

  Future<void> _launchCustomUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (urlString.contains('whatsapp.com')) {
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não é possível abrir: $urlString')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

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
          if (canGoBack) _webViewController!.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('http://127.0.0.1:8899/index.html'),
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
              _registerJavaScriptHandlers(controller);
            },
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            onGeolocationPermissionsShowPrompt: (controller, origin) async {
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
              await controller.evaluateJavascript(source: _photoBridgeJs + _jsonBridgeJs);
            },
            onConsoleMessage: (controller, consoleMessage) {
              debugPrint('WebView Console: ${consoleMessage.message}');
            },
            onReceivedError: (controller, request, error) {
              debugPrint('WebView Error: ${error.type} - ${error.description}\nURL: ${request.url}');
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;

              if (uri?.scheme == 'data' || uri?.scheme == 'blob') {
                return NavigationActionPolicy.ALLOW;
              }

              // Block wa.me — Flutter bridge handles WhatsApp file sharing
              final host = uri?.host ?? '';
              if (host.contains('wa.me') || host.contains('api.whatsapp.com')) {
                return NavigationActionPolicy.CANCEL;
              }

              if (_isCustomSchemeUrl(uri)) {
                await _launchCustomUrl(uri.toString());
                return NavigationActionPolicy.CANCEL;
              }

              return NavigationActionPolicy.ALLOW;
            },
          ),
        ),
      ),
    );
  }
}

// ── Injected JavaScript ───────────────────────────────────────────────

const String _photoBridgeJs = r'''
(function() {
  if (window._photoBridgeInstalled) return;
  window._photoBridgeInstalled = true;

  function _isImageFile(blob) {
    var type = blob ? (blob.type || '') : '';
    var name = blob ? (blob.name || '') : '';
    return type.startsWith('image/') ||
      /\.(jpg|jpeg|png|webp|gif|bmp|heic|heif)$/i.test(name);
  }

  function _saveToGallery(b64, fileName) {
    if (!b64 || !window.flutter_inappwebview) return;
    window.flutter_inappwebview
      .callHandler('saveImageToGallery', {base64: b64, name: fileName})
      .catch(function(e) { console.error('[PhotoBridge] save error:', e); });
  }

  // 1. Intercept FileReader.readAsDataURL (covers gallery files)
  var _origRead = FileReader.prototype.readAsDataURL;
  FileReader.prototype.readAsDataURL = function(blob) {
    if (_isImageFile(blob)) {
      var self = this;
      var fileName = (blob && blob.name) ? blob.name : ('photo_' + Date.now() + '.jpg');
      // Skip gallery save for photos already handled by capturePhotoNative
      var alreadySaved = !!(window._mmSaved && window._mmSaved[fileName]);
      self.addEventListener('load', function onPBLoad() {
        self.removeEventListener('load', onPBLoad);
        if (alreadySaved) return;
        try {
          var raw = self.result;
          var b64 = (raw && raw.indexOf(',') >= 0) ? raw.split(',')[1] : raw;
          _saveToGallery(b64, fileName);
        } catch(e) { console.error('[PhotoBridge] load handler error:', e); }
      });
    }
    return _origRead.call(this, blob);
  };

  // 2. Intercept camera input clicks — bypass flutter_inappwebview's file chooser
  //    (broken on process death) and use Flutter image_picker instead.
  document.addEventListener('click', function(e) {
    var t = e.target;
    if (!t || t.tagName !== 'INPUT' || t.type !== 'file') return;
    if (!t.hasAttribute('capture')) return;
    if (t._mmProcessing) return;
    e.preventDefault();
    e.stopImmediatePropagation();
    t._mmProcessing = true;
    if (!window.flutter_inappwebview) { t._mmProcessing = false; return; }
    window.flutter_inappwebview.callHandler('capturePhotoNative', {})
      .then(function(result) {
        t._mmProcessing = false;
        if (!result || result.cancelled) return;
        if (!result.success || !result.base64) {
          console.error('[PhotoBridge] capturePhotoNative failed:', result && result.message);
          return;
        }
        // Mark as saved so the readAsDataURL override above won't double-save
        window._mmSaved = window._mmSaved || {};
        window._mmSaved[result.name] = true;
        // Build a synthetic File and inject it into the input via DataTransfer
        var byteStr = atob(result.base64);
        var ab = new ArrayBuffer(byteStr.length);
        var ia = new Uint8Array(ab);
        for (var i = 0; i < byteStr.length; i++) ia[i] = byteStr.charCodeAt(i);
        var blob = new Blob([ab], {type: result.mimeType || 'image/jpeg'});
        var file = new File([blob], result.name, {type: result.mimeType || 'image/jpeg'});
        try {
          var dt = new DataTransfer();
          dt.items.add(file);
          t.files = dt.files;
        } catch(dtErr) {
          console.error('[PhotoBridge] DataTransfer inject failed:', dtErr);
        }
        t.dispatchEvent(new Event('change', {bubbles: true}));
      })
      .catch(function(err) {
        t._mmProcessing = false;
        console.error('[PhotoBridge] capturePhotoNative error:', err);
      });
  }, true);

  // 3. Prevent unhandled promise rejections from crashing the React app
  window.addEventListener('unhandledrejection', function(event) {
    console.warn('[PhotoBridge] Unhandled rejection caught:', event.reason);
    event.preventDefault();
  });
})();
''';

const String _jsonBridgeJs = r'''
(function() {
  if (window._jsonBridgeInstalled) return;
  window._jsonBridgeInstalled = true;

  var CHUNK_SIZE = 180000;
  var _jsonSaveLock = false;
  var _lastJsonSig = '';

  function sendJsonChunked(jsonText, fileName) {
    var sessionId = 'json_' + Date.now() + '_' + Math.random().toString(36).slice(2);
    var total = Math.ceil(jsonText.length / CHUNK_SIZE);
    return window.flutter_inappwebview.callHandler('saveJsonStart', {
      sessionId: sessionId, fileName: fileName, totalChunks: total
    }).then(function(res) {
      if (!res || res.success !== true) throw new Error(res && res.message ? res.message : 'Falha ao iniciar');
      // Send chunks SEQUENTIALLY to preserve order (parallel was corrupting large JSONs)
      var seq = Promise.resolve();
      for (var i = 0; i < total; i++) {
        (function(idx) {
          var begin = idx * CHUNK_SIZE;
          seq = seq.then(function() {
            return window.flutter_inappwebview.callHandler('saveJsonChunk', {
              sessionId: sessionId,
              chunk: jsonText.slice(begin, Math.min(begin + CHUNK_SIZE, jsonText.length)),
              index: idx, total: total
            });
          });
        })(i);
      }
      return seq.then(function() {
        return window.flutter_inappwebview.callHandler('saveJsonFinish', {sessionId: sessionId});
      });
    });
  }

  function sendJsonToFlutter(jsonText, fileName) {
    if (!jsonText || !window.flutter_inappwebview) return Promise.reject(new Error('Bridge indisponível'));
    var sig = String(jsonText.length) + ':' + jsonText.slice(0, 60);
    if (_jsonSaveLock || sig === _lastJsonSig) {
      console.log('[JsonBridge] Skipped duplicate JSON save (lock=' + _jsonSaveLock + ')');
      return Promise.resolve(null);
    }
    _lastJsonSig = sig;
    _jsonSaveLock = true;
    var unlock = function() { setTimeout(function() { _jsonSaveLock = false; }, 8000); };
    return sendJsonChunked(jsonText, fileName || ('planejamento-' + Date.now() + '.json'))
      .then(function(r) { unlock(); return r; }, function(e) { unlock(); throw e; });
  }

  // Intercept JSON.stringify for planning payloads
  if (!window._mmJsonStringifyPatched) {
    window._mmJsonStringifyPatched = true;
    var _origStringify = JSON.stringify;
    var _lastSig = '';
    JSON.stringify = function(value, replacer, space) {
      var result = _origStringify.apply(JSON, arguments);
      try {
        if (value && typeof value === 'object' &&
            Array.isArray(value.PLANEJAMENTO) &&
            Array.isArray(value.LOTES_SELECIONADOS) &&
            Array.isArray(value.LOCAIS) &&
            typeof result === 'string' && result.length > 10) {
          var sig = result.length + ':' + result.slice(0, 80);
          if (sig !== _lastSig) {
            _lastSig = sig;
            // Debug: log media info so we can see if conteudo is present
            try {
              var mediaCnt = 0;
              if (Array.isArray(value.LOCAIS)) {
                value.LOCAIS.forEach(function(loc) {
                  if (!Array.isArray(loc)) return;
                  loc.forEach(function(item) {
                    if (item && item.TAG === 'DADOS_MIDIA' && Array.isArray(item.RESPOSTA)) {
                      item.RESPOSTA.forEach(function(m) {
                        mediaCnt++;
                        console.log('[JsonBridge] media: nome=' + (m.nome||'?') +
                          ' tipo=' + (m.tipo||'?') +
                          ' conteudo=' + (m.conteudo ? m.conteudo.length + 'chars' : 'MISSING'));
                      });
                    }
                  });
                });
              }
              console.log('[JsonBridge] Total media items: ' + mediaCnt + '  JSON size: ' + result.length);
            } catch(_) {}
            var planId = null;
            try {
              for (var i = 0; i < value.PLANEJAMENTO.length; i++) {
                if (value.PLANEJAMENTO[i] && value.PLANEJAMENTO[i].TAG === 'ID_PLANEJAMENTO') {
                  planId = value.PLANEJAMENTO[i].RESPOSTA;
                  break;
                }
              }
            } catch(_) {}
            var fName = planId ? ('plano-nutricional-' + planId + '.json') : ('planejamento-' + Date.now() + '.json');
            sendJsonToFlutter(result, fName).catch(function(e) {
              console.error('[JsonBridge] stringify hook failed:', e);
            });
          }
        }
      } catch(e) { console.error('[JsonBridge] stringify hook error:', e); }
      return result;
    };
  }

  // Intercept navigator.share for JSON files
  if (navigator && typeof navigator.share === 'function' && !navigator._mmSharePatched) {
    var _origShare = navigator.share.bind(navigator);
    navigator.share = function(shareData) {
      try {
        var files = shareData && shareData.files;
        if (files && files.length) {
          for (var i = 0; i < files.length; i++) {
            var file = files[i];
            var name = file && file.name ? String(file.name) : '';
            if ((name.toLowerCase().endsWith('.json') || (file.type || '').indexOf('application/json') >= 0) &&
                typeof file.text === 'function') {
              return file.text().then(function(text) {
                return sendJsonToFlutter(text, name);
              }).catch(function(e) {
                console.error('[JsonBridge] share intercept failed:', e);
                return _origShare(shareData);
              });
            }
          }
        }
      } catch(e) { console.error('[JsonBridge] share hook error:', e); }
      return _origShare(shareData);
    };
    navigator._mmSharePatched = true;
  }

  // Suppress window.open for WhatsApp URLs (Flutter bridge handles file sharing)
  var _origOpen = window.open;
  window.open = function(url, target, features) {
    if (url && (String(url).includes('wa.me') || String(url).includes('api.whatsapp.com'))) {
      console.log('[JsonBridge] Suppressed window.open WhatsApp URL - handled by Flutter bridge');
      return null;
    }
    return _origOpen ? _origOpen.apply(this, arguments) : null;
  };

  // Suppress React's blocking completion alert — it fires BEFORE the Promise chain resolves
  // which prevents saveJsonFinish from completing and blocks _sharePlanFilesOnWhatsApp.
  var _origAlert = window.alert;
  window.alert = function(msg) {
    var s = String(msg || '');
    if (s.includes('RELATÓRIO PRONTO') || s.includes('RELATÓRIO') ||
        (s.includes('arquivo') && s.includes('WhatsApp'))) {
      console.log('[JsonBridge] Suppressed blocking alert - Flutter bridge handles sharing');
      return;
    }
    return _origAlert ? _origAlert.apply(this, arguments) : undefined;
  };

  // Intercept blob download links
  if (window.URL && window.URL.createObjectURL) {
    var _origCreateURL = window.URL.createObjectURL.bind(window.URL);
    var _origRevokeURL = window.URL.revokeObjectURL.bind(window.URL);
    var _blobRegistry = {};
    window.URL.createObjectURL = function(obj) {
      var url = _origCreateURL(obj);
      try { if (obj instanceof Blob) _blobRegistry[url] = obj; } catch(_) {}
      return url;
    };
    window.URL.revokeObjectURL = function(url) {
      delete _blobRegistry[url];
      return _origRevokeURL(url);
    };
    document.addEventListener('click', function(event) {
      var anchor = event.target && event.target.closest ? event.target.closest('a[download]') : null;
      if (!anchor) return;
      if (anchor.dataset.mmBypass === '1') { anchor.dataset.mmBypass = '0'; return; }
      var href = anchor.getAttribute('href') || '';
      var downloadName = (anchor.getAttribute('download') || '').trim();
      if (href.indexOf('blob:') !== 0 && !downloadName.toLowerCase().endsWith('.json')) return;
      var blob = _blobRegistry[href];
      if (!blob) return;
      if (!(blob.type || '').includes('application/json') && !downloadName.toLowerCase().endsWith('.json')) return;
      event.preventDefault();
      blob.text().then(function(text) {
        return sendJsonToFlutter(text, downloadName || ('planejamento-' + Date.now() + '.json'));
      }).then(function(res) {
        if (!res || res.success !== true) throw new Error(res && res.message ? res.message : 'Falha');
        console.log('[JsonBridge] JSON salvo:', res.path || res.message);
      }).catch(function(e) {
        console.error('[JsonBridge] blob download intercept failed:', e);
        anchor.dataset.mmBypass = '1';
        try { anchor.click(); } catch(_) {}
      });
    }, true);
  }
})();
''';
