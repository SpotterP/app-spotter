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
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      // El servidor manda el rol (POST /auth/login y GET /users/me). El 'USER' de aquí es
      // sólo una red de seguridad para una respuesta antigua o recortada: cuando la API
      // trae el rol, es el que se usa.
      role: json['role'] ?? 'USER',
    );
  }

  // Convierte el User a JSON (lo usamos para guardarlo en el móvil)
  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name, 'email': email, 'role': role};
  }
}
