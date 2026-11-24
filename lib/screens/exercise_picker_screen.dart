import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../services/http_client.dart';
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
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<Exercise> _exercises = [];
  String _search = '';
  // null = todas las categorías
  String? _category;
  int _page = 1;
  bool _hasNextPage = false;

  // true mientras se carga la primera página de una búsqueda
  bool _loading = true;
  // true mientras se cargan más ejercicios al final de la lista
  bool _loadingMore = false;
  String? _error;

  // Cada búsqueda nueva sube este número. Así, si una respuesta antigua llega tarde,
  // se ignora y no pisa los resultados de la búsqueda actual
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Pide la primera página con la búsqueda y la categoría actuales (GET /exercises)
  Future<void> _loadFirstPage() async {
    final requestId = ++_requestId;
    final auth = context.read<AuthProvider>();

    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });

    try {
      final result = await WorkoutService.exercises(auth, page: 1, search: _search, category: _category);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _exercises = result.exercises;
        _page = 1;
        _hasNextPage = result.hasNextPage;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  // Pide la página siguiente y la añade al final de la lista
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasNextPage) return;

    final requestId = _requestId;
    final auth = context.read<AuthProvider>();
    setState(() => _loadingMore = true);

    try {
      final result = await WorkoutService.exercises(auth, page: _page + 1, search: _search, category: _category);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _exercises = [..._exercises, ...result.exercises];
        _page += 1;
        _hasNextPage = result.hasNextPage;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e.message;
        _loadingMore = false;
      });
    }
  }

  // Cuando falta poco para llegar al final de la lista, cargamos más ejercicios
  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) _loadMore();
  }

  // Busca cuando el usuario deja de escribir, para no llamar a la API con cada letra
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = text.trim();
      _loadFirstPage();
    });
  }

  // Filtra por categoría. Si se vuelve a pulsar la que ya estaba elegida, se quita el filtro
  void _selectCategory(String? category) {
    _category = category;
    _loadFirstPage();
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
              controller: _searchController,
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

  // La lista de ejercicios, o el mensaje que toque si está cargando, falla o no hay resultados
  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _exercises.isEmpty) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)));
    }

    if (_exercises.isEmpty) return const Center(child: Text('No hay ejercicios con esos filtros'));

    return ListView.builder(
      controller: _scrollController,
      // Un elemento más al final con la rueda de carga, mientras se piden más ejercicios
      itemCount: _exercises.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == _exercises.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }

        final exercise = _exercises[index];
        final added = widget.selectedIds.contains(exercise.id);

        return ListTile(
          title: Text(exercise.name),
          subtitle: Text(_categoryLabel(exercise.category)),
          // Los que ya están en la rutina salen con un check y no se pueden volver a elegir
          enabled: !added,
          trailing: added ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(exercise),
        );
      },
    );
  }
}
