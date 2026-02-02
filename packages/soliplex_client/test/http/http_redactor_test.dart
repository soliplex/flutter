import 'package:soliplex_client/src/http/http_redactor.dart';
import 'package:test/test.dart';

void main() {
  group('HttpRedactor.redactHeaders', () {
    group('exact match headers', () {
      test('redacts Authorization header', () {
        final headers = {'Authorization': 'Bearer secret-token'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['Authorization'], equals('[REDACTED]'));
      });

      test('redacts Proxy-Authorization header', () {
        final headers = {'Proxy-Authorization': 'Basic abc123'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['Proxy-Authorization'], equals('[REDACTED]'));
      });

      test('redacts Cookie header', () {
        final headers = {'Cookie': 'session=abc123'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['Cookie'], equals('[REDACTED]'));
      });

      test('redacts Set-Cookie header', () {
        final headers = {'Set-Cookie': 'session=abc123; Path=/'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['Set-Cookie'], equals('[REDACTED]'));
      });

      test('redacts X-API-Key header', () {
        final headers = {'X-API-Key': 'my-api-key'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-API-Key'], equals('[REDACTED]'));
      });

      test('redacts X-Auth-Token header', () {
        final headers = {'X-Auth-Token': 'my-token'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Auth-Token'], equals('[REDACTED]'));
      });

      test('redacts X-CSRF-Token header', () {
        final headers = {'X-CSRF-Token': 'csrf-value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-CSRF-Token'], equals('[REDACTED]'));
      });

      test('redacts X-XSRF-Token header', () {
        final headers = {'X-XSRF-Token': 'xsrf-value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-XSRF-Token'], equals('[REDACTED]'));
      });

      test('redacts X-Forwarded-For header', () {
        final headers = {'X-Forwarded-For': '192.168.1.1'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Forwarded-For'], equals('[REDACTED]'));
      });

      test('redacts X-Real-IP header', () {
        final headers = {'X-Real-IP': '10.0.0.1'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Real-IP'], equals('[REDACTED]'));
      });

      test('exact match is case-insensitive', () {
        final headers = {
          'authorization': 'Bearer token',
          'COOKIE': 'session=abc',
          'X-Api-Key': 'key',
        };
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['authorization'], equals('[REDACTED]'));
        expect(result['COOKIE'], equals('[REDACTED]'));
        expect(result['X-Api-Key'], equals('[REDACTED]'));
      });
    });

    group('substring match headers', () {
      test('redacts headers containing "token"', () {
        final headers = {'X-Custom-Token': 'value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Custom-Token'], equals('[REDACTED]'));
      });

      test('redacts headers containing "key"', () {
        final headers = {'Api-Key-Custom': 'value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['Api-Key-Custom'], equals('[REDACTED]'));
      });

      test('redacts headers containing "secret"', () {
        final headers = {'X-Secret-Header': 'value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Secret-Header'], equals('[REDACTED]'));
      });

      test('redacts headers containing "password"', () {
        final headers = {'X-Password': 'value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Password'], equals('[REDACTED]'));
      });

      test('redacts headers containing "auth"', () {
        final headers = {'X-Auth-Info': 'value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Auth-Info'], equals('[REDACTED]'));
      });

      test('redacts headers containing "session"', () {
        final headers = {'X-Session-Id': 'value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Session-Id'], equals('[REDACTED]'));
      });

      test('redacts headers containing "credential"', () {
        final headers = {'X-Credential': 'value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Credential'], equals('[REDACTED]'));
      });

      test('redacts headers containing "bearer"', () {
        final headers = {'X-Bearer-Token': 'value'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-Bearer-Token'], equals('[REDACTED]'));
      });

      test('substring match is case-insensitive', () {
        final headers = {
          'X-TOKEN': 'value',
          'x-Secret': 'value',
          'PASSWORD-Header': 'value',
        };
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['X-TOKEN'], equals('[REDACTED]'));
        expect(result['x-Secret'], equals('[REDACTED]'));
        expect(result['PASSWORD-Header'], equals('[REDACTED]'));
      });
    });

    group('non-sensitive headers', () {
      test('preserves Content-Type header', () {
        final headers = {'Content-Type': 'application/json'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['Content-Type'], equals('application/json'));
      });

      test('preserves Content-Length header', () {
        final headers = {'Content-Length': '1024'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['Content-Length'], equals('1024'));
      });

      test('preserves Accept header', () {
        final headers = {'Accept': 'application/json'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['Accept'], equals('application/json'));
      });

      test('preserves User-Agent header', () {
        final headers = {'User-Agent': 'Soliplex/1.0'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['User-Agent'], equals('Soliplex/1.0'));
      });

      test('preserves Cache-Control header', () {
        final headers = {'Cache-Control': 'no-cache'};
        final result = HttpRedactor.redactHeaders(headers);
        expect(result['Cache-Control'], equals('no-cache'));
      });
    });

    group('mixed headers', () {
      test('redacts sensitive and preserves non-sensitive headers', () {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer secret',
          'Accept': '*/*',
          'X-API-Key': 'my-key',
          'Cache-Control': 'no-cache',
        };
        final result = HttpRedactor.redactHeaders(headers);

        expect(result['Content-Type'], equals('application/json'));
        expect(result['Authorization'], equals('[REDACTED]'));
        expect(result['Accept'], equals('*/*'));
        expect(result['X-API-Key'], equals('[REDACTED]'));
        expect(result['Cache-Control'], equals('no-cache'));
      });

      test('returns empty map for empty input', () {
        final result = HttpRedactor.redactHeaders({});
        expect(result, isEmpty);
      });
    });
  });

  group('HttpRedactor.redactUri', () {
    group('sensitive query parameters', () {
      test('redacts token parameter', () {
        final uri = Uri.parse('https://example.com/api?token=secret123');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['token'], equals('[REDACTED]'));
      });

      test('redacts access_token parameter', () {
        final uri = Uri.parse('https://example.com/api?access_token=abc');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['access_token'], equals('[REDACTED]'));
      });

      test('redacts refresh_token parameter', () {
        final uri = Uri.parse('https://example.com/api?refresh_token=xyz');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['refresh_token'], equals('[REDACTED]'));
      });

      test('redacts id_token parameter', () {
        final uri = Uri.parse('https://example.com/api?id_token=jwt');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['id_token'], equals('[REDACTED]'));
      });

      test('redacts code parameter', () {
        final uri = Uri.parse('https://example.com/callback?code=authcode');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['code'], equals('[REDACTED]'));
      });

      test('redacts client_secret parameter', () {
        final uri = Uri.parse('https://example.com/api?client_secret=secret');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['client_secret'], equals('[REDACTED]'));
      });

      test('redacts state parameter', () {
        final uri = Uri.parse('https://example.com/callback?state=random');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['state'], equals('[REDACTED]'));
      });

      test('redacts code_verifier parameter', () {
        final uri = Uri.parse('https://example.com/api?code_verifier=pkce');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['code_verifier'], equals('[REDACTED]'));
      });

      test('redacts session_state parameter', () {
        final uri = Uri.parse('https://example.com/api?session_state=sess');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['session_state'], equals('[REDACTED]'));
      });

      test('redacts api_key parameter', () {
        final uri = Uri.parse('https://example.com/api?api_key=key123');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['api_key'], equals('[REDACTED]'));
      });

      test('redacts password parameter', () {
        final uri = Uri.parse('https://example.com/api?password=pass123');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['password'], equals('[REDACTED]'));
      });

      test('redacts secret parameter', () {
        final uri = Uri.parse('https://example.com/api?secret=shhh');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['secret'], equals('[REDACTED]'));
      });

      test('redacts key parameter', () {
        final uri = Uri.parse('https://example.com/api?key=mykey');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['key'], equals('[REDACTED]'));
      });

      test('redacts credential parameter', () {
        final uri = Uri.parse('https://example.com/api?credential=cred');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['credential'], equals('[REDACTED]'));
      });

      test('redacts auth parameter', () {
        final uri = Uri.parse('https://example.com/api?auth=authvalue');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['auth'], equals('[REDACTED]'));
      });

      test('parameter matching is case-insensitive', () {
        final uri = Uri.parse(
          'https://example.com/api?TOKEN=a&Access_Token=b&API_KEY=c',
        );
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['TOKEN'], equals('[REDACTED]'));
        expect(result.queryParameters['Access_Token'], equals('[REDACTED]'));
        expect(result.queryParameters['API_KEY'], equals('[REDACTED]'));
      });
    });

    group('non-sensitive query parameters', () {
      test('preserves page parameter', () {
        final uri = Uri.parse('https://example.com/api?page=5');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['page'], equals('5'));
      });

      test('preserves limit parameter', () {
        final uri = Uri.parse('https://example.com/api?limit=20');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['limit'], equals('20'));
      });

      test('preserves sort parameter', () {
        final uri = Uri.parse('https://example.com/api?sort=name');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['sort'], equals('name'));
      });

      test('preserves id parameter', () {
        final uri = Uri.parse('https://example.com/api?id=123');
        final result = HttpRedactor.redactUri(uri);
        expect(result.queryParameters['id'], equals('123'));
      });
    });

    group('mixed query parameters', () {
      test('redacts sensitive and preserves non-sensitive params', () {
        final uri = Uri.parse(
          'https://example.com/api?page=1&token=secret&limit=10&api_key=key',
        );
        final result = HttpRedactor.redactUri(uri);

        expect(result.queryParameters['page'], equals('1'));
        expect(result.queryParameters['token'], equals('[REDACTED]'));
        expect(result.queryParameters['limit'], equals('10'));
        expect(result.queryParameters['api_key'], equals('[REDACTED]'));
      });

      test('preserves path and host', () {
        final uri = Uri.parse(
          'https://example.com/api/v1/users?token=secret&page=1',
        );
        final result = HttpRedactor.redactUri(uri);

        expect(result.scheme, equals('https'));
        expect(result.host, equals('example.com'));
        expect(result.path, equals('/api/v1/users'));
      });

      test('returns unchanged uri when no query parameters', () {
        final uri = Uri.parse('https://example.com/api');
        final result = HttpRedactor.redactUri(uri);
        expect(result, equals(uri));
      });

      test('returns unchanged uri when no sensitive parameters', () {
        final uri = Uri.parse('https://example.com/api?page=1&limit=10');
        final result = HttpRedactor.redactUri(uri);
        expect(result, equals(uri));
      });
    });
  });

  group('HttpRedactor.redactJsonBody', () {
    group('field name redaction', () {
      test('redacts password field', () {
        final body = {'username': 'john', 'password': 'secret123'};
        final result = _redactMap(body);
        expect(result['username'], equals('john'));
        expect(result['password'], equals('[REDACTED]'));
      });

      test('redacts secret field', () {
        final body = {'name': 'config', 'secret': 'shhh'};
        final result = _redactMap(body);
        expect(result['secret'], equals('[REDACTED]'));
      });

      test('redacts token field', () {
        final body = {'token': 'jwt-token'};
        final result = _redactMap(body);
        expect(result['token'], equals('[REDACTED]'));
      });

      test('redacts access_token field', () {
        final body = {'access_token': 'at-123'};
        final result = _redactMap(body);
        expect(result['access_token'], equals('[REDACTED]'));
      });

      test('redacts refresh_token field', () {
        final body = {'refresh_token': 'rt-456'};
        final result = _redactMap(body);
        expect(result['refresh_token'], equals('[REDACTED]'));
      });

      test('redacts id_token field', () {
        final body = {'id_token': 'id-789'};
        final result = _redactMap(body);
        expect(result['id_token'], equals('[REDACTED]'));
      });

      test('redacts api_key field', () {
        final body = {'api_key': 'key-abc'};
        final result = _redactMap(body);
        expect(result['api_key'], equals('[REDACTED]'));
      });

      test('redacts client_secret field', () {
        final body = {'client_secret': 'cs-xyz'};
        final result = _redactMap(body);
        expect(result['client_secret'], equals('[REDACTED]'));
      });

      test('redacts authorization field', () {
        final body = {'authorization': 'Bearer abc'};
        final result = _redactMap(body);
        expect(result['authorization'], equals('[REDACTED]'));
      });

      test('redacts credential field', () {
        final body = {'credential': 'cred-123'};
        final result = _redactMap(body);
        expect(result['credential'], equals('[REDACTED]'));
      });

      test('redacts bearer field', () {
        final body = {'bearer': 'token-value'};
        final result = _redactMap(body);
        expect(result['bearer'], equals('[REDACTED]'));
      });

      test('redacts session_token field', () {
        final body = {'session_token': 'sess-abc'};
        final result = _redactMap(body);
        expect(result['session_token'], equals('[REDACTED]'));
      });

      test('redacts private_key field', () {
        final body = {'private_key': '-----BEGIN RSA-----'};
        final result = _redactMap(body);
        expect(result['private_key'], equals('[REDACTED]'));
      });

      test('redacts signing_key field', () {
        final body = {'signing_key': 'sign-key'};
        final result = _redactMap(body);
        expect(result['signing_key'], equals('[REDACTED]'));
      });

      test('redacts encryption_key field', () {
        final body = {'encryption_key': 'enc-key'};
        final result = _redactMap(body);
        expect(result['encryption_key'], equals('[REDACTED]'));
      });

      test('field name matching is case-insensitive', () {
        final body = {
          'PASSWORD': 'secret1',
          'Token': 'secret2',
          'Api_Key': 'secret3',
        };
        final result = _redactMap(body);
        expect(result['PASSWORD'], equals('[REDACTED]'));
        expect(result['Token'], equals('[REDACTED]'));
        expect(result['Api_Key'], equals('[REDACTED]'));
      });
    });

    group('nested object redaction', () {
      test('redacts sensitive fields in nested objects', () {
        final body = {
          'user': {
            'name': 'John',
            'password': 'secret',
          },
        };
        final result = _redactMap(body);
        final user = result['user'] as Map<String, dynamic>;
        expect(user['name'], equals('John'));
        expect(user['password'], equals('[REDACTED]'));
      });

      test('redacts deeply nested sensitive fields', () {
        final body = {
          'level1': {
            'level2': {
              'level3': {
                'token': 'deep-secret',
              },
            },
          },
        };
        final result = _redactMap(body);
        final level1 = result['level1'] as Map<String, dynamic>;
        final level2 = level1['level2'] as Map<String, dynamic>;
        final level3 = level2['level3'] as Map<String, dynamic>;
        expect(level3['token'], equals('[REDACTED]'));
      });
    });

    group('array handling', () {
      test('redacts sensitive fields in array elements', () {
        final body = {
          'users': [
            {'name': 'Alice', 'password': 'pass1'},
            {'name': 'Bob', 'password': 'pass2'},
          ],
        };
        final result = _redactMap(body);
        final users = result['users'] as List<dynamic>;
        final user0 = users[0] as Map<String, dynamic>;
        final user1 = users[1] as Map<String, dynamic>;
        expect(user0['name'], equals('Alice'));
        expect(user0['password'], equals('[REDACTED]'));
        expect(user1['name'], equals('Bob'));
        expect(user1['password'], equals('[REDACTED]'));
      });

      test('handles mixed arrays', () {
        final body = {
          'data': [
            'string',
            42,
            {'token': 'secret'},
          ],
        };
        final result = _redactMap(body);
        final data = result['data'] as List<dynamic>;
        expect(data[0], equals('string'));
        expect(data[1], equals(42));
        final item2 = data[2] as Map<String, dynamic>;
        expect(item2['token'], equals('[REDACTED]'));
      });
    });

    group('non-sensitive content', () {
      test('preserves non-sensitive string fields', () {
        final body = {'name': 'John', 'email': 'john@example.com'};
        final result = _redactMap(body);
        expect(result['name'], equals('John'));
        expect(result['email'], equals('john@example.com'));
      });

      test('preserves numeric fields', () {
        final body = {'count': 42, 'price': 19.99};
        final result = _redactMap(body);
        expect(result['count'], equals(42));
        expect(result['price'], equals(19.99));
      });

      test('preserves boolean fields', () {
        final body = {'active': true, 'verified': false};
        final result = _redactMap(body);
        expect(result['active'], equals(true));
        expect(result['verified'], equals(false));
      });

      test('preserves null fields', () {
        final body = {'optional': null};
        final result = _redactMap(body);
        expect(result['optional'], isNull);
      });
    });

    group('auth endpoint detection', () {
      test('redacts entire body for /oauth endpoint', () {
        final uri = Uri.parse('https://example.com/oauth/token');
        final body = {'grant_type': 'password', 'username': 'user'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /token endpoint', () {
        final uri = Uri.parse('https://example.com/api/token');
        final body = {'code': 'authcode'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /auth endpoint', () {
        final uri = Uri.parse('https://example.com/auth/login');
        final body = {'user': 'test'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /login endpoint', () {
        final uri = Uri.parse('https://example.com/api/login');
        final body = {'username': 'user', 'password': 'pass'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /signin endpoint', () {
        final uri = Uri.parse('https://example.com/signin');
        final body = {'email': 'user@example.com'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /authenticate endpoint', () {
        final uri = Uri.parse('https://example.com/api/authenticate');
        final body = {'credentials': 'data'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /password endpoint', () {
        final uri = Uri.parse('https://example.com/password/change');
        final body = {'old': 'old', 'new': 'new'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /reset-password endpoint', () {
        final uri = Uri.parse('https://example.com/reset-password');
        final body = {'email': 'user@example.com'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /forgot-password endpoint', () {
        final uri = Uri.parse('https://example.com/forgot-password');
        final body = {'email': 'user@example.com'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /register endpoint', () {
        final uri = Uri.parse('https://example.com/register');
        final body = {'email': 'user@example.com', 'password': 'pass'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /signup endpoint', () {
        final uri = Uri.parse('https://example.com/signup');
        final body = {'email': 'user@example.com'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /session endpoint', () {
        final uri = Uri.parse('https://example.com/session');
        final body = {'token': 'sess-token'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /sessions endpoint', () {
        final uri = Uri.parse('https://example.com/sessions');
        final body = {'active': true};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /2fa endpoint', () {
        final uri = Uri.parse('https://example.com/2fa/verify');
        final body = {'code': '123456'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /mfa endpoint', () {
        final uri = Uri.parse('https://example.com/mfa/setup');
        final body = {'method': 'totp'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('redacts entire body for /otp endpoint', () {
        final uri = Uri.parse('https://example.com/otp/send');
        final body = {'phone': '+1234567890'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('auth endpoint detection is case-insensitive', () {
        final uri = Uri.parse('https://example.com/API/LOGIN');
        final body = {'user': 'test'};
        final result = HttpRedactor.redactJsonBody(body, uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });
    });

    group('edge cases', () {
      test('returns empty map for empty input', () {
        final result = _redactMap({});
        expect(result, equals(<String, dynamic>{}));
      });

      test('handles string body (non-JSON)', () {
        final result = HttpRedactor.redactJsonBody('plain text', _nonAuthUri);
        expect(result, equals('plain text'));
      });

      test('redacts string body for auth endpoint', () {
        final uri = Uri.parse('https://example.com/login');
        final result = HttpRedactor.redactJsonBody('plain text', uri);
        expect(result, equals('[REDACTED - Auth Endpoint]'));
      });

      test('handles list body', () {
        final body = [
          {'token': 'secret'},
          {'name': 'test'},
        ];
        final result =
            HttpRedactor.redactJsonBody(body, _nonAuthUri) as List<dynamic>;
        final item0 = result[0] as Map<String, dynamic>;
        final item1 = result[1] as Map<String, dynamic>;
        expect(item0['token'], equals('[REDACTED]'));
        expect(item1['name'], equals('test'));
      });

      test('handles null body', () {
        final result = HttpRedactor.redactJsonBody(null, _nonAuthUri);
        expect(result, isNull);
      });
    });
  });

  group('HttpRedactor.redactString', () {
    test('redacts string for auth endpoint', () {
      final uri = Uri.parse('https://example.com/login');
      final result = HttpRedactor.redactString('raw body content', uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('returns string unchanged for non-auth endpoint', () {
      final result = HttpRedactor.redactString('raw body content', _nonAuthUri);
      expect(result, equals('raw body content'));
    });

    group('form-encoded body redaction', () {
      test('redacts password in form-encoded body', () {
        final result = HttpRedactor.redactString(
          'username=john&password=secret123',
          _nonAuthUri,
        );
        expect(result, contains('username=john'));
        expect(result, isNot(contains('secret123')));
        expect(result, contains('password=[REDACTED]'));
      });

      test('redacts token in form-encoded body', () {
        final result = HttpRedactor.redactString(
          'grant_type=refresh&token=abc123',
          _nonAuthUri,
        );
        expect(result, contains('grant_type=refresh'));
        expect(result, isNot(contains('abc123')));
      });

      test('redacts multiple sensitive fields in form-encoded body', () {
        final result = HttpRedactor.redactString(
          'username=john&password=secret&api_key=key123&page=1',
          _nonAuthUri,
        );
        expect(result, contains('username=john'));
        expect(result, contains('page=1'));
        expect(result, isNot(contains('secret')));
        expect(result, isNot(contains('key123')));
      });

      test('handles URL-encoded values in form body', () {
        final result = HttpRedactor.redactString(
          'email=john%40example.com&password=pass%26word',
          _nonAuthUri,
        );
        expect(result, contains('email=john%40example.com'));
        expect(result, isNot(contains('pass%26word')));
      });
    });
  });

  group('HttpRedactor additional auth endpoints', () {
    test('redacts body for /verify endpoint', () {
      final uri = Uri.parse('https://example.com/verify/email');
      final body = {'code': '123456'};
      final result = HttpRedactor.redactJsonBody(body, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('redacts body for /activate endpoint', () {
      final uri = Uri.parse('https://example.com/activate');
      final body = {'token': 'abc'};
      final result = HttpRedactor.redactJsonBody(body, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('redacts body for /api-keys endpoint', () {
      final uri = Uri.parse('https://example.com/api-keys');
      final body = {'name': 'my-key'};
      final result = HttpRedactor.redactJsonBody(body, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('redacts body for /tokens endpoint', () {
      final uri = Uri.parse('https://example.com/tokens');
      final body = {'type': 'access'};
      final result = HttpRedactor.redactJsonBody(body, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('redacts body for /credentials endpoint', () {
      final uri = Uri.parse('https://example.com/credentials');
      final body = {'user': 'test'};
      final result = HttpRedactor.redactJsonBody(body, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('redacts body for /authorization endpoint', () {
      final uri = Uri.parse('https://example.com/authorization');
      final body = {'scope': 'read'};
      final result = HttpRedactor.redactJsonBody(body, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('redacts body for /revoke endpoint', () {
      final uri = Uri.parse('https://example.com/revoke');
      final body = {'token': 'abc'};
      final result = HttpRedactor.redactJsonBody(body, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('redacts body for /introspect endpoint', () {
      final uri = Uri.parse('https://example.com/introspect');
      final body = {'token': 'jwt'};
      final result = HttpRedactor.redactJsonBody(body, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('redacts body for /userinfo endpoint', () {
      final uri = Uri.parse('https://example.com/userinfo');
      final body = {'sub': '123'};
      final result = HttpRedactor.redactJsonBody(body, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });
  });

  group('HttpRedactor.redactSseContent', () {
    test('redacts sensitive fields in SSE JSON data events', () {
      const sseContent = '''
event: message
data: {"text": "hello", "token": "secret123"}

event: done
data: {"status": "complete"}

''';
      final result = HttpRedactor.redactSseContent(sseContent, _nonAuthUri);
      expect(result, contains('"text":"hello"'));
      expect(result, isNot(contains('secret123')));
      expect(result, contains('"status":"complete"'));
    });

    test('redacts entire SSE content for auth endpoints', () {
      const sseContent = 'event: auth\ndata: {"token": "secret"}\n\n';
      final uri = Uri.parse('https://example.com/login/stream');
      final result = HttpRedactor.redactSseContent(sseContent, uri);
      expect(result, equals('[REDACTED - Auth Endpoint]'));
    });

    test('handles malformed SSE content gracefully', () {
      const sseContent = 'not valid sse content';
      final result = HttpRedactor.redactSseContent(sseContent, _nonAuthUri);
      expect(result, equals(sseContent));
    });
  });
}

final _nonAuthUri = Uri.parse('https://example.com/api/data');

/// Helper to redact a map body and cast to typed result.
Map<String, dynamic> _redactMap(Map<String, dynamic> body) {
  return HttpRedactor.redactJsonBody(body, _nonAuthUri) as Map<String, dynamic>;
}
