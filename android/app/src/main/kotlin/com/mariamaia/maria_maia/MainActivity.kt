package com.mariamaia.maria_maia

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
	private val CHANNEL = "com.mariamaia.maria_maia/gallery"

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
								result.success(
									mapOf(
										"success" to false,
										"message" to "Bytes da imagem vazios"
									)
								)
								return@setMethodCallHandler
							}

							val fileName = if (fileNameArg.isNullOrBlank()) {
								"photo_${System.currentTimeMillis()}.jpg"
							} else {
								fileNameArg
							}

							val values = ContentValues().apply {
								put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
								put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
								if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
									put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/MariaMaia")
									put(MediaStore.Images.Media.IS_PENDING, 1)
								}
							}

							val resolver = applicationContext.contentResolver
							val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
							if (uri == null) {
								result.success(
									mapOf(
										"success" to false,
										"message" to "Falha ao criar entrada no MediaStore"
									)
								)
								return@setMethodCallHandler
							}

							var outputStream: OutputStream? = null
							try {
								outputStream = resolver.openOutputStream(uri)
								if (outputStream == null) {
									result.success(
										mapOf(
											"success" to false,
											"message" to "Falha ao abrir stream no MediaStore"
										)
									)
									return@setMethodCallHandler
								}
								outputStream.write(bytes)
								outputStream.flush()
							} finally {
								outputStream?.close()
							}

							if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
								val publishValues = ContentValues().apply {
									put(MediaStore.Images.Media.IS_PENDING, 0)
								}
								resolver.update(uri, publishValues, null, null)
							}

							result.success(
								mapOf(
									"success" to true,
									"path" to uri.toString(),
									"message" to "Imagem salva com sucesso"
								)
							)
						} catch (e: Exception) {
							result.success(
								mapOf(
									"success" to false,
									"message" to "Erro ao salvar imagem: ${e.message}"
								)
							)
						}
					}

					"saveJsonToGallery", "saveJsonToDocuments" -> {
						try {
							val jsonContent = call.argument<String>("jsonContent")
							val fileNameArg = call.argument<String>("fileName")

							if (jsonContent.isNullOrBlank()) {
								result.success(
									mapOf(
										"success" to false,
										"message" to "Conteudo JSON vazio"
									)
								)
								return@setMethodCallHandler
							}

							val fileName = if (fileNameArg.isNullOrBlank()) {
								"plano-nutricional_${System.currentTimeMillis()}.json"
							} else {
								if (fileNameArg.lowercase().endsWith(".json")) fileNameArg else "$fileNameArg.json"
							}

							result.success(saveJsonToDocuments(jsonContent, fileName))
						} catch (e: Exception) {
							result.success(
								mapOf(
									"success" to false,
									"message" to "Erro ao salvar JSON: ${e.message}"
								)
							)
						}
					}

					"shareFilesViaFileProvider" -> {
						try {
							val filePaths = call.argument<List<String>>("filePaths") ?: emptyList()
							val text = call.argument<String>("text")
							result.success(shareFilesViaFileProvider(filePaths, text))
						} catch (e: Exception) {
							result.success(
								mapOf(
									"success" to false,
									"message" to "Erro ao compartilhar: ${e.message}"
								)
							)
						}
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun saveJsonToDocuments(jsonContent: String, fileName: String): Map<String, Any> {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val values = ContentValues().apply {
				put(MediaStore.Files.FileColumns.DISPLAY_NAME, fileName)
				put(MediaStore.Files.FileColumns.MIME_TYPE, "application/json")
				put(MediaStore.Files.FileColumns.RELATIVE_PATH, "Documents/maria_maia")
				put(MediaStore.Files.FileColumns.IS_PENDING, 1)
			}

			val resolver = applicationContext.contentResolver
			val uri = resolver.insert(MediaStore.Files.getContentUri("external"), values)
				?: return mapOf(
					"success" to false,
					"message" to "Falha ao criar entrada em Documents/maria_maia"
				)

			var outputStream: OutputStream? = null
			try {
				outputStream = resolver.openOutputStream(uri)
					?: return mapOf(
						"success" to false,
						"message" to "Falha ao abrir stream do arquivo"
					)

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
				Toast.makeText(
					this,
					"JSON salvo em Documents/maria_maia",
					Toast.LENGTH_LONG
				).show()
			}

			return mapOf(
				"success" to true,
				"path" to "Documents/maria_maia/$fileName",
				"uri" to uri.toString(),
				"message" to "JSON salvo em Documents/maria_maia"
			)
		}

		val documentsRoot = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
		val targetDir = File(documentsRoot, "maria_maia")
		if (!targetDir.exists() && !targetDir.mkdirs()) {
			return mapOf(
				"success" to false,
				"message" to "Nao foi possivel criar Documents/maria_maia"
			)
		}

		val outFile = File(targetDir, fileName)
		outFile.writeText(jsonContent, Charsets.UTF_8)
		runOnUiThread {
			Toast.makeText(
				this,
				"JSON salvo em Documents/maria_maia",
				Toast.LENGTH_LONG
			).show()
		}
		return mapOf(
			"success" to true,
			"path" to outFile.absolutePath,
			"message" to "JSON salvo em Documents/maria_maia"
		)
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
				android.util.Log.w("MariaMaia", "shareFilesViaFileProvider: arquivo nao encontrado: $path")
				continue
			}
			try {
				val uri = FileProvider.getUriForFile(this, authority, file)
				uris.add(uri)
			} catch (e: Exception) {
				android.util.Log.e("MariaMaia", "FileProvider URI falhou para $path: ${e.message}")
			}
		}

		if (uris.isEmpty()) {
			return mapOf("success" to false, "message" to "Nenhum URI valido para compartilhar")
		}

		val packageCandidates = listOf("com.whatsapp", "com.whatsapp.w4b")
		val whatsappPackage = packageCandidates.firstOrNull { isPackageInstalled(it) }

		val intent = if (uris.size == 1) {
			Intent(Intent.ACTION_SEND).apply {
				type = "*/*"
				putExtra(Intent.EXTRA_STREAM, uris[0])
				if (!text.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, text)
				addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				if (whatsappPackage != null) setPackage(whatsappPackage)
			}
		} else {
			Intent(Intent.ACTION_SEND_MULTIPLE).apply {
				type = "*/*"
				putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
				if (!text.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, text)
				addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				if (whatsappPackage != null) setPackage(whatsappPackage)
			}
		}

		return try {
			if (whatsappPackage != null) {
				startActivity(intent)
			} else {
				startActivity(Intent.createChooser(intent, "Compartilhar plano"))
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

