// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse(
    'http://localhost:8080/v1/projects/demo-project/databases/(default)/documents/products',
  );

  for (final token in ['owner', 'admin', 'ya29.c.mock', 'Bearer owner']) {
    final res = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    print('Token: $token -> ${res.statusCode}');
    if (res.statusCode != 200) {
      print('   ${res.body}');
    }
  }
}
