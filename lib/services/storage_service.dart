import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucket = 'chat-media';

  // File upload karo → public URL wapas milega
  Future<String?> uploadFile({
    required File file,
    required String folder, // "images", "voice", "docs"
  }) async {
    try {
      // Unique file name (timestamp + original name)
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final path = '$folder/$fileName';

      // Upload
      await _supabase.storage.from(_bucket).upload(path, file);

      // Public URL lo
      final url = _supabase.storage.from(_bucket).getPublicUrl(path);
      return url;
    } catch(e) {
  print('Supabase upload error: $e'); // error terminal mein dikhega
  return null;
  }
  }
}