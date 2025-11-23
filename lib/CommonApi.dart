
import 'package:http/http.dart' as http;
class CommonApi {
  void listModels(String apiKey) async {
    var errorMessage;
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models?key=$apiKey',
      );
      final res = await http.get(uri);

      // show the raw listModels response so you can pick a supported model
      errorMessage = 'ListModels response: ${res.statusCode}\n${res.body}';

    } catch (e) {

      errorMessage = 'Failed to call ListModels: $e';

    }

    print(errorMessage);
  }
}