import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:sqlite3/sqlite3.dart';

void _log(String msg) => stdout.writeln(msg);

// ── Database ────────────────────────────────────────────────────────────────

late final Database _db;

void _initDb(String dbPath) {
  _db = sqlite3.open(dbPath);
  // WAL mode allows concurrent reads during writes and prevents file corruption
  // on simultaneous saves from multiple clients.
  _db.execute('PRAGMA journal_mode=WAL;');
  _db.execute('PRAGMA foreign_keys=ON;');
  _db.execute('''
    CREATE TABLE IF NOT EXISTS meetings (
      id               TEXT    PRIMARY KEY,
      name             TEXT    NOT NULL,
      notes_enabled    INTEGER NOT NULL DEFAULT 0,
      time_enabled     INTEGER NOT NULL DEFAULT 1,
      time_per_person  INTEGER NOT NULL DEFAULT 40,
      sort_order       INTEGER NOT NULL DEFAULT 0,
      last_session_start TEXT,
      last_session_end   TEXT
    );
  ''');
  _db.execute('''
    CREATE TABLE IF NOT EXISTS attendees (
      id             TEXT    PRIMARY KEY,
      meeting_id     TEXT    NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
      name           TEXT    NOT NULL,
      enabled        INTEGER NOT NULL DEFAULT 1,
      note           TEXT    NOT NULL DEFAULT '',
      note_edited_at TEXT,
      sort_order     INTEGER NOT NULL DEFAULT 0
    );
  ''');
}

// ── Migration from legacy meetings.json ─────────────────────────────────────

void _migrateFromJson(String dbPath) {
  // Look for a sibling .json file (same path but with .json extension).
  final jsonPath = dbPath.replaceFirst(RegExp(r'\.db$'), '.json');
  if (jsonPath == dbPath) return; // DATA_PATH has no .db extension — skip
  final jsonFile = File(jsonPath);
  if (!jsonFile.existsSync()) return;

  _log('Found legacy $jsonPath — migrating to SQLite…');
  try {
    final raw = jsonDecode(jsonFile.readAsStringSync());
    if (raw is List && raw.isNotEmpty) {
      _saveMeetings(raw);
    }
    jsonFile.renameSync('$jsonPath.migrated');
    _log('Migration complete. Legacy file renamed to ${jsonFile.path}.migrated');
  } catch (e) {
    _log('Warning: migration from $jsonPath failed: $e');
  }
}

// ── Data access ─────────────────────────────────────────────────────────────

List<dynamic> _loadMeetings() {
  final result = <dynamic>[];
  for (final row in _db.select('SELECT * FROM meetings ORDER BY sort_order')) {
    final attendees = _db
        .select(
          'SELECT * FROM attendees WHERE meeting_id = ? ORDER BY sort_order',
          [row['id']],
        )
        .map((a) => <String, dynamic>{
              'id': a['id'],
              'name': a['name'],
              'enabled': a['enabled'] == 1,
              'note': a['note'],
              if (a['note_edited_at'] != null) 'noteEditedAt': a['note_edited_at'],
            })
        .toList();

    final meeting = <String, dynamic>{
      'id': row['id'],
      'name': row['name'],
      'notesEnabled': row['notes_enabled'] == 1,
      'timeEnabled': row['time_enabled'] == 1,
      'timePerPerson': row['time_per_person'],
      'attendees': attendees,
    };
    if (row['last_session_start'] != null && row['last_session_end'] != null) {
      meeting['lastSession'] = {
        'startTime': row['last_session_start'],
        'endTime': row['last_session_end'],
      };
    }
    result.add(meeting);
  }
  return result;
}

void _saveMeetings(List<dynamic> data) {
  _db.execute('BEGIN');
  try {
    _db.execute('DELETE FROM meetings');
    for (var i = 0; i < data.length; i++) {
      final m = data[i] as Map<String, dynamic>;
      final lastSession = m['lastSession'] as Map<String, dynamic>?;
      _db.execute(
        '''INSERT INTO meetings
             (id, name, notes_enabled, time_enabled, time_per_person,
              sort_order, last_session_start, last_session_end)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          m['id'],
          m['name'],
          (m['notesEnabled'] as bool? ?? false) ? 1 : 0,
          (m['timeEnabled'] as bool? ?? true) ? 1 : 0,
          m['timePerPerson'] ?? 40,
          i,
          lastSession?['startTime'],
          lastSession?['endTime'],
        ],
      );
      final attendees = m['attendees'] as List<dynamic>? ?? [];
      for (var j = 0; j < attendees.length; j++) {
        final a = attendees[j] as Map<String, dynamic>;
        _db.execute(
          '''INSERT INTO attendees
               (id, meeting_id, name, enabled, note, note_edited_at, sort_order)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [
            a['id'],
            m['id'],
            a['name'],
            (a['enabled'] as bool? ?? true) ? 1 : 0,
            a['note'] ?? '',
            a['noteEditedAt'],
            j,
          ],
        );
      }
    }
    _db.execute('COMMIT');
  } catch (e) {
    _db.execute('ROLLBACK');
    rethrow;
  }
}

// ── HTTP handlers ────────────────────────────────────────────────────────────

Response _jsonOk(Object body) => Response.ok(
      jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response _badRequest(String msg) => Response(
      400,
      body: jsonEncode({'error': msg}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<Response> _getMeetings(Request _) async => _jsonOk(_loadMeetings());

Future<Response> _putMeetings(Request req) async {
  final body = await req.readAsString();
  dynamic parsed;
  try {
    parsed = jsonDecode(body);
  } catch (_) {
    return _badRequest('Invalid JSON');
  }
  if (parsed is! List) return _badRequest('Expected a JSON array');
  try {
    _saveMeetings(parsed);
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Database error: $e'}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
  return _jsonOk({'ok': true});
}

// ── Main ─────────────────────────────────────────────────────────────────────

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final dbPath = Platform.environment['DATA_PATH'] ?? 'meetings.db';

  _initDb(dbPath);
  _migrateFromJson(dbPath);
  _log('Database: ${File(dbPath).absolute.path}');

  final router = Router()
    ..get('/api/meetings', _getMeetings)
    ..put('/api/meetings', _putMeetings)
    ..all('/api/<ignored|.*>', (Request _) => Response.notFound(
          '{"error":"not found"}',
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

  final staticDir =
      Directory(Platform.environment['STATIC_PATH'] ?? '../build/web');
  Handler staticHandler;
  if (staticDir.existsSync()) {
    final fileHandler =
        createStaticHandler(staticDir.path, defaultDocument: 'index.html');
    staticHandler = (Request req) async {
      final res = await fileHandler(req);
      if (res.statusCode == 404) {
        return fileHandler(Request('GET', req.requestedUri.replace(path: '/')));
      }
      return res;
    };
    _log('Serving Flutter app from: ${staticDir.absolute.path}');
  } else {
    staticHandler = (req) => Response.notFound(
        'Static files not found. Run `flutter build web` first, or set STATIC_PATH.');
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
}
