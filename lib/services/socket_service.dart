import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/environment.dart';

// Conexión Socket.IO con el backend, para recibir avisos en tiempo real.
// Usa la misma URL que la API. El servidor comprueba el token al conectar.
class SocketService {
  io.Socket? _socket;

  // Abre la conexión. El token se pide con getToken cada vez que se conecta (o se reconecta),
  // así si el token se ha renovado mientras tanto se usa el último.
  // onSessionCreated se llama cada vez que llega el evento session:created, que es cuando
  // se guarda un entrenamiento del usuario (en este u otro dispositivo).
  void connect(String? Function() getToken, void Function() onSessionCreated) {
    // Si ya había una conexión, la cerramos antes de abrir otra
    disconnect();

    final socket = io.io(
      Environment.apiUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          // Una conexion nueva cada vez: sin esto la libreria reutiliza la anterior de la misma URL,
          // y al cambiar de usuario se quedaria con el token y los avisos del anterior
          .enableForceNew()
          .setAuthFn((callback) => callback({'token': getToken()}))
          .disableAutoConnect()
          .build(),
    );

    socket.on('session:created', (_) => onSessionCreated());

    // Si no se puede conectar (servidor caído, token que no vale...) no hacemos nada:
    // la pantalla sigue funcionando con su botón de actualizar
    socket.onConnectError((_) {});

    socket.connect();
    _socket = socket;
  }

  // Cierra la conexión (al salir de la pantalla o cerrar sesión)
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
