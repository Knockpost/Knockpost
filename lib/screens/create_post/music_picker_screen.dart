import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../../utils/haptic_helper.dart';

class MusicTrack {
  final String title;
  final String artist;
  final String duration;
  final String coverUrl;
  final String category;
  final String previewUrl;

  MusicTrack(this.title, this.artist, this.duration, this.coverUrl,
      this.category, this.previewUrl);
}

class MusicPickerScreen extends StatefulWidget {
  const MusicPickerScreen({super.key});

  @override
  State<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends State<MusicPickerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<String> _tabs = ['Trending', 'Pop', 'Hip-Hop', 'Chill', 'Bollywood'];
  
  Map<String, List<MusicTrack>> _categoryTracksMap = {};
  List<MusicTrack> _searchTracks = [];
  
  String? _playingUrl;
  String _searchQuery = '';
  bool _isLoadingTracks = false;
  bool _isLoadingAudio = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _stopAudio();
        _loadTracksForCategory(_tabs[_tabController.index]);
      }
    });

    // Load initial category
    _loadTracksForCategory(_tabs[0]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTracksForCategory(String category) async {
    if (_categoryTracksMap.containsKey(category) &&
        _categoryTracksMap[category]!.isNotEmpty) {
      return; 
    }
    
    // Map category to a good iTunes search term
    String searchTerm = category;
    if (category == 'Trending') searchTerm = 'Top billboard hits';
    else if (category == 'Chill') searchTerm = 'Lofi chillhop';
    else if (category == 'Bollywood') searchTerm = 'Bollywood latest hits';
    else searchTerm = '$category music';

    await _fetchFromITunes(searchTerm, category);
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query.toLowerCase());
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() { _searchTracks = []; });
      return;
    }
    
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _fetchFromITunes(query, 'Search');
    });
  }

  Future<void> _fetchFromITunes(String term, String categoryKey) async {
    if (mounted) setState(() => _isLoadingTracks = true);
    
    try {
      final url = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(term)}&limit=30&media=music&entity=song');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        final tracks = results.map((item) {
          int millis = item['trackTimeMillis'] ?? 0;
          int sec = (millis / 1000).round();
          String dur = '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
          
          return MusicTrack(
            item['trackName'] ?? 'Unknown',
            item['artistName'] ?? 'Unknown Artist',
            dur,
            (item['artworkUrl100'] as String?)?.replaceAll('100x100', '300x300') ?? '', 
            categoryKey,
            item['previewUrl'] ?? '',
          );
        }).where((t) => t.previewUrl.isNotEmpty).toList();

        if (mounted) {
          setState(() {
            if (categoryKey == 'Search') {
              _searchTracks = tracks;
            } else {
              _categoryTracksMap[categoryKey] = tracks;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('iTunes API Error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTracks = false);
    }
  }

  void _onTrackTap(MusicTrack track) {
    KnockHaptics.tap();
    _audioPlayer.stop();
    Navigator.pop(context, track);
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    if (mounted) setState(() { _playingUrl = null; _isLoadingAudio = false; });
  }

  Future<void> _togglePlayPause(MusicTrack track) async {
    KnockHaptics.tap();

    if (_playingUrl == track.previewUrl) {
      await _audioPlayer.pause();
      setState(() => _playingUrl = null);
      return;
    }

    setState(() { _playingUrl = track.previewUrl; _isLoadingAudio = true; });

    try {
      await _audioPlayer.setUrl(track.previewUrl);
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      if (mounted) setState(() => _isLoadingAudio = false);

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingUrl = null);
        }
      });
    } catch (e) {
      if (mounted) setState(() { _playingUrl = null; _isLoadingAudio = false; });
    }
  }

  Color _accentForCategory(String cat) {
    switch (cat) {
      case 'Trending': return const Color(0xFFF15BB5);
      case 'Pop': return const Color(0xFF4361EE);
      case 'Hip-Hop': return const Color(0xFFFF6B35);
      case 'Chill': return const Color(0xFF06D6A0);
      case 'Bollywood': return const Color(0xFFFFBE0B);
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentForCategory(_tabs[_tabController.index]);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () { _audioPlayer.stop(); Navigator.pop(context); },
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Audio',
                        style: TextStyle(color: Colors.white, fontSize: 19,
                            fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),

            // ── SEARCH BAR ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.4), size: 22),
                    hintText: 'Search songs, artists',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── CATEGORY TABS ──
            SizedBox(
              height: 36,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicatorColor: accent,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ),

            const SizedBox(height: 4),

            // ── TRACK LIST ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: _tabs.map((cat) {
                  List<MusicTrack> tracks = [];
                  if (_searchQuery.isNotEmpty) {
                    tracks = _searchTracks;
                  } else {
                    tracks = _categoryTracksMap[cat] ?? [];
                  }

                  if (_isLoadingTracks && tracks.isEmpty) {
                    return Center(
                      child: SizedBox(
                        width: 24, height: 24, 
                        child: CircularProgressIndicator(color: accent, strokeWidth: 2),
                      )
                    );
                  }

                  if (tracks.isEmpty) {
                    return Center(
                      child: Text('No tracks found',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 14)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isPlaying = _playingUrl == track.previewUrl;
                      final catAccent = _accentForCategory(cat);

                      return GestureDetector(
                        onTap: () => _onTrackTap(track),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? catAccent.withOpacity(0.12)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: isPlaying
                                ? Border.all(
                                    color: catAccent.withOpacity(0.3),
                                    width: 1)
                                : null,
                          ),
                          child: Row(
                            children: [
                              // ── Cover Art ──
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  image: track.coverUrl.isNotEmpty ? DecorationImage(
                                    image: NetworkImage(track.coverUrl),
                                    fit: BoxFit.cover,
                                  ) : null,
                                ),
                                child: track.coverUrl.isEmpty ? Center(
                                  child: Icon(
                                    isPlaying
                                        ? Icons.equalizer_rounded
                                        : Icons.music_note_rounded,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 24,
                                  ),
                                ) : null,
                              ),
                              const SizedBox(width: 14),

                              // ── Track Info ──
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isPlaying
                                              ? catAccent
                                              : Colors.white,
                                        )),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${track.artist} · ${track.duration}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              Colors.white.withOpacity(0.4)),
                                    ),
                                    // ── Mini Waveform ──
                                    if (isPlaying && !_isLoadingAudio) ...[
                                      const SizedBox(height: 8),
                                      _buildWaveform(catAccent),
                                    ],
                                    if (isPlaying && _isLoadingAudio) ...[
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        backgroundColor:
                                            catAccent.withOpacity(0.1),
                                        color: catAccent,
                                        minHeight: 2,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // ── Play / Pause ──
                              GestureDetector(
                                onTap: () => _togglePlayPause(track),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isPlaying
                                        ? catAccent.withOpacity(0.25)
                                        : Colors.white.withOpacity(0.08),
                                    border: Border.all(
                                      color: isPlaying
                                          ? catAccent.withOpacity(0.5)
                                          : Colors.white.withOpacity(0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: _isLoadingAudio && isPlaying
                                      ? Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: catAccent,
                                          ),
                                        )
                                      : Icon(
                                          isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 20,
                                          color: isPlaying
                                              ? catAccent
                                              : Colors.white70,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform(Color accent) {
    return Row(
      children: List.generate(20, (i) {
        final heights = [
          6.0, 12.0, 8.0, 16.0, 10.0, 14.0, 7.0, 18.0, 11.0, 5.0,
          13.0, 9.0, 15.0, 6.0, 17.0, 8.0, 12.0, 10.0, 14.0, 7.0
        ];
        return Expanded(
          child: Container(
            height: heights[i],
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
