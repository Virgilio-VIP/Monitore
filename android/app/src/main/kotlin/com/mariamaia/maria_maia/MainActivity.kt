package com.mariamaia.maria_maia

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
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

					else -> result.notImplemented()
				}
			}
	}
}

