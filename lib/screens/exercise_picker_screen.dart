import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../services/workout_service.dart';
import '../theme/app_colors.dart';

// Las categorías del catálogo: la clave que usa la API y su nombre en español
const _categories = [
  ('CHEST', 'Pecho'),
  ('BACK', 'Espalda'),
  ('LEGS', 'Piernas'),
  ('SHOULDERS', 'Hombros'),
  ('ARMS', 'Brazos'),
  ('CORE', 'Core'),
  ('CARDIO', 'Cardio'),
];

// Nombre en español de una categoría. Si no la conocemos, enseñamos la clave tal cual
String _categoryLabel(String key) {
  for (final (k, label) in _categories) {
    if (k == key) return label;
  }
  return key;
}

// Selector de ejercicios del catálogo. Se abre desde la rutina o el entrenamiento y, al elegir un
// ejercicio, se cierra y lo devuelve. Tiene buscador, filtro por categoría y carga más ejercicios
// al llegar al final de la lista. Es solo de lectura: no se puede crear, editar ni borrar ejercicios.
class ExercisePickerScreen extends StatefulWidget {
  // Ids de los ejercicios que ya están en la rutina: se enseñan marcados y no se pueden elegir
  final Set<String> selectedIds;

  const ExercisePickerScreen({super.key, this.selectedIds = const {}});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  Timer? _debounce;

  String _search = '';
  // null = todas las categorías
  String? _category;

  // Si la API dijo que hay otra página después de la última que pedimos
  bool _hasNextPage = true;

  // Cada búsqueda nueva sube este número. Así, si una respuesta antigua llega tarde,
  // no cambia el dato _hasNextPage de la búsqueda actual
  int _requestId = 0;

  // El paquete infinite_scroll_pagination se encarga del scroll: vigila cuándo se llega al final,
  // pide la página siguiente y guarda las páginas. Nosotros solo le decimos qué página toca pedir
  // y cómo pedirla. Si llega una respuesta de una petición que se canceló con refresh(), el paquete
  // la descarta él solo.
  late final _pagingController = PagingController<int, Exercise>(
    // Qué página pedir ahora: la siguiente, o ninguna si la API ya dijo que no hay más
    getNextPageKey: (state) => _hasNextPage ? state.nextIntPageKey : null,
    fetchPage: _fetchPage,
  );

  @override
  void dispose() {
    _debounce?.cancel();
    _pagingController.dispose();
    super.dispose();
  }

  // Pide una página del catálogo a la API (GET /exercises) con la búsqueda y la categoría actuales
  Future<List<Exercise>> _fetchPage(int page) async {
    final auth = context.read<AuthProvider>();
    final requestId = _requestId;

    final result = await WorkoutService.exercises(auth, page: page, search: _search, category: _category);

    // Si mientras tanto se empezó otra búsqueda, esta respuesta ya no vale y no toca _hasNextPage
    if (requestId == _requestId) _hasNextPage = result.hasNextPage;

    return result.exercises;
  }

  // Empieza una búsqueda nueva: vuelve a la primera página y deja de esperar a las respuestas anteriores
  void _restart() {
    _requestId++;
    _hasNextPage = true;
    _pagingController.refresh();
  }

  // Busca cuando el usuario deja de escribir, para no llamar a la API con cada letra
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = text.trim();
      _restart();
    });
  }

  // Filtra por categoría. Si se vuelve a pulsar la que ya estaba elegida, se quita el filtro
  void _selectCategory(String? category) {
    setState(() => _category = category);
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir ejercicio')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar ejercicio',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // Las categorías van en una fila que se desliza hacia los lados
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: const Text('Todas'), selected: _category == null, onSelected: (_) => _selectCategory(null)),
                ),
                for (final (key, label) in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _category == key,
                      onSelected: (_) => _selectCategory(_category == key ? null : key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  // La lista de ejercicios. El paquete pinta la rueda de carga de la primera página y la del final;
  // nosotros solo ponemos los textos en español de "sin resultados" y de los errores
  Widget _buildList() {
    return PagingListener(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) => PagedListView<int, Exercise>(
        state: state,
        fetchNextPage: fetchNextPage,
        builderDelegate: PagedChildBuilderDelegate<Exercise>(
          itemBuilder: (context, exercise, index) => _buildTile(exercise),
          noItemsFoundIndicatorBuilder: (_) => const Center(child: Text('No hay ejercicios con esos filtros')),
          firstPageErrorIndicatorBuilder: (_, error) => Center(child: Text('$error', style: const TextStyle(color: AppColors.danger))),
          // Si falla al cargar más, se enseña el error al final de la lista y al tocarlo se reintenta
          newPageErrorIndicatorBuilder: (_, error) => ListTile(
            title: Text('$error', style: const TextStyle(color: AppColors.danger)),
            subtitle: const Text('Toca para reintentar'),
            onTap: _pagingController.fetchNextPage,
          ),
        ),
      ),
    );
  }

  // Un ejercicio de la lista
  Widget _buildTile(Exercise exercise) {
    final added = widget.selectedIds.contains(exercise.id);

    return ListTile(
      title: Text(exercise.name),
      subtitle: Text(_categoryLabel(exercise.category)),
      // Los que ya están en la rutina salen con un check y no se pueden volver a elegir
      enabled: !added,
      trailing: added ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(exercise),
    );
  }
}
