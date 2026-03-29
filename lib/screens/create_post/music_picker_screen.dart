import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../utils/haptic_helper.dart';

class MusicTrack {
  final String title;
  final String artist;
  final String duration;
  final String coverUrl;
  final String category;
  final String previewUrl; // actual audio URL

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

  // Free sample audio clips (royalty-free from SampleLib / assets)
  static const _s1 = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
  static const _s2 = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3';
  static const _s3 = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3';
  static const _s4 = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3';
  static const _s5 = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3';
  static const _s6 = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3';
  static const _s7 = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3';
  static const _s8 = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3';

  final List<MusicTrack> _allTracks = [
    // Trending
    MusicTrack("Blinding Lights", "The Weeknd", "3:20", "", "Trending", _s1),
    MusicTrack("Levitating", "Dua Lipa", "3:23", "", "Trending", _s2),
    MusicTrack("As It Was", "Harry Styles", "2:47", "", "Trending", _s3),
    MusicTrack("Anti-Hero", "Taylor Swift", "3:21", "", "Trending", _s4),
    MusicTrack("Kill Bill", "SZA", "2:33", "", "Trending", _s5),
    MusicTrack("Flowers", "Miley Cyrus", "3:20", "", "Trending", _s6),
    // Pop
    MusicTrack("Shape of You", "Ed Sheeran", "3:53", "", "Pop", _s7),
    MusicTrack("Peaches", "Justin Bieber", "3:18", "", "Pop", _s8),
    MusicTrack("Watermelon Sugar", "Harry Styles", "2:54", "", "Pop", _s1),
    MusicTrack("Stay", "The Kid LAROI & JB", "2:21", "", "Pop", _s2),
    MusicTrack("Bad Habits", "Ed Sheeran", "3:50", "", "Pop", _s3),
    MusicTrack("Dynamite", "BTS", "3:19", "", "Pop", _s4),
    // Hip-Hop
    MusicTrack("HUMBLE.", "Kendrick Lamar", "2:57", "", "Hip-Hop", _s5),
    MusicTrack("SICKO MODE", "Travis Scott", "5:12", "", "Hip-Hop", _s6),
    MusicTrack("Lucid Dreams", "Juice WRLD", "3:59", "", "Hip-Hop", _s7),
    MusicTrack("Blueberry Faygo", "Lil Mosey", "2:36", "", "Hip-Hop", _s8),
    MusicTrack("Industry Baby", "Lil Nas X", "3:32", "", "Hip-Hop", _s1),
    // Chill
    MusicTrack("Starboy", "The Weeknd", "3:50", "", "Chill", _s2),
    MusicTrack("Heat Waves", "Glass Animals", "3:58", "", "Chill", _s3),
    MusicTrack("Sunflower", "Post Malone", "2:38", "", "Chill", _s4),
    MusicTrack("Circles", "Post Malone", "3:35", "", "Chill", _s5),
    MusicTrack("Snowman", "Sia", "3:15", "", "Chill", _s6),
    // Bollywood
    MusicTrack("Tum Hi Ho", "Arijit Singh", "4:22", "", "Bollywood", _s7),
    MusicTrack("Kesariya", "Arijit Singh", "4:28", "", "Bollywood", _s8),
    MusicTrack("Raataan Lambiyan", "Jubin Nautiyal", "3:49", "", "Bollywood", _s1),
    MusicTrack("Pasoori", "Ali Sethi", "3:52", "", "Bollywood", _s2),
    MusicTrack("Apna Bana Le", "Arijit Singh", "4:34", "", "Bollywood", _s3),
  ];

  final _tabs = ['Trending', 'Pop', 'Hip-Hop', 'Chill', 'Bollywood'];
  int? _playingIndex;
  String _searchQuery = '';
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      _stopAudio();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _filterTracks(String query) {
    setState(() => _searchQuery = query.toLowerCase());
  }

  void _onTrackTap(MusicTrack track) {
    KnockHaptics.tap();
    _audioPlayer.stop();
    Navigator.pop(context, track);
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    if (mounted) setState(() { _playingIndex = null; _isLoadingAudio = false; });
  }

  Future<void> _togglePlayPause(int globalIndex) async {
    KnockHaptics.tap();

    if (_playingIndex == globalIndex) {
      // Currently playing this track → pause it
      await _audioPlayer.pause();
      setState(() => _playingIndex = null);
      return;
    }

    // Play a new track
    setState(() { _playingIndex = globalIndex; _isLoadingAudio = true; });

    try {
      final track = _allTracks[globalIndex];
      await _audioPlayer.setUrl(track.previewUrl);
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      if (mounted) setState(() => _isLoadingAudio = false);

      // Listen for completion
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingIndex = null);
        }
      });
    } catch (e) {
      if (mounted) setState(() { _playingIndex = null; _isLoadingAudio = false; });
    }
  }

  Color _accentForCategory(String cat) {
    switch (cat) {
      case 'Trending':
        return const Color(0xFFF15BB5);
      case 'Pop':
        return const Color(0xFF4361EE);
      case 'Hip-Hop':
        return const Color(0xFFFF6B35);
      case 'Chill':
        return const Color(0xFF06D6A0);
      case 'Bollywood':
        return const Color(0xFFFFBE0B);
      default:
        return Colors.white;
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
                  onChanged: _filterTracks,
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
                  final tracks = _allTracks.where((t) {
                    final matchesCat = t.category == cat;
                    final matchesSearch = _searchQuery.isEmpty ||
                        t.title.toLowerCase().contains(_searchQuery) ||
                        t.artist.toLowerCase().contains(_searchQuery);
                    return matchesCat && matchesSearch;
                  }).toList();

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
                      final globalIndex = _allTracks.indexOf(track);
                      final isPlaying = _playingIndex == globalIndex;
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
                                  gradient: LinearGradient(
                                    colors: [
                                      catAccent.withOpacity(0.6),
                                      catAccent.withOpacity(0.2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Icon(
                                    isPlaying
                                        ? Icons.equalizer_rounded
                                        : Icons.music_note_rounded,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 24,
                                  ),
                                ),
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
                                onTap: () => _togglePlayPause(globalIndex),
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
                                  child: _isLoadingAudio &&
                                          _playingIndex == globalIndex
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
