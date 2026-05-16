import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  String baseUrl;

  ApiService({this.baseUrl = 'http://127.0.0.1:8000'});

  void setPort(int port) {
    baseUrl = 'http://127.0.0.1:$port';
  }

  Future<Map<String, dynamic>> health() async {
    final res = await http.get(Uri.parse('$baseUrl/health'));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> loadModel({
    required String modelPath,
    String precision = 'fp16',
    bool vramOptimization = false,
    bool cpuOffload = false,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/model/load'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model_path': modelPath,
        'precision': precision,
        'vram_optimization': vramOptimization,
        'cpu_offload': cpuOffload,
      }),
    ).timeout(const Duration(minutes: 5));
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['detail']);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> txt2img(Map<String, dynamic> params) async {
    final res = await http.post(
      Uri.parse('$baseUrl/txt2img'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params),
    ).timeout(const Duration(minutes: 10));
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['detail']);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> img2img(Map<String, dynamic> params) async {
    final res = await http.post(
      Uri.parse('$baseUrl/img2img'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params),
    ).timeout(const Duration(minutes: 10));
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['detail']);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> inpaint(Map<String, dynamic> params) async {
    final res = await http.post(
      Uri.parse('$baseUrl/inpaint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params),
    ).timeout(const Duration(minutes: 10));
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['detail']);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getProgress() async {
    final res = await http.get(Uri.parse('$baseUrl/generate/progress'));
    return jsonDecode(res.body);
  }

  Future<void> cancelGeneration() async {
    await http.post(Uri.parse('$baseUrl/generate/cancel'));
  }

  Future<List<String>> getBaseModels() async {
    final res = await http.get(Uri.parse('$baseUrl/models/base'));
    final data = jsonDecode(res.body);
    return List<String>.from(data['models']);
  }

  Future<List<String>> getLoraList() async {
    final res = await http.get(Uri.parse('$baseUrl/lora/list'));
    final data = jsonDecode(res.body);
    return List<String>.from(data['loras']);
  }

  Future<String> startLoraTrain(Map<String, dynamic> params) async {
    final res = await http.post(
      Uri.parse('$baseUrl/lora/train'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params),
    );
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['detail']);
    return jsonDecode(res.body)['job_id'];
  }

  Future<Map<String, dynamic>> getLoraStatus(String jobId) async {
    final res = await http.get(Uri.parse('$baseUrl/lora/status/$jobId'));
    return jsonDecode(res.body);
  }

  Future<List<Map<String, dynamic>>> getPresets() async {
    final res = await http.get(Uri.parse('$baseUrl/presets'));
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['presets']);
  }

  Future<String> savePreset(Map<String, dynamic> preset) async {
    final res = await http.post(
      Uri.parse('$baseUrl/presets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(preset),
    );
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['detail']);
    return jsonDecode(res.body)['id'];
  }

  Future<void> deletePreset(String id) async {
    await http.delete(Uri.parse('$baseUrl/presets/$id'));
  }

  Future<Map<String, dynamic>> getConfig() async {
    final res = await http.get(Uri.parse('$baseUrl/config'));
    return jsonDecode(res.body);
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    await http.put(
      Uri.parse('$baseUrl/config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(config),
    );
  }
}

final api = ApiService();
