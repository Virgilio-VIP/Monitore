package br.com.monitore.app

import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.widget.Toast
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.OutputStream

class MainActivity : FlutterActivity() {
	private val CHANNEL = "br.com.monitore.app/gallery"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"saveImageToGallery" -> {
						try {
							val bytes = call.argument<ByteArray>("bytes")
							val fileNameArg = call.argument<String>("fileName")
							if (bytes == null || bytes.isEmpty()) {
								result.success(mapOf("success" to false, "message" to "Bytes da imagem vazios"))
								return@setMethodCallHandler
							}
							val fileName = if (fileNameArg.isNullOrBlank()) {
								"photo_${System.currentTimeMillis()}.jpg"
							} else {
								fileNameArg
							}
							result.success(saveImageBytesToGallery(bytes, fileName))
						} catch (e: Exception) {
							result.success(mapOf("success" to false, "message" to "Erro ao salvar imagem: ${e.message}"))
						}
					}

					"saveImageFromFile" -> {
						try {
							val filePath = call.argument<String>("filePath")
							val fileNameArg = call.argument<String>("fileName")
							if (filePath.isNullOrBlank()) {
								result.success(mapOf("success" to false, "message" to "Caminho do arquivo vazio"))
								return@setMethodCallHandler
							}
							val sourceFile = File(filePath)
							if (!sourceFile.exists()) {
								result.success(mapOf("success" to false, "message" to "Arquivo não encontrado: $filePath"))
								return@setMethodCallHandler
							}
							val fileName = if (fileNameArg.isNullOrBlank()) sourceFile.name else fileNameArg
							result.success(saveImageBytesToGallery(sourceFile.readBytes(), fileName))
						} catch (e: Exception) {
							result.success(mapOf("success" to false, "message" to "Erro ao salvar imagem: ${e.message}"))
						}
					}

					"saveJsonToDocuments" -> {
						try {
							val jsonContent = call.argument<String>("jsonContent")
							val fileNameArg = call.argument<String>("fileName")
							if (jsonContent.isNullOrBlank()) {
								result.success(mapOf("success" to false, "message" to "Conteudo JSON vazio"))
								return@setMethodCallHandler
							}
							val fileName = if (fileNameArg.isNullOrBlank()) {
								"planejamento_${System.currentTimeMillis()}.json"
							} else {
								if (fileNameArg.lowercase().endsWith(".json")) fileNameArg else "$fileNameArg.json"
							}
							result.success(saveJsonToDocuments(jsonContent, fileName))
						} catch (e: Exception) {
							result.success(mapOf("success" to false, "message" to "Erro ao salvar JSON: ${e.message}"))
						}
					}

