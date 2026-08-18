import 'dart:async';
import 'package:fllama/fllama.dart';
import 'llama_model_manager.dart';

class LlamaChatService {
  final LlamaModelManager _modelManager = LlamaModelManager();

  /// Ek message bhejta hai aur bot ka poora reply return karta hai.
  /// onToken callback se tumhe reply "type hote hue" bhi mil sakta hai (streaming).
  Future<String> sendMessage(
    String userMessage, {
    void Function(String partialResponse)? onToken,
  }) async {
    final modelPath = await _modelManager.getModelPath();

    final request = OpenAiRequest(
      maxTokens: 256,
      messages: [
        Message(Role.system, 'You are a helpful, friendly assistant.'),
        Message(Role.user, userMessage),
      ],
      numGpuLayers: 0,
      modelPath: modelPath,
      mmprojPath: null,
      frequencyPenalty: 0.0,
      presencePenalty: 1.1,
      topP: 1.0,
      contextSize: 1024,
      temperature: 0.3,
    );

    final completer = Completer<String>();

    fllamaChat(request, (response, responseJson, done) {
      // 'response' hamesha ABHI TAK ka POORA reply hota hai
      onToken?.call(response);
      if (done && !completer.isCompleted) {
        completer.complete(response);
      }
    });

    return completer.future;
  }
}