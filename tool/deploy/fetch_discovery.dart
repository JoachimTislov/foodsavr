import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://firebaserules.googleapis.com/\$discovery/rest?version=v1'));
  final json = jsonDecode(res.body);
  print(json['schemas']['Release']);
  print(json['schemas']['UpdateReleaseRequest']);
}
