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
            onLoadStop: (controller, url) {
              debugPrint('WebView load completed: $url');
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
