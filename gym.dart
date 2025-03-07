import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(GymTrackerApp());
}

class GymTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymTracker Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: HomePage(),
    );
  }
}

// Database Helper Class
class DatabaseHelper {
  static final _databaseName = "gymtracker.db";
  static final _databaseVersion = 1;
  
  // Singleton pattern
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }
  
  Future _onCreate(Database db, int version) async {
    // Create tables
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sets INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
      )
    ''');
    
    // Create preset exercises table
    await db.execute('''
      CREATE TABLE preset_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        is_premium INTEGER DEFAULT 0
      )
    ''');
    
    // Insert sample preset exercises
    await _insertSampleExercises(db);
  }
  
  Future _insertSampleExercises(Database db) async {
    // Free exercises
    var batch = db.batch();
    
    // Chest exercises
    batch.insert('preset_exercises', {'name': 'Bench Press', 'category': 'Chest', 'is_premium': 0});
    batch.insert('preset_exercises', {'name': 'Push-ups', 'category': 'Chest', 'is_premium': 0});
    batch.insert('preset_exercises', {'name': 'Dumbbell Flyes', 'category': 'Chest', 'is_premium': 0});
    
    // Back exercises
    batch.insert('preset_exercises', {'name': 'Pull-ups', 'category': 'Back', 'is_premium': 0});
    batch.insert('preset_exercises', {'name': 'Bent-over Rows', 'category': 'Back', 'is_premium': 0});
    batch.insert('preset_exercises', {'name': 'Lat Pulldowns', 'category': 'Back', 'is_premium': 0});
    
    // Legs exercises
    batch.insert('preset_exercises', {'name': 'Squats', 'category': 'Legs', 'is_premium': 0});
    batch.insert('preset_exercises', {'name': 'Lunges', 'category': 'Legs', 'is_premium': 0});
    batch.insert('preset_exercises', {'name': 'Leg Press', 'category': 'Legs', 'is_premium': 0});
    
    // Premium exercises
    batch.insert('preset_exercises', {'name': 'Incline Bench Press', 'category': 'Chest', 'is_premium': 1});
    batch.insert('preset_exercises', {'name': 'Cable Crossovers', 'category': 'Chest', 'is_premium': 1});
    batch.insert('preset_exercises', {'name': 'Deadlifts', 'category': 'Back', 'is_premium': 1});
    batch.insert('preset_exercises', {'name': 'T-Bar Rows', 'category': 'Back', 'is_premium': 1});
    batch.insert('preset_exercises', {'name': 'Hack Squats', 'category': 'Legs', 'is_premium': 1});
    batch.insert('preset_exercises', {'name': 'Romanian Deadlifts', 'category': 'Legs', 'is_premium': 1});
    
    await batch.commit();
  }
  
  // CRUD operations for workouts
  Future<int> insertWorkout(Map<String, dynamic> workout) async {
    Database db = await database;
    return await db.insert('workouts', workout);
  }
  
  Future<List<Map<String, dynamic>>> getWorkouts() async {
    Database db = await database;
    return await db.query('workouts', orderBy: 'date DESC');
  }
  
  Future<List<Map<String, dynamic>>> getWorkoutsByDate(DateTime date) async {
    Database db = await database;
    String dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return await db.query(
      'workouts',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
    );
  }
  
  // CRUD operations for exercises
  Future<int> insertExercise(Map<String, dynamic> exercise) async {
    Database db = await database;
    return await db.insert('exercises', exercise);
  }
  
  Future<List<Map<String, dynamic>>> getExercisesForWorkout(int workoutId) async {
    Database db = await database;
    return await db.query(
      'exercises',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );
  }
  
  // Operations for preset exercises
  Future<List<Map<String, dynamic>>> getPresetExercises(bool isPremium) async {
    Database db = await database;
    if (isPremium) {
      // If premium, get all exercises
      return await db.query('preset_exercises', orderBy: 'category, name');
    } else {
      // If free, get only free exercises
      return await db.query(
        'preset_exercises',
        where: 'is_premium = ?',
        whereArgs: [0],
        orderBy: 'category, name',
      );
    }
  }
  
  Future<List<Map<String, dynamic>>> getPresetExercisesByCategory(String category, bool isPremium) async {
    Database db = await database;
    if (isPremium) {
      return await db.query(
        'preset_exercises',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'name',
      );
    } else {
      return await db.query(
        'preset_exercises',
        where: 'category = ? AND is_premium = ?',
        whereArgs: [category, 0],
        orderBy: 'name',
      );
    }
  }
}

// Subscription Service
class SubscriptionService {
  static const String _isPremiumKey = 'is_premium';
  
  static Future<bool> isPremium() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isPremiumKey) ?? false;
  }
  
  static Future<void> setPremium(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, value);
  }
  
  static Future<void> upgradeToPremium() async {
    // In a real app, this would handle payment processing
    // For this MVP, we'll just set the premium flag
    await setPremium(true);
  }
}

// Model Classes
class Workout {
  final int? id;
  final String name;
  final DateTime date;
  final String? notes;
  
  Workout({
    this.id,
    required this.name,
    required this.date,
    this.notes,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }
  
  static Workout fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'],
      name: map['name'],
      date: DateTime.parse(map['date']),
      notes: map['notes'],
    );
  }
}

class Exercise {
  final int? id;
  final int workoutId;
  final String name;
  final int sets;
  final int reps;
  final double weight;
  
  Exercise({
    this.id,
    required this.workoutId,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
    };
  }
  
  static Exercise fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      workoutId: map['workout_id'],
      name: map['name'],
      sets: map['sets'],
      reps: map['reps'],
      weight: map['weight'],
    );
  }
}

// Screens
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isPremium = false;
  
  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }
  
  Future<void> _checkPremiumStatus() async {
    bool isPremium = await SubscriptionService.isPremium();
    setState(() {
      _isPremium = isPremium;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GymTracker ${_isPremium ? "Pro" : "Free"}'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              ).then((_) => _checkPremiumStatus());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Premium banner if not premium
          if (!_isPremium)
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upgrade to Pro for premium exercises and analytics!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    child: Text('UPGRADE'),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PremiumPage()),
                      );
                      _checkPremiumStatus();
                    },
                  ),
                ],
              ),
            ),
          
          // Main menu options
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.all(16),
              children: [
                _buildMenuCard(
                  context,
                  'Start Workout',
                  Icons.fitness_center,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NewWorkoutPage()),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  'Workout History',
                  Icons.history,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => WorkoutHistoryPage()),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  'Exercise Library',
                  Icons.menu_book,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ExerciseLibraryPage()),
                    );
                  },
                ),
                if (_isPremium)
                  _buildMenuCard(
                    context,
                    'Analytics',
                    Icons.analytics,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AnalyticsPage()),
                      );
                    },
                  )
                else
                  _buildMenuCard(
                    context,
                    'Analytics (Pro)',
                    Icons.analytics,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PremiumPage()),
                      );
                    },
                    isLocked: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isLocked = false,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isLocked) Icon(Icons.lock, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class NewWorkoutPage extends StatefulWidget {
  @override
  _NewWorkoutPageState createState() => _NewWorkoutPageState();
}

class _NewWorkoutPageState extends State<NewWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _workoutNameController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<Map<String, dynamic>> _exercises = [];
  bool _isPremium = false;
  
  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }
  
  Future<void> _checkPremiumStatus() async {
    bool isPremium = await SubscriptionService.isPremium();
    setState(() {
      _isPremium = isPremium;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Workout'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _workoutNameController,
                    decoration: InputDecoration(
                      labelText: 'Workout Name',
                      hintText: 'e.g., Morning Chest Day',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a workout name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Exercises',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Add Exercise'),
                    onPressed: () async {
                      final exercise = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddExercisePage(isPremium: _isPremium),
                        ),
                      );
                      
                      if (exercise != null) {
                        setState(() {
                          _exercises.add(exercise);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _exercises.isEmpty
                  ? Center(
                      child: Text(
                        'No exercises added yet.\nTap "Add Exercise" to begin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = _exercises[index];
                        return ListTile(
                          title: Text(exercise['name']),
                          subtitle: Text(
                            '${exercise['sets']} sets × ${exercise['reps']} reps × ${exercise['weight']} kg',
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _exercises.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: ElevatedButton(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'SAVE WORKOUT',
              style: TextStyle(fontSize: 16),
            ),
          ),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if (_exercises.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please add at least one exercise')),
                );
                return;
              }
              
              await _saveWorkout();
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }
  
  Future<void> _saveWorkout() async {
    // Create workout record
    final workout = {
      'name': _workoutNameController.text,
      'date': DateTime.now().toIso8601String(),
      'notes': _notesController.text,
    };
    
    // Insert workout and get ID
    final workoutId = await DatabaseHelper.instance.insertWorkout(workout);
    
    // Insert all exercises
    for (var exercise in _exercises) {
      final exerciseRecord = {
        'workout_id': workoutId,
        'name': exercise['name'],
        'sets': exercise['sets'],
        'reps': exercise['reps'],
        'weight': exercise['weight'],
      };
      
      await DatabaseHelper.instance.insertExercise(exerciseRecord);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Workout saved successfully')),
    );
  }
  
  @override
  void dispose() {
    _workoutNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

class AddExercisePage extends StatefulWidget {
  final bool isPremium;
  
  AddExercisePage({required this.isPremium});
  
  @override
  _AddExercisePageState createState() => _AddExercisePageState();
}

class _AddExercisePageState extends State<AddExercisePage> {
  final _formKey = GlobalKey<FormState>();
  final _exerciseNameController = TextEditingController();
  final _setsController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '10');
  final _weightController = TextEditingController(text: '0');
  
  List<Map<String, dynamic>> _presetExercises = [];
  List<String> _categories = [];
  String? _selectedCategory;
  
  @override
  void initState() {
    super.initState();
    _loadPresetExercises();
  }
  
  Future<void> _loadPresetExercises() async {
    // Load all preset exercises
    final exercises = await DatabaseHelper.instance.getPresetExercises(widget.isPremium);
    
    // Extract unique categories
    final categoriesSet = <String>{};
    for (var exercise in exercises) {
      categoriesSet.add(exercise['category'] as String);
    }
    
    setState(() {
      _presetExercises = exercises;
      _categories = categoriesSet.toList()..sort();
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Exercise'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: TextFormField(
                controller: _exerciseNameController,
                decoration: InputDecoration(
                  labelText: 'Exercise Name',
                  hintText: 'e.g., Bench Press',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.list),
                    tooltip: 'Select from preset exercises',
                    onPressed: () {
                      _showPresetExercisesDialog();
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an exercise name';
                  }
                  return null;
                },
              ),
            ),
            
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _setsController,
                      decoration: InputDecoration(
                        labelText: 'Sets',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Enter a number';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _repsController,
                      decoration: InputDecoration(
                        labelText: 'Reps',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Enter a number';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter a number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Container(),
            ),
            
            Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'ADD TO WORKOUT',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final exercise = {
                      'name': _exerciseNameController.text,
                      'sets': int.parse(_setsController.text),
                      'reps': int.parse(_repsController.text),
                      'weight': double.parse(_weightController.text),
                    };
                    
                    Navigator.pop(context, exercise);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPresetExercisesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Exercise'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    hint: Text('Select Category'),
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 300,
                    width: double.maxFinite,
                    child: _selectedCategory == null
                        ? Center(child: Text('Select a category'))
                        : FutureBuilder<List<Map<String, dynamic>>>(
                            future: DatabaseHelper.instance.getPresetExercisesByCategory(
                              _selectedCategory!,
                              widget.isPremium,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(child: CircularProgressIndicator());
                              }
                              
                              final exercises = snapshot.data!;
                              return ListView.builder(
                                itemCount: exercises.length,
                                itemBuilder: (context, index) {
                                  final exercise = exercises[index];
                                  final isPremium = exercise['is_premium'] == 1;
                                  
                                  return ListTile(
                                    title: Text(exercise['name'] as String),
                                    trailing: isPremium
                                        ? Icon(Icons.star, color: Colors.amber)
                                        : null,
                                    enabled: !isPremium || widget.isPremium,
                                    onTap: () {
                                      _exerciseNameController.text = exercise['name'] as String;
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('CANCEL'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  @override
  void dispose() {
    _exerciseNameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}

class WorkoutHistoryPage extends StatefulWidget {
  @override
  _WorkoutHistoryPageState createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  List<Map<String, dynamic>> _workouts = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }
  
  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
    });
    
    final workouts = await DatabaseHelper.instance.getWorkouts();
    
    setState(() {
      _workouts = workouts;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workout History'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
              ? Center(
                  child: Text(
                    'No workouts yet.\nStart by creating a new workout!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _workouts.length,
                  itemBuilder: (context, index) {
                    final workout = _workouts[index];
                    final date = DateTime.parse(workout['date'] as String);
                    
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text(workout['name'] as String),
                        subtitle: Text(
                          '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                        ),
                        children: [
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: DatabaseHelper.instance.getExercisesForWorkout(workout['id'] as int),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(child: CircularProgressIndicator());
                              }
                              
                              final exercises = snapshot.data!;
                              return Column(
                                children: [
                                  if (workout['notes'] != null && (workout['notes'] as String).isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Notes: ',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Expanded(
                                            child: Text(workout['notes'] as String),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    itemCount: exercises.length,
                                    itemBuilder: (context, index) {
                                      final exercise = exercises[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(exercise['name'] as String),
                                        subtitle: Text(
                                          '${exercise['sets']} sets × ${exercise['reps']} reps × ${exercise['weight']} kg',
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class ExerciseLibraryPage extends StatefulWidget {
  @override
  _ExerciseLibraryPageState createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  bool _isPremium = false;
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _init();
  }
  
  Future<void> _init() async {
    setState(() {
      _isLoading = true;
    });
    
    final isPremium = await SubscriptionService.isPremium();
    
    // Load all exercises
    final exercises = await DatabaseHelper.instance.getPresetExercises(isPremium);
    
    // Extract unique categories
    final categoriesSet = <String>{};
    for (var exercise in exercises) {
      categoriesSet.add(exercise['category'] as String);
    }
    
    setState(() {
      _isPremium = isPremium;
      _categories = categoriesSet.toList()..sort();
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exercise Library'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_isPremium)
                  Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.amber.shade100,
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Upgrade to Pro to unlock all premium exercises!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          child: Text('UPGRADE'),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PremiumPage()),
                            );
                            _init(); // Refresh after returning
                          },
                        ),
                      ],
                    ),
                  ),
                
                // Category selector
                Padding(
                  padding: EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Muscle Group',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                ),
                
                // Exercise list
                Expanded(
                  child: _selectedCategory == null
                      ? Center(child: Text('Select a muscle group'))
                      : FutureBuilder<List<Map<String, dynamic>>>(
                          future: DatabaseHelper.instance.getPresetExercisesByCategory(
                            _selectedCategory!,
                            _isPremium,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Center(child: CircularProgressIndicator());
                            }
                            
                            final exercises = snapshot.data!;
                            return ListView.builder(
                              itemCount: exercises.length,
                              itemBuilder: (context, index) {
                                final exercise = exercises[index];
                                final isPremiumExercise = exercise['is_premium'] == 1;
                                
                                return ListTile(
                                  title: Text(exercise['name'] as String),
                                  trailing: isPremiumExercise
                                      ? Icon(Icons.star, color: Colors.amber)
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class AnalyticsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics'),
      ),
      body: FutureBuilder<bool>(
        future: SubscriptionService.isPremium(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final isPremium = snapshot.data!;
          
          if (!isPremium) {
            // Redirect to premium page if not premium
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => PremiumPage()),
              );
            });
            return Container();
          }
          
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getWorkouts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              
              final workouts = snapshot.data!;
              
              if (workouts.isEmpty) {
                return Center(
                  child: Text(
                    'No workout data yet.\nStart by creating some workouts!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              
              return SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Workout Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            _buildStatTile('Total Workouts', '${workouts.length}'),
                            _buildStatTile('This Week', '${_countWorkoutsThisWeek(workouts)}'),
                            _buildStatTile('Most Common', '${_getMostCommonWorkout(workouts)}'),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    Text(
                      'Workout Frequency',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                    SizedBox(
                      height: 200,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'Premium Feature: Workout frequency chart',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    Text(
                      'Progress Charts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                    SizedBox(
                      height: 200,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'Premium Feature: Weight progression charts',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildStatTile(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  int _countWorkoutsThisWeek(List<Map<String, dynamic>> workouts) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - 1),
    );
    
    return workouts.where((workout) {
      final workoutDate = DateTime.parse(workout['date'] as String);
      return workoutDate.isAfter(startOfWeek);
    }).length;
  }
  
  String _getMostCommonWorkout(List<Map<String, dynamic>> workouts) {
    if (workouts.isEmpty) return 'None';
    
    // Count workout names
    final Map<String, int> counts = {};
    for (var workout in workouts) {
      final name = workout['name'] as String;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    
    // Find the most common
    String mostCommon = workouts.first['name'] as String;
    int highestCount = 0;
    
    counts.forEach((name, count) {
      if (count > highestCount) {
        highestCount = count;
        mostCommon = name;
      }
    });
    
    return mostCommon;
  }
}

class PremiumPage extends StatefulWidget {
  @override
  _PremiumPageState createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  bool _isPremium = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }
  
  Future<void> _checkPremiumStatus() async {
    final isPremium = await SubscriptionService.isPremium();
    setState(() {
      _isPremium = isPremium;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upgrade to Pro'),
      ),
      body: _isPremium
          ? _buildAlreadyPremium()
          : _buildPremiumOffer(),
    );
  }
  
  Widget _buildAlreadyPremium() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'You\'re a Pro User!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You have access to all premium features.',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            child: Text('RETURN TO HOME'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildPremiumOffer() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Upgrade to GymTracker Pro',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          
          // Feature comparison
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildFeatureRow('Basic Workout Tracking', true, true),
                  Divider(),
                  _buildFeatureRow('Workout History', true, true),
                  Divider(),
                  _buildFeatureRow('Basic Exercise Library', true, true),
                  Divider(),
                  _buildFeatureRow('Premium Exercises', false, true),
                  Divider(),
                  _buildFeatureRow('Analytics Dashboard', false, true),
                  Divider(),
                  _buildFeatureRow('Progress Charts', false, true),
                  Divider(),
                  _buildFeatureRow('Export Data', false, true),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Pricing
          Text(
            'Only \$4.99/month',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 8),
          
          Text(
            'Or \$39.99/year (save 33%)',
            style: TextStyle(
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 24),
          
          // Upgrade button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: _isLoading
                ? CircularProgressIndicator(color: Colors.white)
                : Text(
                    'UPGRADE NOW',
                    style: TextStyle(fontSize: 16),
                  ),
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() {
                      _isLoading = true;
                    });
                    
                    // In a real app, this would handle payment processing
                    await Future.delayed(Duration(seconds: 2));
                    await SubscriptionService.upgradeToPremium();
                    
                    setState(() {
                      _isPremium = true;
                      _isLoading = false;
                    });
                    
                    // Show success dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Upgrade Successful'),
                        content: Text('You now have access to all Pro features!'),
                        actions: [
                          TextButton(
                            child: Text('OK'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  },
          ),
          
          SizedBox(height: 16),
          
          TextButton(
            child: Text('Restore Purchase'),
            onPressed: () {
              // In a real app, this would check for existing purchases
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No previous purchases found')),
              );
            },
          ),
          
          SizedBox(height: 8),
          
          Text(
            'This is a demo app. No actual payment will be processed.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureRow(String feature, bool inFree, bool inPro) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(feature),
          ),
          SizedBox(width: 8),
          Column(
            children: [
              Text(
                'FREE',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Icon(
                inFree ? Icons.check_circle : Icons.cancel,
                color: inFree ? Colors.green : Colors.red,
              ),
            ],
          ),
          SizedBox(width: 16),
          Column(
            children: [
              Text(
                'PRO',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Icon(
                inPro ? Icons.check_circle : Icons.cancel,
                color: inPro ? Colors.green : Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isPremium = false;
  
  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }
  
  Future<void> _checkPremiumStatus() async {
    final isPremium = await SubscriptionService.isPremium();
    setState(() {
      _isPremium = isPremium;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('Subscription'),
            subtitle: Text(_isPremium ? 'Pro' : 'Free'),
            leading: Icon(Icons.star),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PremiumPage()),
              ).then((_) => _checkPremiumStatus());
            },
          ),
          Divider(),
          ListTile(
            title: Text('Units'),
            subtitle: Text('Kilograms (kg)'),
            leading: Icon(Icons.scale),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              // Would open unit selection dialog in a real app
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unit settings would open here')),
              );
            },
          ),
          Divider(),
          ListTile(
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
            leading: Icon(Icons.info_outline),
          ),
          Divider(),
          ListTile(
            title: Text('Reset All Data'),
            leading: Icon(Icons.delete_forever, color: Colors.red),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Reset All Data?'),
                  content: Text(
                    'This will delete all your workouts and reset the app to default settings. This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      child: Text('CANCEL'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: Text(
                        'RESET',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () {
                        // Would actually delete data in a real app
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('All data has been reset')),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}