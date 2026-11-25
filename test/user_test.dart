import 'package:flutter_test/flutter_test.dart';
import 'package:app_spotter/models/user.dart';

// Test sencillo del modelo User: fromJson y toJson
void main() {
  test('User.fromJson y toJson', () {
    final user = User.fromJson({'_id': '1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'});

    expect(user.id, '1');
    expect(user.name, 'Ana');
    expect(user.toJson(), {'_id': '1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'});
  });
}
