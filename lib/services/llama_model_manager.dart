import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class LlamaModelManager {
  // Model ka download URL — LLaMA 3.2 1B, Q4_K_M quantized (~808MB)
  static const String modelUrl =
      'https://huggingface.co/hugging-quants/Llama-3.2-1B-Instruct-Q4_K_M-GGUF/resolve/main/llama-3.2-1b-instruct-q4_k_m.gguf';
  static const String modelFileName = 'llama-3.2-1b-instruct-q4_k_m.gguf';

  /// Phone ke andar model file kahan save hogi, uska poora path deta hai
  Future<String> getModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$modelFileName';
  }

  /// Check karta hai ke model pehle se download ho chuki hai ya nahi
  Future<bool> isModelDownloaded() async {
    final path = await getModelPath();
    return File(path).exists();
  }

  /// Model ko internet se download karke phone mein save karta hai.
  /// onProgress callback ke through 0.0 se 1.0 tak progress milta hai.
  Future<void> downloadModel({
    required void Function(double progress) onProgress,
  }) async {
    final path = await getModelPath();
    final file = File(path);

    final request = http.Request('GET', Uri.parse(modelUrl));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('Download fail hua: ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? 0;
    int received = 0;
    final sink = file.openWrite();

    await response.stream.listen((chunk) {
      sink.add(chunk);
      received += chunk.length;
      if (contentLength > 0) {
        onProgress(received / contentLength);
      }
    }).asFuture();

    await sink.close();
  }
}