package br.com.monitore.app

import android.content.ClipData
import android.content.ContentUris
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

					"listSavedPlans" -> {
						try {
							result.success(listSavedPlans())
						} catch (e: Exception) {
							result.success(emptyList<Map<String, Any>>())
						}
					}

					"readSavedPlanFile" -> {
						try {
							val fileName = call.argument<String>("fileName") ?: ""
							result.success(readSavedPlanFileContent(fileName))
						} catch (e: Exception) {
							result.success(mapOf("success" to false, "message" to "Erro: ${e.message}"))
						}
					}

					"copyGalleryMediaToTemp" -> {
						try {
							val fileNames = call.argument<List<String>>("fileNames") ?: emptyList()
							val destDir   = call.argument<String>("destDir") ?: ""
							result.success(copyGalleryMediaToTemp(fileNames, destDir))
						} catch (e: Exception) {
							result.success(emptyMap<String, String>())
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

	private fun listSavedPlans(): List<Map<String, Any>> {
		val plans = mutableListOf<Map<String, Any>>()
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val collection = MediaStore.Files.getContentUri("external")
			val projection  = arrayOf(
				MediaStore.Files.FileColumns.DISPLAY_NAME,
				MediaStore.Files.FileColumns.DATE_ADDED,
				MediaStore.Files.FileColumns.SIZE
			)
			val selection     = "(${MediaStore.Files.FileColumns.RELATIVE_PATH} = ? OR " +
				"${MediaStore.Files.FileColumns.RELATIVE_PATH} = ?) AND " +
				"${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?"
			val selectionArgs = arrayOf("Documents/monitore", "Documents/monitore/", "%.json")
			val sortOrder     = "${MediaStore.Files.FileColumns.DATE_ADDED} DESC"
			contentResolver.query(collection, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
				val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
				val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_ADDED)
				val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
				while (cursor.moveToNext()) {
					plans.add(mapOf(
						"fileName" to cursor.getString(nameCol),
						"dateMs"   to cursor.getLong(dateCol) * 1000L,
						"size"     to cursor.getLong(sizeCol)
					))
				}
			}
		} else {
			@Suppress("DEPRECATION")
			val dir = File(
				Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
				"monitore"
			)
			if (dir.exists()) {
				dir.listFiles { f -> f.name.endsWith(".json") }
					?.sortedByDescending { it.lastModified() }
					?.forEach { f ->
						plans.add(mapOf(
							"fileName" to f.name,
							"dateMs"   to f.lastModified(),
							"size"     to f.length()
						))
					}
			}
		}
		return plans
	}

	private fun readSavedPlanFileContent(fileName: String): Map<String, Any> {
		if (fileName.isBlank()) return mapOf("success" to false, "message" to "Nome vazio")
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val collection    = MediaStore.Files.getContentUri("external")
			val projection    = arrayOf(MediaStore.Files.FileColumns._ID)
			val selection     = "(${MediaStore.Files.FileColumns.RELATIVE_PATH} = ? OR " +
				"${MediaStore.Files.FileColumns.RELATIVE_PATH} = ?) AND " +
				"${MediaStore.Files.FileColumns.DISPLAY_NAME} = ?"
			val selectionArgs = arrayOf("Documents/monitore", "Documents/monitore/", fileName)
			contentResolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
				if (cursor.moveToFirst()) {
					val id  = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID))
					val uri = ContentUris.withAppendedId(collection, id)
					contentResolver.openInputStream(uri)?.use { stream ->
						return mapOf("success" to true, "content" to stream.bufferedReader(Charsets.UTF_8).readText())
					}
				}
			}
			return mapOf("success" to false, "message" to "Arquivo não encontrado: $fileName")
		} else {
			@Suppress("DEPRECATION")
			val file = File(
				Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
				"monitore/$fileName"
			)
			return if (file.exists()) {
				mapOf("success" to true, "content" to file.readText(Charsets.UTF_8))
			} else {
				mapOf("success" to false, "message" to "Arquivo não encontrado: $fileName")
			}
		}
	}

	private fun copyGalleryMediaToTemp(fileNames: List<String>, destDirPath: String): Map<String, String> {
		if (fileNames.isEmpty() || destDirPath.isBlank()) return emptyMap()
		val destDir = File(destDirPath)
		if (!destDir.exists()) destDir.mkdirs()
		val result = mutableMapOf<String, String>()
		for (name in fileNames) {
			if (name.isBlank()) continue
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				val collection    = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
				val projection    = arrayOf(MediaStore.Images.Media._ID)
				val selection     = "(${MediaStore.Images.Media.RELATIVE_PATH} = ? OR " +
					"${MediaStore.Images.Media.RELATIVE_PATH} = ?) AND " +
					"${MediaStore.Images.Media.DISPLAY_NAME} = ?"
				val selectionArgs = arrayOf("Pictures/Monitore", "Pictures/Monitore/", name)
				contentResolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
					if (cursor.moveToFirst()) {
						val id  = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
						val uri = ContentUris.withAppendedId(collection, id)
						val dst = File(destDir, name)
						try {
							contentResolver.openInputStream(uri)?.use { input ->
								dst.outputStream().use { out -> input.copyTo(out) }
								result[name] = dst.absolutePath
							}
						} catch (e: Exception) {
							android.util.Log.w("Monitore", "copyGalleryMedia failed for $name: ${e.message}")
						}
					}
				}
			} else {
				@Suppress("DEPRECATION")
				val src = File(
					Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
					"Monitore/$name"
				)
				if (src.exists()) {
					try {
						val dst = File(destDir, name)
						src.copyTo(dst, overwrite = true)
						result[name] = dst.absolutePath
					} catch (e: Exception) {
						android.util.Log.w("Monitore", "copyGalleryMedia (legacy) failed for $name: ${e.message}")
					}
				}
			}
		}
		return result
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
