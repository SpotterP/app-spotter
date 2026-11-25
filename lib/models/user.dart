// Usuario de la app (lo que devuelve la API al hacer login)
class User {
  final String id;
  final String name;
  final String email;
  final String role;

  User({required this.id, required this.name, required this.email, required this.role});

  // La app es para usuarios normales: el backend protege sus rutas con RequireRole('USER')
  // (/users/me/workouts, /users/me/sessions, /users/me/progress). ADMIN es el rol del
  // backoffice, que entra por otro login y tiene otras pantallas, así que una cuenta de
  // administrador no puede usar la app: vería las pestañas de datos vacías por un 403.
  bool get canUseApp => role == 'USER';

  // Convierte el JSON de la API en un User. La API manda el id como "_id"
  //
  // id, name y email son obligatorios: si la API deja de mandar uno, es mejor decirlo aquí, con
  // el campo por su nombre, que pintar un hueco en el perfil o inventarse un rol. En cambio el
  // rol es opcional: GET /users/me lo manda, y si un día no viene se queda el de siempre.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _campoObligatorio(json, '_id'),
      name: _campoObligatorio(json, 'name'),
      email: _campoObligatorio(json, 'email'),
      role: json['role'] is String ? json['role'] as String : 'USER',
    );
  }

  // Un campo de texto que la API tiene que mandar sí o sí
  static String _campoObligatorio(Map<String, dynamic> json, String campo) {
    final valor = json[campo];
    if (valor is String && valor.isNotEmpty) return valor;

    throw FormatException('La respuesta de la API no trae el campo obligatorio "$campo" del usuario');
  }

  // Convierte el User a JSON (lo usamos para guardarlo en el móvil)
  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name, 'email': email, 'role': role};
  }
}
