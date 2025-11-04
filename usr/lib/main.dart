import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fruit Blast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const FruitBlastGame(),
    );
  }
}

class FruitBlastGame extends StatefulWidget {
  const FruitBlastGame({super.key});

  @override
  State<FruitBlastGame> createState() => _FruitBlastGameState();
}

class _FruitBlastGameState extends State<FruitBlastGame> {
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _crushSoundPlayer = AudioPlayer();
  bool _isMusicPlaying = false;

  late List<List<String>> _board;
  int _currentLevelIndex = 0;
  int _width = 8;
  int _targetScore = 950;
  int _score = 0;
  int? _firstSelection;
  int? _secondSelection;
  bool _isProcessing = false;
  final List<String> _fruits = ['🍉', '🍊', '🍓', '🍇', '🥝', '🍒'];
  final double _tileSize = 40.0;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _setupBoard();
  }

  void _initializeAudio() async {
    try {
      await _backgroundMusicPlayer.setAsset('assets/audio/background_music.mp3');
      await _crushSoundPlayer.setAsset('assets/audio/pop_crush.mp3');
      _backgroundMusicPlayer.setLoopMode(LoopMode.one);
      _backgroundMusicPlayer.setVolume(0.5);
      _crushSoundPlayer.setVolume(0.8);
    } catch (e) {
      // Audio files not available, continue without audio
    }
  }

  void _toggleMusic() {
    if (_isMusicPlaying) {
      _backgroundMusicPlayer.pause();
      setState(() {
        _isMusicPlaying = false;
      });
    } else {
      _backgroundMusicPlayer.play();
      setState(() {
        _isMusicPlaying = true;
      });
    }
  }

  void _playCrushSound() {
    _crushSoundPlayer.seek(Duration.zero);
    _crushSoundPlayer.play();
  }

  List<Map<String, dynamic>> _generateLevelData() {
    final data = <Map<String, dynamic>>[];
    int baseScore = 700;
    int boardSize = 8;
    for (int i = 1; i <= 50; i++) {
      if (i > 5 && i <= 10) boardSize = 9;
      else if (i > 10 && i <= 15) boardSize = 10;
      else if (i > 15 && i <= 25) boardSize = 11;
      else if (i > 25) boardSize = 12;
      int target = baseScore + (i * 250);
      data.add({'width': boardSize, 'targetScore': target});
    }
    return data;
  }

  void _setupBoard() {
    final levelData = _generateLevelData();
    _width = levelData[_currentLevelIndex]['width'];
    _targetScore = levelData[_currentLevelIndex]['targetScore'];
    _score = 0;
    _firstSelection = null;
    _secondSelection = null;
    _isProcessing = false;
    _board = List.generate(_width, (_) => List.generate(_width, (_) => _fruits[_getRandomFruitIndex()]));
    _removeInitialMatches();
    setState(() {});
  }

  int _getRandomFruitIndex() {
    return DateTime.now().millisecondsSinceEpoch % _fruits.length;
  }

  void _removeInitialMatches() {
    bool hasMatches = true;
    while (hasMatches) {
      hasMatches = false;
      final matchedTiles = _checkAllMatches();
      if (matchedTiles.isNotEmpty) {
        hasMatches = true;
        for (final index in matchedTiles) {
          final row = index ~/ _width;
          final col = index % _width;
          _board[row][col] = '';
        }
        _moveDown();
        _fillTopRow();
      }
    }
  }

  void _handleTileTap(int index) {
    if (_isProcessing) return;
    if (!_isMusicPlaying) _toggleMusic();
    final row = index ~/ _width;
    final col = index % _width;
    if (_firstSelection == null) {
      setState(() {
        _firstSelection = index;
      });
      return;
    }
    if (_firstSelection == index) {
      setState(() {
        _firstSelection = null;
      });
      return;
    }
    _secondSelection = index;
    final id1 = _firstSelection!;
    final id2 = _secondSelection!;
    final isAdjacent = (id1 - id2).abs() == 1 || (id1 - id2).abs() == _width;
    final sameRowCheck = (id1 - id2).abs() == 1 && (id1 ~/ _width) != (id2 ~/ _width);
    if (isAdjacent && !sameRowCheck) {
      _handleSwap(id1, id2);
    } else {
      setState(() {
        _firstSelection = index;
        _secondSelection = null;
      });
    }
  }

  void _handleSwap(int id1, int id2) {
    if (_isProcessing) return;
    _swapFruits(id1, id2);
    setState(() {
      _firstSelection = null;
      _secondSelection = null;
    });
    _runGameLoop(true);
  }

  void _swapFruits(int id1, int id2) {
    final row1 = id1 ~/ _width;
    final col1 = id1 % _width;
    final row2 = id2 ~/ _width;
    final col2 = id2 % _width;
    final temp = _board[row1][col1];
    _board[row1][col1] = _board[row2][col2];
    _board[row2][col2] = temp;
  }

  Set<int> _checkAllMatches() {
    final matchedTiles = <int>{};
    // Check horizontal
    for (int row = 0; row < _width; row++) {
      for (int col = 0; col <= _width - 3; col++) {
        final fruit = _board[row][col];
        if (fruit.isNotEmpty &&
            fruit == _board[row][col + 1] &&
            fruit == _board[row][col + 2]) {
          matchedTiles.add(row * _width + col);
          matchedTiles.add(row * _width + col + 1);
          matchedTiles.add(row * _width + col + 2);
          for (int k = col + 3; k < _width; k++) {
            if (_board[row][k] == fruit) {
              matchedTiles.add(row * _width + k);
            } else {
              break;
            }
          }
        }
      }
    }
    // Check vertical
    for (int col = 0; col < _width; col++) {
      for (int row = 0; row <= _width - 3; row++) {
        final fruit = _board[row][col];
        if (fruit.isNotEmpty &&
            fruit == _board[row + 1][col] &&
            fruit == _board[row + 2][col]) {
          matchedTiles.add(row * _width + col);
          matchedTiles.add((row + 1) * _width + col);
          matchedTiles.add((row + 2) * _width + col);
          for (int k = row + 3; k < _width; k++) {
            if (_board[k][col] == fruit) {
              matchedTiles.add(k * _width + col);
            } else {
              break;
            }
          }
        }
      }
    }
    return matchedTiles;
  }

  void _moveDown() {
    for (int col = 0; col < _width; col++) {
      final column = <String>[];
      for (int row = _width - 1; row >= 0; row--) {
        if (_board[row][col].isNotEmpty) {
          column.add(_board[row][col]);
        }
      }
      for (int row = 0; row < _width; row++) {
        if (row < column.length) {
          _board[_width - 1 - row][col] = column[row];
        } else {
          _board[_width - 1 - row][col] = '';
        }
      }
    }
  }

  void _fillTopRow() {
    for (int col = 0; col < _width; col++) {
      if (_board[0][col].isEmpty) {
        _board[0][col] = _fruits[_getRandomFruitIndex()];
      }
    }
  }

  void _runGameLoop(bool canReverse) async {
    _isProcessing = true;
    final matchedTiles = _checkAllMatches();
    if (matchedTiles.isNotEmpty) {
      _playCrushSound();
      _updateScore(10 * matchedTiles.length);
      await Future.delayed(const Duration(milliseconds: 300));
      for (final index in matchedTiles) {
        final row = index ~/ _width;
        final col = index % _width;
        _board[row][col] = '';
      }
      _moveDown();
      _fillTopRow();
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 300));
      _runGameLoop(false);
    } else if (canReverse && _firstSelection != null && _secondSelection != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      _swapFruits(_firstSelection!, _secondSelection!);
      setState(() {});
    }
    _firstSelection = null;
    _secondSelection = null;
    _isProcessing = false;
    if (_score >= _targetScore) {
      await Future.delayed(const Duration(milliseconds: 500));
      _completeLevel();
    }
  }

  void _updateScore(int points) {
    setState(() {
      _score += points;
    });
  }

  int _calculateStars() {
    if (_score >= _targetScore * 1.5) return 3;
    if (_score >= _targetScore * 1.2) return 2;
    if (_score >= _targetScore) return 1;
    return 0;
  }

  void _completeLevel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Level Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⭐' * _calculateStars(), style: const TextStyle(fontSize: 30)),
            Text('Your Score: $_score'),
            const Text('Ad integration area', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _nextLevel();
            },
            child: const Text('Play Next Level'),
          ),
        ],
      ),
    );
  }

  void _nextLevel() {
    final levelData = _generateLevelData();
    if (_currentLevelIndex < levelData.length - 1) {
      _currentLevelIndex++;
      _setupBoard();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Congratulations!'),
          content: const Text('All 50 levels completed!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _currentLevelIndex = 0;
                _setupBoard();
              },
              child: const Text('Restart'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 50,
            color: Colors.black,
            child: const Center(
              child: Text(
                'Banner Ad Placeholder',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(10.0),
            child: Text(
              '🍉 Fruit Blast 🍊',
              style: TextStyle(fontSize: 24, color: Color(0xFF388E3C)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level: ${_currentLevelIndex + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '⭐' * _calculateStars(),
                      style: const TextStyle(color: Color(0xFFFFD700)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Score: $_score',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Target: $_targetScore',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFa5d6a7),
                  border: Border.all(color: const Color(0xFF1B5E20), width: 4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _width,
                  ),
                  itemCount: _width * _width,
                  itemBuilder: (context, index) {
                    final row = index ~/ _width;
                    final col = index % _width;
                    final isSelected = _firstSelection == index;
                    return GestureDetector(
                      onTap: () => _handleTileTap(index),
                      child: Container(
                        width: _tileSize,
                        height: _tileSize,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            _board[row][col],
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleMusic,
        backgroundColor: const Color(0xFFFF9800),
        child: Icon(_isMusicPlaying ? Icons.volume_up : Icons.volume_off),
      ),
    );
  }

  @override
  void dispose() {
    _backgroundMusicPlayer.dispose();
    _crushSoundPlayer.dispose();
    super.dispose();
  }
}