					"shareFilesViaFileProvider" -> {
						try {
							val filePaths = call.argument<List<String>>("filePaths") ?: emptyList()
							val text = call.argument<String>("text")
							result.success(shareFilesViaFileProvider(filePaths, text))
						} catch (e: Exception) {
							result.success(mapOf("success" to false, "message" to "Erro ao compartilhar: ${e.message}"))
						}
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun saveImageBytesToGallery(bytes: ByteArray, fileName: String): Map<String, Any> {
		val values = ContentValues().apply {
			put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
			put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Monitore")
				put(MediaStore.Images.Media.IS_PENDING, 1)
			}
		}
		val resolver = applicationContext.contentResolver
		val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
			?: return mapOf("success" to false, "message" to "Falha ao criar entrada no MediaStore")
		var outputStream: OutputStream? = null
		try {
			outputStream = resolver.openOutputStream(uri)
				?: return mapOf("success" to false, "message" to "Falha ao abrir stream no MediaStore")
			outputStream.write(bytes)
			outputStream.flush()
		} finally {
			outputStream?.close()
		}
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val publishValues = ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
			resolver.update(uri, publishValues, null, null)
		}
		return mapOf("success" to true, "path" to uri.toString(), "message" to "Imagem salva com sucesso")
	}

	private fun saveJsonToDocuments(jsonContent: String, fileName: String): Map<String, Any> {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val values = ContentValues().apply {
				put(MediaStore.Files.FileColumns.DISPLAY_NAME, fileName)
				put(MediaStore.Files.FileColumns.MIME_TYPE, "application/json")
				put(MediaStore.Files.FileColumns.RELATIVE_PATH, "Documents/monitore")
				put(MediaStore.Files.FileColumns.IS_PENDING, 1)
			}
			val resolver = applicationContext.contentResolver
			val uri = resolver.insert(MediaStore.Files.getContentUri("external"), values)
				?: return mapOf("success" to false, "message" to "Falha ao criar entrada em Documents/monitore")

			var outputStream: OutputStream? = null
			try {
				outputStream = resolver.openOutputStream(uri)
					?: return mapOf("success" to false, "message" to "Falha ao abrir stream do arquivo")
				outputStream.write(jsonContent.toByteArray(Charsets.UTF_8))
				outputStream.flush()
			} finally {
				outputStream?.close()
			}
			val publishValues = ContentValues().apply {
				put(MediaStore.Files.FileColumns.IS_PENDING, 0)
			}
			resolver.update(uri, publishValues, null, null)
			runOnUiThread {
				Toast.makeText(this, "Planejamento salvo em Documents/monitore", Toast.LENGTH_LONG).show()
			}
			return mapOf("success" to true, "path" to "Documents/monitore/$fileName", "uri" to uri.toString())
		}

		val documentsRoot = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
		val targetDir = File(documentsRoot, "monitore")
		if (!targetDir.exists() && !targetDir.mkdirs()) {
			return mapOf("success" to false, "message" to "Nao foi possivel criar Documents/monitore")
		}
		val outFile = File(targetDir, fileName)
		outFile.writeText(jsonContent, Charsets.UTF_8)
		runOnUiThread {
			Toast.makeText(this, "Planejamento salvo em Documents/monitore", Toast.LENGTH_LONG).show()
		}
		return mapOf("success" to true, "path" to outFile.absolutePath)
	}

	private fun shareFilesViaFileProvider(filePaths: List<String>, text: String?): Map<String, Any> {
		if (filePaths.isEmpty()) {
			return mapOf("success" to false, "message" to "Nenhum arquivo para compartilhar")
		}
		val authority = "${applicationContext.packageName}.fileprovider"
		val uris = ArrayList<Uri>()
		for (path in filePaths) {
			val file = File(path)
			if (!file.exists()) {
				android.util.Log.w("Monitore", "shareFilesViaFileProvider: arquivo nao encontrado: $path")
				continue
			}
			try {
				val uri = FileProvider.getUriForFile(this, authority, file)
				uris.add(uri)
			} catch (e: Exception) {
				android.util.Log.e("Monitore", "FileProvider URI falhou para $path: ${e.message}")
			}
		}
		if (uris.isEmpty()) {
			return mapOf("success" to false, "message" to "Nenhum URI valido para compartilhar")
		}
		val packageCandidates = listOf("com.whatsapp", "com.whatsapp.w4b")
		val whatsappPackage = packageCandidates.firstOrNull { isPackageInstalled(it) }
		val shareMimeType = if (uris.size == 1) {
			contentResolver.getType(uris[0]) ?: "*/*"
		} else {
			"*/*"
		}
		val uriClipData = ClipData.newUri(contentResolver, "Arquivos do planejamento", uris.first()).apply {
			for (index in 1 until uris.size) addItem(ClipData.Item(uris[index]))
		}
		val intent = if (uris.size == 1) {
			Intent(Intent.ACTION_SEND).apply {
				type = shareMimeType
				putExtra(Intent.EXTRA_STREAM, uris[0])
				clipData = uriClipData
				addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
				if (whatsappPackage != null) setPackage(whatsappPackage)
			}
		} else {
			Intent(Intent.ACTION_SEND_MULTIPLE).apply {
				type = shareMimeType
				putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
				clipData = uriClipData
				putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
				addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
				if (whatsappPackage != null) setPackage(whatsappPackage)
			}
		}
		return try {
			if (whatsappPackage != null) {
				for (uri in uris) {
					grantUriPermission(whatsappPackage, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
				}
				startActivity(intent)
			} else {
				startActivity(Intent.createChooser(intent, "Compartilhar planejamento"))
			}
			mapOf("success" to true, "message" to "Compartilhamento iniciado")
		} catch (e: Exception) {
			mapOf("success" to false, "message" to "Falha ao iniciar compartilhamento: ${e.message}")
		}
	}

	private fun isPackageInstalled(packageName: String): Boolean {
		return try {
			packageManager.getPackageInfo(packageName, 0)
			true
		} catch (_: Exception) {
			false
		}
	}
}
