import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

void _log(String msg) => stdout.writeln(msg);

// ── Data file ──────────────────────────────────────────────────────────────

final _dataFile = File(Platform.environment['DATA_PATH'] ?? 'meetings.json');

List<dynamic> _load() {
  if (!_dataFile.existsSync()) return [];
  try {
    return jsonDecode(_dataFile.readAsStringSync()) as List<dynamic>;
  } catch (_) {
    return [];
  }
}

void _save(List<dynamic> data) =>
    _dataFile.writeAsStringSync(jsonEncode(data));

// ── Handlers ───────────────────────────────────────────────────────────────

Response _jsonOk(Object body) => Response.ok(
      jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response _badRequest(String msg) => Response(400,
    body: jsonEncode({'error': msg}),
    headers: {'content-type': 'application/json; charset=utf-8'});

Future<Response> _getMeetings(Request _) async => _jsonOk(_load());

Future<Response> _putMeetings(Request req) async {
  final body = await req.readAsString();
  dynamic parsed;
  try {
    parsed = jsonDecode(body);
  } catch (_) {
    return _badRequest('Invalid JSON');
  }
  if (parsed is! List) return _badRequest('Expected a JSON array');
  _save(parsed);
  return _jsonOk({'ok': true});
}

// ── Main ───────────────────────────────────────────────────────────────────

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;

  final router = Router()
    ..get('/api/meetings', _getMeetings)
    ..put('/api/meetings', _putMeetings)
    // Catch-all for unknown /api/* routes — prevents the static handler from
    // serving index.html for API misses (e.g. wrong method or unknown path).
    ..all('/api/<ignored|.*>', (Request _) => Response.notFound(
          '{"error":"not found"}',
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

  // Serve built Flutter web app if the directory exists
  final staticDir =
      Directory(Platform.environment['STATIC_PATH'] ?? '../build/web');
  Handler staticHandler;
  if (staticDir.existsSync()) {
    final fileHandler =
        createStaticHandler(staticDir.path, defaultDocument: 'index.html');
    // Fallback: any unmatched route serves index.html (SPA support)
    staticHandler = (Request req) async {
      final res = await fileHandler(req);
      if (res.statusCode == 404) {
        return fileHandler(Request('GET', req.requestedUri.replace(path: '/')));
      }
      return res;
    };
    _log('Serving Flutter app from: ${staticDir.absolute.path}');
  } else {
    staticHandler = (req) => Response.notFound('Static files not found. '
        'Run `flutter build web` first, or set STATIC_PATH.');
    _log('No static files found at ${staticDir.path} — API only mode.');
  }

  final cascade = Cascade().add(router.call).add(staticHandler);

  final pipeline = const Pipeline()
      .addMiddleware(corsHeaders(headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: '*',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, PUT, OPTIONS',
        ACCESS_CONTROL_ALLOW_HEADERS: 'content-type',
      }))
      .addMiddleware(logRequests())
      .addHandler(cascade.handler);

  final server = await shelf_io.serve(pipeline, '0.0.0.0', port);
  server.autoCompress = true;
  _log('Server listening on http://0.0.0.0:${server.port}');
  _log('Data file: ${_dataFile.absolute.path}');
}
